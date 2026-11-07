// Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import { chromium } from '@playwright/test';
import { fileURLToPath } from 'node:url';
import { createBridgeServer } from '../server.mjs';
import { browserOptions, browserArgs, command, inputBytes, openStory } from '../browser.mjs';

test('every default, mouse and compact story follows registry interactions through browser input', { timeout: 180000 }, async () => {
  const server = await createBridgeServer({ port: 0, staticDir: fileURLToPath(new URL('../storybook-static/', import.meta.url)) });
  let browser;
  try {
    browser = await chromium.launch({ args: browserArgs });
    const page = await browser.newPage(browserOptions);
    const errors = []; page.on('pageerror', error => errors.push(error.message));
    for (const story of server.stories.filter(story => ['default', 'mouse', 'constrained'].includes(story.state) || ['text-editor.code', 'described-choice.submit'].includes(story.id))) {
      await openStory(page, `http://127.0.0.1:${server.port}`, story);
      const scripted = [];
      for (const step of story.steps) { scripted.push(await command(page, 'step')); }
      await command(page, 'reset');
      for (const [index, step] of story.steps.entries()) {
        if (step.size) { await command(page, 'resize', step.size.rows, step.size.cols); }
        if (step.event) {
          const event = step.event;
          if (event.type === 3) {
            const bounds = await page.locator('.xterm-screen').boundingBox();
            const size = await page.locator('ncurses-native-terminal').evaluate(e => ({ cols: e.term.cols, rows: e.term.rows }));
            const x = bounds.x + (event.mouse.x + 0.5) * bounds.width / size.cols;
            const y = bounds.y + (event.mouse.y + 0.5) * bounds.height / size.rows;
            if (event.mouse.button_state === 4) { await page.mouse.click(x, y); }
            else {
              await page.locator('.xterm-screen').dispatchEvent('wheel', { clientX: x, clientY: y,
                deltaMode: 1, deltaY: event.mouse.button_state === 65536 ? -1 : 1, bubbles: true });
            }
          } else if (event.type === 6) {
            await page.locator('ncurses-native-terminal').evaluate((e, text) => e.term.paste(text), event.ch);
          } else if (event.type === 5) { await page.keyboard.press('Alt+' + event.ch); }
          else if (event.type === 1) {
            const key = { '\x1b': 'Escape', '\x1a': 'Control+z', '\t': 'Tab', '\n': 'Enter', '\r': 'Enter', ' ': 'Space' }[event.ch];
            if (key) { await page.keyboard.press(key); } else { await page.keyboard.insertText(event.ch); }
          } else {
            const keys = { KEY_ENTER: 'Enter', KEY_UP: 'ArrowUp', KEY_DOWN: 'ArrowDown', KEY_LEFT: 'ArrowLeft', KEY_RIGHT: 'ArrowRight',
              KEY_HOME: 'Home', KEY_END: 'End', KEY_PPAGE: 'PageUp', KEY_NPAGE: 'PageDown', 'KEY_F(7)': 'F7', 'KEY_F(8)': 'F8' };
            assert.ok(keys[event.name], `Missing browser encoding for ${event.name}`); await page.keyboard.press(keys[event.name]);
          }
        }
        const actual = await command(page, 'capture');
        assert.deepEqual(actual.state, scripted[index].state, `${story.id}/${step.checkpoint} state`);
        assert.deepEqual(actual.frame, scripted[index].frame, `${story.id}/${step.checkpoint} composed frame`);
      }
      await command(page, 'dispose');
    }
    assert.deepEqual(errors, []);
  } finally { if (browser) { await browser.close(); } await server.close(); }
  assert.equal(server.sessionCount, 0);
});

test('input encoding rejects unsupported event types', () => {
  assert.throws(() => inputBytes({ type: 99 }), /No PTY encoding/);
  assert.throws(() => inputBytes({ type: 2, name: 'unknown' }), /No PTY encoding/);
});
