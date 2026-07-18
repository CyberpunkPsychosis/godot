// End-to-end relay test: mock "Godot editor" WS server <-> real bridge
// process <-> stdio, exactly how an MCP client would drive it.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { WebSocketServer } from 'ws';

const BRIDGE = fileURLToPath(new URL('../src/index.mjs', import.meta.url));

test('bridge relays initialize and tools/list to the WS server and back', async () => {
  const wss = new WebSocketServer({ host: '127.0.0.1', port: 0 });
  await new Promise((resolve) => wss.on('listening', resolve));
  const port = wss.address().port;

  wss.on('connection', (socket) => {
    socket.on('message', (data) => {
      const msg = JSON.parse(data.toString());
      if (msg.method === 'initialize') {
        socket.send(JSON.stringify({
          jsonrpc: '2.0', id: msg.id,
          result: { protocolVersion: '2025-06-18', serverInfo: { name: 'mock-godot' } },
        }));
      } else if (msg.method === 'tools/list') {
        socket.send(JSON.stringify({
          jsonrpc: '2.0', id: msg.id,
          result: { tools: [{ name: 'create_node' }] },
        }));
      }
    });
  });

  const bridge = spawn(process.execPath, [BRIDGE, '--port', String(port)], { stdio: ['pipe', 'pipe', 'pipe'] });
  const responses = [];
  let buffer = '';
  bridge.stdout.on('data', (chunk) => {
    buffer += chunk.toString();
    let idx;
    while ((idx = buffer.indexOf('\n')) >= 0) {
      const line = buffer.slice(0, idx).trim();
      buffer = buffer.slice(idx + 1);
      if (line) responses.push(JSON.parse(line));
    }
  });

  bridge.stdin.write(JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'initialize', params: { protocolVersion: '2025-06-18' } }) + '\n');
  bridge.stdin.write(JSON.stringify({ jsonrpc: '2.0', id: 2, method: 'tools/list' }) + '\n');

  const deadline = Date.now() + 8000;
  while (responses.length < 2 && Date.now() < deadline) {
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  bridge.kill();
  wss.close();

  assert.equal(responses.length, 2, `expected 2 responses, got ${JSON.stringify(responses)}`);
  assert.equal(responses[0].result.serverInfo.name, 'mock-godot');
  assert.equal(responses[1].result.tools[0].name, 'create_node');
});
