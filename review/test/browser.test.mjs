// Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import { chromium } from '@playwright/test';
import { createBridgeServer } from '../server.mjs';
import { fileURLToPath } from 'node:url';
import { openStory, command } from '../browser.mjs';
import { imageDiff } from '../artifacts.mjs';

test('Storybook mounts real PTY output and native completion barriers', { timeout: 30000 }, async () => {
  const server = await createBridgeServer({ port: 0, staticDir: fileURLToPath(new URL('../storybook-static/', import.meta.url)) });
  const browser = await chromium.launch();
  try {
    const page = await browser.newPage({ viewport: { width: 1400, height: 1000 }, deviceScaleFactor: 1 });
    const errors = []; page.on('pageerror', error => errors.push(error.message));
    await page.goto(`http://127.0.0.1:${server.port}/iframe.html?id=native-tablewidget--scrolling&viewMode=story`);
    await page.locator('ncurses-native-terminal').waitFor();
    const initial = await page.locator('ncurses-native-terminal').evaluate(element => element.ready);
    assert.equal(initial.state.selected, 0);
    const advances = await page.evaluate(() => {
      const canvas = document.createElement('canvas'); const context = canvas.getContext('2d');
      context.font = '14px "Noto Sans Mono", "Noto Sans SC"';
      return ['A', '─', '│', '┌', '┐', '└', '┘', '●'].map(char => context.measureText(char).width);
    });
    assert.ok(advances.every(width => Math.abs(width - advances[0]) < 0.001), 'ACS borders and selection markers must occupy one mono cell');
    const last = await page.locator('ncurses-native-terminal').evaluate(element => element.input('\x1bOF'));
    assert.equal(last.state.selected, 23);
    const cells = await page.locator('ncurses-native-terminal').evaluate(element => Array.from({ length: element.term.rows }, (_, y) => element.term.buffer.active.getLine(y).translateToString()));
    assert.ok(cells.some(line => line.includes('Row 23')));
    await page.locator('.native-terminal').screenshot({ path: '/tmp/ncurses-ux-browser-table.png' });
    const reset = await page.locator('ncurses-native-terminal').evaluate(element => element.reset());
    assert.deepEqual(reset, initial);
    await page.locator('ncurses-native-terminal').evaluate(element => element.dispose());
    assert.deepEqual(errors, []);
  } finally { await browser.close(); await server.close(); }
});

test('same-page story replacement tears down prior PTYs, including mounting and startup failures', { timeout: 30000 }, async () => {
  const server = await createBridgeServer({ port: 0, staticDir: fileURLToPath(new URL('../storybook-static/', import.meta.url)) });
  const browser = await chromium.launch();
  try {
    const page = await browser.newPage();
    await openStory(page, `http://127.0.0.1:${server.port}`, server.stories.find(story => story.id === 'label.default'));
    for (const id of ['table.scrolling', 'text-editor.boundaries', 'completion-popup.overlap', 'label.default']) {
      const story = server.stories.find(story => story.id === id);
      const frame = await page.evaluate(async story => {
        document.querySelector('ncurses-native-terminal').remove();
        const cancelled = document.createElement('ncurses-native-terminal'); cancelled.definition = story;
        document.body.append(cancelled); cancelled.remove();
        const next = document.createElement('ncurses-native-terminal'); next.definition = story;
        document.body.append(next); return await next.ready;
      }, story);
      assert.equal(frame.story, id);
      assert.deepEqual(await command(page, 'reset'), frame);
    }
    await command(page, 'dispose');
  } finally { await browser.close(); await server.close(); }
  assert.equal(server.sessionCount, 0);
  const failed = await createBridgeServer({ port: 0, qore: '/nonexistent/qore', staticDir: fileURLToPath(new URL('../storybook-static/', import.meta.url)) });
  const failedBrowser = await chromium.launch();
  try {
    const page = await failedBrowser.newPage();
    await assert.rejects(openStory(page, `http://127.0.0.1:${failed.port}`, failed.stories[0]), /No such file|Native/);
  } finally { await failedBrowser.close(); await failed.close(); }
  assert.equal(failed.sessionCount, 0);
});

test('missing Storybook registration fails within the readiness deadline', { timeout: 10000 }, async () => {
  const server = await createBridgeServer({ port: 0, staticDir: fileURLToPath(new URL('../storybook-static/', import.meta.url)) });
  const browser = await chromium.launch();
  try {
    const page = await browser.newPage();
    await assert.rejects(openStory(page, `http://127.0.0.1:${server.port}`,
      { ...server.stories[0], id: 'label.unregistered' }, false, server.stories[0].geometry, 1000), /Story readiness deadline exceeded/);
    assert.equal(server.sessionCount, 0);
  } finally { await browser.close(); await server.close(); }
});

