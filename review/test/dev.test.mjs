// Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { fileURLToPath } from 'node:url';
import fs from 'node:fs/promises';
import { chromium } from '@playwright/test';
import { registry } from '../native.mjs';
import { openStory, command, browserArgs } from '../browser.mjs';

test('documented development command serves Storybook and proxies the native session', { timeout: 60000 }, async () => {
  const child = spawn(process.execPath, ['dev.mjs'], { cwd: fileURLToPath(new URL('../', import.meta.url)), stdio: ['ignore', 'pipe', 'pipe'] });
  const exited = once(child, 'close'); let output = ''; let browser; let page; const diagnostics = []; const pageErrors = [];
  const ready = new Promise((resolve, reject) => {
    const read = data => { output += data; if (output.includes('Storybook ready!')) { resolve(); } };
    child.stdout.on('data', read); child.stderr.on('data', read);
    child.once('error', reject); child.once('close', () => reject(new Error('Development server closed before readiness: ' + output)));
  });
  try {
    await ready; browser = await chromium.launch({ args: browserArgs }); page = await browser.newPage();
    page.on('pageerror', error => pageErrors.push(error.message));
    page.on('console', message => { if (message.type() === 'error') { diagnostics.push(message.text()); } });
    page.on('requestfailed', request => diagnostics.push(`${request.url()}: ${request.failure()?.errorText}`));
    page.on('websocket', socket => {
      if (!socket.url().endsWith('/native')) { return; }
      socket.on('framesent', event => diagnostics.push(`WS sent ${socket.url()}: ${String(event.payload).slice(0, 140)}`));
      socket.on('framereceived', event => diagnostics.push(`WS received ${socket.url()}: ${String(event.payload).slice(0, 140)}`));
      socket.on('socketerror', error => diagnostics.push(`WS error: ${error}`));
    });
    const story = (await registry()).find(story => story.id === 'table.scrolling');
    assert.equal((await openStory(page, 'http://127.0.0.1:6006', story)).state.selected, 0);
    assert.equal((await command(page, 'input', '\x1bOF')).state.selected, 23);
    const reloaded = page.waitForEvent('framenavigated', frame => frame === page.mainFrame());
    const terminalPath = fileURLToPath(new URL('../terminal.mjs', import.meta.url));
    const metadata = await fs.stat(terminalPath);
    // Exercise the actual file watcher without modifying shared source bytes.
    await fs.utimes(terminalPath, metadata.atime, new Date());
    await reloaded;
    await page.locator('ncurses-native-terminal').waitFor();
    const restarted = await page.locator('ncurses-native-terminal').evaluate(element => element.ready);
    assert.equal(restarted.state.selected, 0);
    assert.equal((await command(page, 'input', '\x1bOF')).state.selected, 23);
    assert.deepEqual(pageErrors, []);
    await command(page, 'dispose');
  } catch (error) {
    const state = page && !page.isClosed() ? await page.evaluate(() => ({ fonts: document.fonts.status,
      socket: document.querySelector('ncurses-native-terminal')?.socket?.readyState })) : null;
    throw new Error(`${error.message}\n${JSON.stringify({ state, diagnostics })}\n${output}`, { cause: error });
  } finally {
    if (browser) { await browser.close(); }
    child.kill('SIGTERM'); await exited;
  }
  assert.doesNotMatch(output, /\bWARN\b|\bERROR\b/);
});
