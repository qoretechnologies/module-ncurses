// Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import WebSocket from 'ws';
import { createBridgeServer, outputBudget, sendWithinBudget } from '../server.mjs';

function connect(server, origin = `http://127.0.0.1:${server.port}`) {
  return new WebSocket(`ws://127.0.0.1:${server.port}/native`, { origin });
}
function response(socket, request) {
  return new Promise((resolve, reject) => {
    const cleanup = () => { socket.off('message', listener); socket.off('error', failed); socket.off('close', closed); };
    const failed = error => { cleanup(); reject(error); };
    const closed = () => failed(new Error('Socket closed before the expected response'));
    const listener = data => {
      const message = JSON.parse(data.toString());
      if (message.request === request) { cleanup(); resolve(message); }
    };
    socket.on('message', listener); socket.once('error', failed); socket.once('close', closed);
  });
}

test('outbound backpressure counts UTF-8 bytes and terminates before crossing its budget', () => {
  const message = { type: 'error', error: '界' }, data = JSON.stringify(message);
  const sent = [];
  const socket = { readyState: WebSocket.OPEN, bufferedAmount: outputBudget - Buffer.byteLength(data),
    send(value) { sent.push(value); this.bufferedAmount += Buffer.byteLength(value); },
    terminate() { this.readyState = WebSocket.CLOSED; } };
  assert.equal(sendWithinBudget(socket, message), true); assert.deepEqual(sent, [data]);
  assert.equal(socket.bufferedAmount, outputBudget);
  assert.equal(sendWithinBudget(socket, message), false); assert.equal(socket.readyState, WebSocket.CLOSED);
  assert.deepEqual(sent, [data], 'overflow never enters the transport buffer');
  assert.equal(sendWithinBudget(socket, message), false); assert.deepEqual(sent, [data]);
});

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

test('queued request count and bytes are bounded before native startup completes', async () => {
  const server = await createBridgeServer({ port: 0 });
  try {
    for (const large of [false, true]) {
      const socket = connect(server); await once(socket, 'open');
      const fatal = new Promise((resolve, reject) => socket.on('message', data => {
        const message = JSON.parse(data.toString());
        if (message.fatal) { resolve(message); }
        else if (message.type === 'frame') { reject(new Error('Excess queued work was accepted')); }
      }));
      const closed = once(socket, 'close');
      // One TCP batch is delivered while startup is still awaiting its native frame.
      socket._socket.cork();
      socket.send(JSON.stringify({ request: 0, type: 'start', story: 'label.default' }));
      for (let request = 1; request <= (large ? 12 : 65); ++request) {
        socket.send(JSON.stringify(large
          ? { request, type: 'input', data: '\x07'.repeat(16384) }
          : { request, type: 'capture' }));
      }
      socket._socket.uncork();
      assert.match((await fatal).error, /Outstanding command budget exceeded/);
      assert.equal((await closed)[0], 1008);
    }
  } finally { await server.close(); }
  assert.equal(server.sessionCount, 0);
});

test('the exact request budget is accepted and completed commands release both counters', async () => {
  const server = await createBridgeServer({ port: 0 });
  const socket = connect(server); await once(socket, 'open');
  try {
    const completed = response(socket, 63);
    socket._socket.cork();
    socket.send(JSON.stringify({ request: 0, type: 'start', story: 'label.default' }));
    for (let request = 1; request < 64; ++request) { socket.send(JSON.stringify({ request, type: 'capture' })); }
    socket._socket.uncork();
    assert.equal((await completed).artifact.story, 'label.default');
    // Cumulative retained JSON exceeds 1 MiB, but only one command is outstanding.
    for (let request = 64; request < 76; ++request) {
      const result = response(socket, request);
      socket.send(JSON.stringify({ request, type: 'capture', padding: 'x'.repeat(96 * 1024) }));
      assert.equal((await result).artifact.story, 'label.default');
    }
    assert.equal(socket.listenerCount('error'), 0, 'completed response helpers release rejection listeners');
  } finally { socket.terminate(); await server.close(); }
  assert.equal(server.sessionCount, 0);
});