test('editor and overlapping popup use browser keyboard, paste, mouse and resize', { timeout: 30000 }, async () => {
  const server = await createBridgeServer({ port: 0, staticDir: fileURLToPath(new URL('../storybook-static/', import.meta.url)) });
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1400, height: 1000 }, deviceScaleFactor: 1 });
  const open = async (id, args = '') => {
    await page.goto(`http://127.0.0.1:${server.port}/iframe.html?id=${id}&viewMode=story${args}`);
    return await page.evaluate(async () => {
      await customElements.whenDefined('ncurses-native-terminal');
      const element = document.querySelector('ncurses-native-terminal') ?? await new Promise(resolve => {
        const observer = new MutationObserver(() => {
          const element = document.querySelector('ncurses-native-terminal');
          if (element) { observer.disconnect(); resolve(element); }
        });
        observer.observe(document.body, { childList: true, subtree: true });
      });
      return await element.ready;
    });
  };
  const view = () => page.locator('ncurses-native-terminal');
  try {
    const editor = await open('native-texteditorwidget--boundaries');
    assert.equal(editor.frame.cols, 8);
    await page.keyboard.type('Z');
    let capture = await view().evaluate(element => element.capture());
    assert.equal(capture.state.text, editor.state.text + 'Z');
    await view().evaluate(element => element.term.paste('界é'));
    capture = await view().evaluate(element => element.capture());
    assert.equal(capture.state.text, editor.state.text + 'Z界é');
    capture = await view().evaluate(element => element.resize(2, 4));
    assert.equal(capture.frame.cols, 4); assert.ok(capture.state.scroll > 0);
    await view().evaluate(element => element.dispose());
    await open('native-completionpopupwidget--overlap');
    await page.keyboard.press('Escape');
    capture = await view().evaluate(element => element.capture());
    assert.equal(capture.state.modal, false); assert.equal(capture.state.focus, 'TextEditorWidget');
    assert.equal(capture.frame.cursor.visibility, 1);
    await view().evaluate(element => element.dispose());
    await open('native-tablewidget--scrolling', '&args=monochrome:true');
    const box = await page.locator('.native-terminal').boundingBox();
    await page.mouse.click(box.x + box.width * 2 / 32, box.y + box.height * 3.5 / 8);
    capture = await view().evaluate(element => element.capture());
    assert.equal(capture.state.selected, 2); assert.equal(capture.frame.colors_enabled, false);
    await view().evaluate(element => element.dispose());
  } finally { await browser.close(); await server.close(); }
});

test('overlapping commands wait for rendered frames and disposal rejects queued work', { timeout: 30000 }, async () => {
  const server = await createBridgeServer({ port: 0, staticDir: fileURLToPath(new URL('../storybook-static/', import.meta.url)) });
  const browser = await chromium.launch();
  try {
    const page = await browser.newPage();
    await openStory(page, `http://127.0.0.1:${server.port}`, server.stories.find(story => story.id === 'text-editor.empty'));
    const result = await page.locator('ncurses-native-terminal').evaluate(async element => {
      const send = element.socket.send.bind(element.socket), onRender = element.term.onRender.bind(element.term);
      const sent = []; element.socket.send = data => { sent.push(JSON.parse(data).type); send(data); };
      const holdNextRender = () => {
        let release, signal; const held = new Promise(resolve => { signal = resolve; });
        Object.defineProperty(element.term, 'onRender', { configurable: true, value: listener => {
          Object.defineProperty(element.term, 'onRender', { configurable: true, value: onRender });
          return onRender(event => { if (!release) { release = () => listener(event); signal(); } });
        } });
        return { held, release: () => release() };
      };
      const firstRender = holdNextRender();
      const first = element.input('X'), second = element.input('Y');
      await firstRender.held;
      const sentBeforeRender = [...sent];
      firstRender.release();
      const frames = await Promise.all([first, second]);
      const lines = Array.from({ length: element.term.rows }, (_, y) => element.term.buffer.active.getLine(y).translateToString());
      if (sentBeforeRender.length !== 1) { return { sentBeforeRender, texts: frames.map(frame => frame.state.text), lines }; }
      const finalRender = holdNextRender();
      const finalInput = element.input('Z'); await finalRender.held;
      const queued = element.capture().then(() => 'unexpected completion', error => error.message);
      const disposed = element.dispose(); finalRender.release();
      await finalInput; await disposed;
      return { sentBeforeRender, texts: frames.map(frame => frame.state.text), lines, queued: await queued, pending: element.requests.size };
    });
    assert.deepEqual(result.sentBeforeRender, ['input']);
    assert.deepEqual(result.texts, ['X', 'XY']); assert.ok(result.lines.some(line => line.includes('XY')));
    assert.match(result.queued, /closing|disposed/); assert.equal(result.pending, 0);
    assert.equal(server.sessionCount, 0);
  } finally { await browser.close(); await server.close(); }
});

test('terminal image geometry is independent of surrounding system-font metrics', { timeout: 30000 }, async () => {
  const server = await createBridgeServer({ port: 0, staticDir: fileURLToPath(new URL('../storybook-static/', import.meta.url)) });
  const browser = await chromium.launch();
  try {
    const page = await browser.newPage();
    await openStory(page, `http://127.0.0.1:${server.port}`, server.stories.find(story => story.id === 'completion-popup.focused'));
    let reference;
    for (const [font, repeats] of ['system-ui', 'serif', 'monospace'].flatMap(font => [1, 2, 5, 17, 18, 31].map(repeats => [font, repeats]))) {
      await page.locator('ncurses-native-terminal').evaluate((element, [font, repeats]) => {
        element.style.fontFamily = font;
        element.querySelector('p').textContent = 'Surrounding review instructions '.repeat(repeats);
      }, [font, repeats]);
      await command(page, 'capture');
      const bounds = await page.locator('.native-terminal').boundingBox();
      assert.equal(bounds.y % 1, 0, `${font}: fractional placement changes screenshot rounding and glyph rasterization`);
      const current = await page.locator('.native-terminal').screenshot();
      if (reference) { const diff = imageDiff(reference, current); assert.equal(diff.pixels, 0); assert.equal(diff.resized, false); }
      else { reference = current; }
    }
    await command(page, 'dispose');
  } finally { await browser.close(); await server.close(); }
});
