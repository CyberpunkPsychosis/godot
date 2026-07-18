import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { discoverPort, portRegistryDirs, readPortFile, splitLines, unreachableResponse } from '../src/lib.mjs';

test('splitLines returns complete lines and keeps the remainder', () => {
  const { lines, rest } = splitLines('{"a":1}\n{"b":2}\r\n{"partial"');
  assert.deepEqual(lines, ['{"a":1}', '{"b":2}']);
  assert.equal(rest, '{"partial"');
});

test('splitLines skips blank lines', () => {
  const { lines } = splitLines('\n\n{"a":1}\n\n');
  assert.deepEqual(lines, ['{"a":1}']);
});

test('unreachableResponse answers requests but not notifications', () => {
  const response = unreachableResponse('{"jsonrpc":"2.0","id":7,"method":"initialize"}');
  assert.equal(response.id, 7);
  assert.equal(response.error.code, -32001);
  assert.equal(unreachableResponse('{"jsonrpc":"2.0","method":"notifications/initialized"}'), null);
  assert.equal(unreachableResponse('not json'), null);
});

test('readPortFile rejects malformed files', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'godot-mcp-'));
  const bad = path.join(dir, 'bad.json');
  fs.writeFileSync(bad, 'nope');
  assert.equal(readPortFile(bad), null);
  const good = path.join(dir, 'good.json');
  fs.writeFileSync(good, JSON.stringify({ port: 9080, pid: process.pid }));
  assert.equal(readPortFile(good).port, 9080);
});

test('discoverPort prefers explicit port, then project file, then registry', () => {
  assert.deepEqual(discoverPort({ port: 1234, registryDirs: [] }), { port: 1234, source: 'explicit --port' });

  const project = fs.mkdtempSync(path.join(os.tmpdir(), 'godot-proj-'));
  fs.mkdirSync(path.join(project, '.godot'));
  fs.writeFileSync(
    path.join(project, '.godot', 'ai_console_port.json'),
    JSON.stringify({ port: 9085, pid: process.pid })
  );
  assert.equal(discoverPort({ projectDir: project, registryDirs: [] }).port, 9085);

  const registry = fs.mkdtempSync(path.join(os.tmpdir(), 'godot-reg-'));
  fs.writeFileSync(path.join(registry, 'a.json'), JSON.stringify({ port: 9090, pid: process.pid, project: '/x' }));
  assert.equal(discoverPort({ registryDirs: [registry] }).port, 9090);

  assert.equal(discoverPort({ registryDirs: [path.join(registry, 'missing')] }), null);
});

test('portRegistryDirs maps platforms to Godot config locations', () => {
  const win = portRegistryDirs('win32', { APPDATA: 'C:\\Users\\me\\AppData\\Roaming' }, 'C:\\Users\\me');
  assert.ok(win[0].includes('Godot'));
  const linux = portRegistryDirs('linux', {}, '/home/me');
  assert.ok(linux[0].endsWith(path.join('godot', 'ai_console_ports')));
  const mac = portRegistryDirs('darwin', {}, '/Users/me');
  assert.ok(mac[0].includes('Application Support'));
});
