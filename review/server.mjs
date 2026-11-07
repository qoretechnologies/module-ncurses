// Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT
import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import { WebSocket, WebSocketServer } from 'ws';
import { NativeStory, dimensions, registry } from './native.mjs';

const mime = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json',
  '.woff2': 'font/woff2', '.woff': 'font/woff', '.ttf': 'font/ttf', '.svg': 'image/svg+xml', '.png': 'image/png', '.ico': 'image/x-icon' };

export const outputBudget = 8 * 1024 * 1024;
/** Stop a non-reading peer before transport buffers can grow without bound. */
export function sendWithinBudget(ws, message) {
  if (ws.readyState !== WebSocket.OPEN) { return false; }
  const data = JSON.stringify(message);
  if (ws.bufferedAmount + Buffer.byteLength(data) > outputBudget) {
    ws.terminate(); return false;
  }
  ws.send(data); return true;
}

export async function createBridgeServer({ port = 6007, staticDir, allowedOrigins = [], qore = 'qore' } = {}) {
  const definitions = await registry(); const stories = new Map(definitions.map(story => [story.id, story]));
  const connections = new Set(); let stopping = false;
  const server = http.createServer(async (request, response) => {
    try {
      const url = new URL(request.url, 'http://127.0.0.1');
      if (url.pathname === '/health') { response.setHeader('Content-Type', 'application/json'); response.end(JSON.stringify({ sessions: connections.size })); return; }
      if (request.method !== 'GET' || !staticDir) { response.writeHead(404).end(); return; }
      const base = path.resolve(staticDir);
      const file = path.resolve(base, '.' + decodeURIComponent(url.pathname === '/' ? '/index.html' : url.pathname));
      if (!file.startsWith(base + path.sep)) { response.writeHead(403).end(); return; }
      const data = await fs.readFile(file);
      response.setHeader('Content-Type', mime[path.extname(file)] ?? 'application/octet-stream'); response.end(data);
    } catch { response.writeHead(404).end(); }
  });
  // A permitted 16 KiB input can expand sixfold as JSON control-character escapes.
  const sockets = new WebSocketServer({ noServer: true, maxPayload: 128 * 1024, perMessageDeflate: false });
  server.on('upgrade', (request, socket, head) => {
    const origin = request.headers.origin;
    const own = `http://127.0.0.1:${server.address().port}`;
    if (stopping || request.url !== '/native' || (origin !== own && !allowedOrigins.includes(origin)) || connections.size >= 4) {
      socket.end('HTTP/1.1 403 Forbidden\r\nConnection: close\r\n\r\n'); return;
    }
    sockets.handleUpgrade(request, socket, head, ws => sockets.emit('connection', ws));
  });
  sockets.on('connection', ws => {
    const connection = { ws, native: null, chain: Promise.resolve(), lastRequest: -1, closing: null,
      outstanding: 0, queuedBytes: 0 };
    connections.add(connection);
    const send = message => { if (!sendWithinBudget(ws, message)) { void connection.close(); } };
    connection.close = () => {
      if (!connection.closing) {
        connection.closing = (async () => {
          // A queued start observes the closed socket before spawning.
          if (connection.native) { await connection.native.close(); }
          connections.delete(connection);
        })();
      }
      return connection.closing;
    };
    ws.on('close', () => { void connection.close(); });
    ws.on('error', () => { ws.terminate(); void connection.close(); });
    ws.on('message', (data, binary) => {
      if (connection.closing || ws.readyState !== WebSocket.OPEN) { return; }
      // Count retained buffers before enqueueing, including the in-flight command.
      // Per-message bounds alone do not constrain a client sending faster than Qore.
      if (connection.outstanding >= 64 || connection.queuedBytes + data.length > 1024 * 1024) {
        send({ type: 'error', fatal: true, error: 'Outstanding command budget exceeded (64 requests or 1 MiB)' });
        ws.close(1008, 'Outstanding command budget exceeded'); void connection.close(); return;
      }
      ++connection.outstanding; connection.queuedBytes += data.length;
      connection.chain = connection.chain.then(async () => {
        if (connection.closing || ws.readyState !== WebSocket.OPEN) { return; }
        let message;
        try {
          if (binary) { throw new Error('Expected a JSON text command'); }
          message = JSON.parse(data.toString());
          if (!Number.isSafeInteger(message.request) || message.request <= connection.lastRequest) { throw new Error('Request IDs must increase'); }
          connection.lastRequest = message.request;
          if (message.type === 'start') {
            if (connection.native) { throw new Error('Reconnect to select another story'); }
            const definition = stories.get(message.story);
            if (!definition) { throw new Error('Unknown story ID'); }
            const geometry = dimensions(message.geometry ?? definition.geometry);
            send({ type: 'geometry', ...geometry });
            const native = connection.native = new NativeStory(definition, { geometry, monochrome: message.monochrome === true, qore });
            native.on('terminal', value => send({ type: 'terminal', data: value }));
            native.on('final', frame => {
              connection.chain = connection.chain.then(() => send(frame));
            });
            native.on('ended', () => {
              // Send the final command response first. The browser closes only after
              // its PTY/render barrier, so intentional exit cannot discard that frame.
              connection.chain = connection.chain.then(() => send({ type: 'ended' }));
            });
            native.on('geometry', value => send({ type: 'geometry', ...value }));
            native.on('failure', error => { send({ type: 'error', fatal: true, error: error.message }); ws.close(1011, 'Native session failed'); });
            const frame = await native.ready; send({ ...frame, request: message.request });
          } else {
            if (!connection.native) { throw new Error('Start a registered story first'); }
            if (message.type === 'close') {
              await connection.native.close(); send({ type: 'closed', request: message.request }); ws.close(1000); return;
            }
            const values = message.type === 'input' ? { data: message.data, encoding: message.encoding }
              : message.type === 'resize' ? dimensions(message) : {};
            const frame = await connection.native.command(message.type, values);
            send({ ...frame, request: message.request });
          }
        } catch (error) {
          send({ type: 'error', request: message?.request, error: error.message });
          if (!connection.native) { ws.close(1008, 'Invalid startup'); }
        }
      }).catch(error => { send({ type: 'error', fatal: true, error: error.message }); ws.close(1011); })
        .finally(() => { --connection.outstanding; connection.queuedBytes -= data.length; });
    });
  });
  await new Promise((resolve, reject) => { server.once('error', reject); server.listen(port, '127.0.0.1', resolve); });
  return {
    port: server.address().port, stories: definitions,
    get sessionCount() { return connections.size; },
    async close() {
      stopping = true;
      const closing = [...connections].map(connection => { connection.ws.terminate(); return connection.close(); });
      await Promise.all(closing); sockets.close();
      await new Promise((resolve, reject) => server.close(error => error ? reject(error) : resolve()));
    },
  };
}
