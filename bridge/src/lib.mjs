// Pure helpers for the bridge, split out for unit testing.
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';

// Godot editor config dirs where port_file.gd publishes ai_console_ports/.
export function portRegistryDirs(platform = process.platform, env = process.env, home = os.homedir()) {
  const dirs = [];
  if (platform === 'win32') {
    if (env.APPDATA) dirs.push(path.join(env.APPDATA, 'Godot', 'ai_console_ports'));
  } else if (platform === 'darwin') {
    dirs.push(path.join(home, 'Library', 'Application Support', 'Godot', 'ai_console_ports'));
  } else {
    const base = env.XDG_CONFIG_HOME || path.join(home, '.config');
    dirs.push(path.join(base, 'godot', 'ai_console_ports'));
  }
  return dirs;
}

export function readPortFile(filePath) {
  try {
    const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    if (typeof data.port === 'number' && data.port > 0) return data;
  } catch {
    // Unreadable or malformed — treat as absent.
  }
  return null;
}

function pidAlive(pid) {
  if (typeof pid !== 'number') return true; // Unknown pid: assume alive.
  try {
    process.kill(pid, 0);
    return true;
  } catch (err) {
    return err.code === 'EPERM';
  }
}

// Resolution order: explicit port > project-local port file > newest live
// entry in the global registry. Returns {port, source} or null.
export function discoverPort({ port, projectDir, registryDirs }) {
  if (port) return { port: Number(port), source: 'explicit --port' };
  if (projectDir) {
    const local = readPortFile(path.join(projectDir, '.godot', 'ai_console_port.json'));
    if (local && pidAlive(local.pid)) return { port: local.port, source: `project ${projectDir}` };
    return null;
  }
  const candidates = [];
  for (const dir of registryDirs) {
    let entries = [];
    try {
      entries = fs.readdirSync(dir).filter((f) => f.endsWith('.json'));
    } catch {
      continue;
    }
    for (const entry of entries) {
      const full = path.join(dir, entry);
      const data = readPortFile(full);
      if (data && pidAlive(data.pid)) {
        candidates.push({ ...data, mtime: fs.statSync(full).mtimeMs });
      }
    }
  }
  candidates.sort((a, b) => b.mtime - a.mtime);
  if (candidates.length > 0) {
    return { port: candidates[0].port, source: `registry (${candidates[0].project || 'unknown project'})` };
  }
  return null;
}

// Incremental newline-delimited JSON splitter for the stdio side.
// Returns {lines, rest}: complete lines and the unterminated remainder.
export function splitLines(buffer) {
  const lines = [];
  let start = 0;
  for (let i = 0; i < buffer.length; i++) {
    if (buffer[i] === '\n') {
      const line = buffer.slice(start, i).replace(/\r$/, '').trim();
      if (line.length > 0) lines.push(line);
      start = i + 1;
    }
  }
  return { lines, rest: buffer.slice(start) };
}

// Builds the JSON-RPC error sent for requests queued while no editor is
// reachable. Returns null for notifications (no id -> no response allowed).
export function unreachableResponse(rawRequest) {
  let id;
  try {
    id = JSON.parse(rawRequest).id;
  } catch {
    return null;
  }
  if (id === undefined || id === null) return null;
  return {
    jsonrpc: '2.0',
    id,
    error: {
      code: -32001,
      message:
        'Godot editor with the AI Console plugin is not reachable. Open the project in Godot (the plugin starts its MCP server automatically), then retry.',
    },
  };
}
