// Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT
import './generate.mjs';
import { spawn } from 'node:child_process';
import { createBridgeServer } from './server.mjs';
import { fileURLToPath } from 'node:url';
import { hostname } from 'node:os';
const directory = fileURLToPath(new URL('./', import.meta.url));
const host = process.env.STORYBOOK_HOST ?? '127.0.0.1';
const publicUrl = `http://${hostname()}:6006`;
const bridge = await createBridgeServer({ allowedOrigins: ['http://127.0.0.1:6006', 'http://localhost:6006', publicUrl] });
const child = spawn(process.execPath, ['node_modules/storybook/dist/bin/dispatcher.js', 'dev', '--host', host, '--port', '6006', '--ci', '--no-open', '--disable-telemetry'], { cwd: directory, stdio: 'inherit' });
let closing;
function close() {
  closing ??= (async () => { child.kill('SIGTERM'); await bridge.close(); })();
  return closing;
}
process.once('SIGINT', () => { void close(); }); process.once('SIGTERM', () => { void close(); });
child.once('error', error => { console.error(error.message); process.exitCode = 1; void close(); });
child.once('exit', code => { process.exitCode = code ?? 0; void close(); });
console.log(`Native bridge bound to 127.0.0.1:6007; Storybook binds to ${host}:6006 (${publicUrl})`);
