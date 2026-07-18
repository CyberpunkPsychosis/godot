#!/usr/bin/env node
// godot-mcp: stdio <-> WebSocket bridge.
//
// MCP clients (Claude Code, Cursor, Cline, Codex CLI...) spawn this process
// and speak newline-delimited JSON-RPC over stdio; we relay verbatim to the
// AI Console MCP server inside the running Godot editor over WebSocket.
//
// CRITICAL: stdout carries ONLY JSON-RPC lines. All logging goes to stderr.
//
// Usage:
//   godot-mcp                       # auto-discover the most recent editor
//   godot-mcp --project <dir>       # target the editor with that project open
//   godot-mcp --port 9080           # explicit port
import { WebSocket } from 'ws';
import { discoverPort, portRegistryDirs, splitLines, unreachableResponse } from './lib.mjs';

const log = (...args) => console.error('[godot-mcp]', ...args);

const args = process.argv.slice(2);
const options = { port: 0, projectDir: '' };
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--port') options.port = Number(args[++i]);
  else if (args[i] === '--project') options.projectDir = args[++i];
  else if (args[i] === '--help' || args[i] === '-h') {
    log('usage: godot-mcp [--project <dir>] [--port <port>]');
    process.exit(0);
  }
}
if (process.env.GODOT_MCP_PORT && !options.port) options.port = Number(process.env.GODOT_MCP_PORT);

const QUEUE_TIMEOUT_MS = 15000;
const RETRY_MAX_MS = 10000;

let ws = null;
let retryDelay = 500;
let queue = []; // {line, ts} waiting for a connection

function connect() {
  const target = discoverPort({
    port: options.port,
    projectDir: options.projectDir,
    registryDirs: portRegistryDirs(),
  });
  if (!target) {
    scheduleReconnect();
    return;
  }
  const url = `ws://127.0.0.1:${target.port}`;
  const socket = new WebSocket(url);
  socket.on('open', () => {
    ws = socket;
    retryDelay = 500;
    log(`connected to ${url} via ${target.source}`);
    const pending = queue;
    queue = [];
    for (const item of pending) socket.send(item.line);
  });
  socket.on('message', (data) => {
    process.stdout.write(data.toString() + '\n');
  });
  socket.on('close', () => {
    if (ws === socket) {
      ws = null;
      log('connection closed; will reconnect');
    }
    scheduleReconnect();
  });
  socket.on('error', (err) => {
    log(`socket error: ${err.message}`);
    socket.close();
  });
}

let reconnectTimer = null;
function scheduleReconnect() {
  if (reconnectTimer) return;
  reconnectTimer = setTimeout(() => {
    reconnectTimer = null;
    if (!ws) connect();
  }, retryDelay);
  retryDelay = Math.min(retryDelay * 2, RETRY_MAX_MS);
}

// Requests stuck in the queue too long get a JSON-RPC error so the client
// reports a useful message instead of hanging forever; we keep retrying the
// connection so later calls succeed once the editor opens.
setInterval(() => {
  const now = Date.now();
  const expired = queue.filter((item) => now - item.ts > QUEUE_TIMEOUT_MS);
  queue = queue.filter((item) => now - item.ts <= QUEUE_TIMEOUT_MS);
  for (const item of expired) {
    const response = unreachableResponse(item.line);
    if (response) process.stdout.write(JSON.stringify(response) + '\n');
  }
}, 2500).unref();

let stdinBuffer = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (chunk) => {
  stdinBuffer += chunk;
  const { lines, rest } = splitLines(stdinBuffer);
  stdinBuffer = rest;
  for (const line of lines) {
    if (ws && ws.readyState === WebSocket.OPEN) ws.send(line);
    else queue.push({ line, ts: Date.now() });
  }
});
process.stdin.on('end', () => {
  log('stdin closed; exiting');
  if (ws) ws.close();
  process.exit(0);
});

connect();
