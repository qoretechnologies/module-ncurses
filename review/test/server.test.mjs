// Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import WebSocket from 'ws';
import { createBridgeServer } from '../server.mjs';

function connect(server, origin = `http://127.0.0.1:${server.port}`) {
  return new WebSocket(`ws://127.0.0.1:${server.port}/native`, { origin });
}
function response(socket, request) {
  return new Promise((resolve, reject) => {
    const listener = data => {
      const message = JSON.parse(data.toString());
      if (message.request === request) { socket.off('message', listener); resolve(message); }
    };
    socket.on('message', listener); socket.once('error', reject);
  });
}

test('WebSocket transports the actual story and rejects unknown actions', async () => {
  const server = await createBridgeServer({ port: 0 });
  const socket = connect(server); await once(socket, 'open');
  try {
    let result = response(socket, 0); socket.send(JSON.stringify({ request: 0, type: 'start', story: 'table.scrolling' }));
    assert.equal((await result).artifact.state.selected, 0);
    result = response(socket, 1); socket.send(JSON.stringify({ request: 1, type: 'input', data: '\x1bOF' }));
    assert.equal((await result).artifact.state.selected, 23);
    result = response(socket, 2); socket.send(JSON.stringify({ request: 2, type: 'shell', command: 'false' }));
    assert.match((await result).error, /Unknown native action/);
    result = response(socket, 3); socket.send(JSON.stringify({ request: 3, type: 'reset' }));
    assert.equal((await result).artifact.state.selected, 0);
  } finally { socket.terminate(); await server.close(); }
  assert.equal(server.sessionCount, 0);
});

test('origin and unknown stories fail before a native process is launched', async () => {
  const server = await createBridgeServer({ port: 0 });
  try {
    const denied = connect(server, 'https://untrusted.example');
    await assert.rejects(once(denied, 'open'));
    const socket = connect(server); await once(socket, 'open');
    const result = response(socket, 0); socket.send(JSON.stringify({ request: 0, type: 'start', story: '../invalid' }));
    assert.match((await result).error, /Unknown story/); socket.terminate();
  } finally { await server.close(); }
  assert.equal(server.sessionCount, 0);
});

test('disconnect during startup, malformed messages and repeated request IDs clean up', async () => {
  const server = await createBridgeServer({ port: 0 });
  try {
    const early = connect(server); await once(early, 'open');
    early.send(JSON.stringify({ request: 0, type: 'start', story: 'table.scrolling' })); early.terminate();
    const malformed = connect(server); await once(malformed, 'open');
    const closed = once(malformed, 'close'); malformed.send('null'); await closed;
    const socket = connect(server); await once(socket, 'open');
    let result = response(socket, 0); socket.send(JSON.stringify({ request: 0, type: 'start', story: 'label.default' })); await result;
    result = response(socket, 0); socket.send(JSON.stringify({ request: 0, type: 'capture' }));
    assert.match((await result).error, /increase/);
    result = response(socket, 1); socket.send(JSON.stringify({ request: 1, type: 'close' }));
    assert.equal((await result).type, 'closed');
  } finally { await server.close(); }
  assert.equal(server.sessionCount, 0);
});

test('session and message bounds reject excess work and release capacity', async () => {
  const server = await createBridgeServer({ port: 0 });
  const sockets = [];
  try {
    for (let i = 0; i < 4; ++i) {
      const socket = connect(server); sockets.push(socket); await once(socket, 'open');
    }
    assert.equal(server.sessionCount, 4);
    const denied = connect(server); await assert.rejects(once(denied, 'open'), /403/);
    const closed = once(sockets[0], 'close'); sockets[0].close(); await closed;
    const replacement = connect(server); sockets.push(replacement); await once(replacement, 'open');
    const oversized = once(replacement, 'close'); replacement.send('x'.repeat(128 * 1024 + 1)); await oversized;
    const recovered = connect(server); sockets.push(recovered); await once(recovered, 'open');
    const result = response(recovered, 0); recovered.send(JSON.stringify({ request: 0, type: 'start', story: 'label.default' }));
    assert.equal((await result).artifact.story, 'label.default');
    const escaped = response(recovered, 1);
    recovered.send(JSON.stringify({ request: 1, type: 'input', data: '\x07'.repeat(16384) }));
    assert.equal((await escaped).artifact.story, 'label.default', 'valid input survives worst-case JSON escaping');
  } finally { for (const socket of sockets) { socket.terminate(); } await server.close(); }
  assert.equal(server.sessionCount, 0);
});
