// Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import { constants } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { chromium } from '@playwright/test';
import { createBridgeServer } from '../server.mjs';
import { fileURLToPath } from 'node:url';
import { openStory, command, browserArgs } from '../browser.mjs';
import { imageDiff } from '../artifacts.mjs';

test('Storybook mounts real PTY output and native completion barriers', { timeout: 30000 }, async () => {
  const server = await createBridgeServer({ port: 0, staticDir: fileURLToPath(new URL('../storybook-static/', import.meta.url)) });
  const browser = await chromium.launch({ args: browserArgs });
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
  const browser = await chromium.launch({ args: browserArgs });
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
  const failedBrowser = await chromium.launch({ args: browserArgs });
  try {
    const page = await failedBrowser.newPage();
    await assert.rejects(openStory(page, `http://127.0.0.1:${failed.port}`, failed.stories[0]), /No such file|Native/);
  } finally { await failedBrowser.close(); await failed.close(); }
  assert.equal(failed.sessionCount, 0);
});

test('missing Storybook registration fails within the readiness deadline', { timeout: 10000 }, async () => {
  const server = await createBridgeServer({ port: 0, staticDir: fileURLToPath(new URL('../storybook-static/', import.meta.url)) });
  const browser = await chromium.launch({ args: browserArgs });
  try {
    const page = await browser.newPage();
    await assert.rejects(openStory(page, `http://127.0.0.1:${server.port}`,
      { ...server.stories[0], id: 'label.unregistered' }, false, server.stories[0].geometry, 1000), /Story readiness deadline exceeded/);
    assert.equal(server.sessionCount, 0);
  } finally { await browser.close(); await server.close(); }
});

test('editor and overlapping popup use browser keyboard, paste, mouse and resize', { timeout: 30000 }, async () => {
  const server = await createBridgeServer({ port: 0, staticDir: fileURLToPath(new URL('../storybook-static/', import.meta.url)) });
  const browser = await chromium.launch({ args: browserArgs });
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
  const browser = await chromium.launch({ args: browserArgs });
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

test('manual input blocks recorded checkpoints before rendering and reset preserves command ordering', { timeout: 30000 }, async () => {
  const server = await createBridgeServer({ port: 0, staticDir: fileURLToPath(new URL('../storybook-static/', import.meta.url)) });
  const browser = await chromium.launch({ args: browserArgs });
  try {
    const page = await browser.newPage();
    await openStory(page, `http://127.0.0.1:${server.port}`, server.stories.find(story => story.id === 'button.default'));
    const result = await page.locator('ncurses-native-terminal').evaluate(async element => {
      const send = element.socket.send.bind(element.socket), onRender = element.term.onRender.bind(element.term);
      const sent = []; element.socket.send = data => { sent.push(JSON.parse(data).type); send(data); };
      let release, signal; const held = new Promise(resolve => { signal = resolve; });
      Object.defineProperty(element.term, 'onRender', { configurable: true, value: listener => {
        Object.defineProperty(element.term, 'onRender', { configurable: true, value: onRender });
        return onRender(event => { if (!release) { release = () => listener(event); signal(); } });
      } });
      const input = element.input(' ');
      await held;
      const beforeRender = { disabled: element.nextStep.disabled, title: element.nextStep.title };
      element.nextStep.click();
      const blocked = await element.step().then(() => 'unexpected step', error => error.message);
      const sentBeforeRender = [...sent];
      // A reset accepted after the edit makes the following recorded step valid.
      const reset = element.reset(), step = element.step();
      release();
      const frames = await Promise.all([input, reset, step]);
      // Conversely, an edit accepted after reset must still invalidate replay.
      const nextReset = element.reset(), nextInput = element.input(' ');
      const blockedAfterReset = await element.step().then(() => 'unexpected step', error => error.message);
      await Promise.all([nextReset, nextInput]);
      return { beforeRender, blocked, sentBeforeRender, activations: frames.map(frame => frame.state.activations),
        indices: frames.map(frame => frame.index), blockedAfterReset, disabled: element.nextStep.disabled, sent };
    });
    assert.equal(result.beforeRender.disabled, true);
    assert.match(result.beforeRender.title, /Reset/);
    assert.match(result.blocked, /Reset the story/);
    assert.deepEqual(result.sentBeforeRender, ['input']);
    assert.deepEqual(result.activations, [1, 0, 0]);
    assert.deepEqual(result.indices, [-1, -1, 0]);
    assert.match(result.blockedAfterReset, /Reset the story/);
    assert.equal(result.disabled, true);
    assert.deepEqual(result.sent, ['input', 'reset', 'step', 'reset', 'input']);
    await command(page, 'dispose');
  } finally { await browser.close(); await server.close(); }
});

test('terminal image geometry is independent of surrounding system-font metrics', { timeout: 30000 }, async () => {
  const server = await createBridgeServer({ port: 0, staticDir: fileURLToPath(new URL('../storybook-static/', import.meta.url)) });
  const browser = await chromium.launch({ args: browserArgs });
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

test('button presses, choice hierarchy, compact recovery and code assistance are usable with real browser input', { timeout: 60000 }, async () => {
  const server = await createBridgeServer({ port: 0, staticDir: fileURLToPath(new URL('../storybook-static/', import.meta.url)) });
  const browser = await chromium.launch({ args: browserArgs });
  try {
    const page = await browser.newPage({ viewport: { width: 1400, height: 1000 }, deviceScaleFactor: 1 });
    const errors = []; page.on('pageerror', error => errors.push(error.message));
    const open = (id, mono = false) => openStory(page, `http://127.0.0.1:${server.port}`, server.stories.find(story => story.id === id), mono);
    const cell = async (x, y) => {
      const bounds = await page.locator('.xterm-screen').boundingBox();
      const size = await page.locator('ncurses-native-terminal').evaluate(e => ({ cols: e.term.cols, rows: e.term.rows }));
      return { x: bounds.x + (x + 0.5) * bounds.width / size.cols, y: bounds.y + (y + 0.5) * bounds.height / size.rows };
    };
    await open('button.default');
    const button = await cell(4, 0); await page.mouse.move(button.x, button.y); await page.mouse.down();
    let frame = await command(page, 'capture'); assert.equal(frame.state.pressed, true); assert.equal(frame.state.activations, 0);
    assert.match(await page.locator('.native-feedback').textContent(), /Release inside/);
    await page.mouse.up(); frame = await command(page, 'capture'); assert.equal(frame.state.activations, 1); assert.equal(frame.state.pressed, false);
    assert.match(await page.locator('.native-feedback').textContent(), /Preview complete/);
    await page.mouse.down(); const outside = await cell(4, 4); await page.mouse.move(outside.x, outside.y); await page.mouse.up();
    frame = await command(page, 'capture'); assert.equal(frame.state.activations, 1); assert.equal(frame.state.pressed, false);
    await page.getByRole('button', { name: 'Focus terminal', exact: true }).click(); await page.keyboard.press('Space');
    frame = await command(page, 'capture'); assert.equal(frame.state.activations, 2);
    assert.equal(await page.getByRole('button', { name: 'Next checkpoint' }).isDisabled(), true);
    await command(page, 'reset'); assert.equal(await page.getByRole('button', { name: 'Next checkpoint' }).isEnabled(), true);
    await command(page, 'step'); await command(page, 'step'); assert.equal(await page.getByRole('button', { name: 'Next checkpoint' }).isDisabled(), true);
    for (const mono of [false, true]) {
      await open('described-choice.default', mono);
      await page.keyboard.press('ArrowDown'); frame = await command(page, 'capture');
      assert.equal(frame.state.highlight, 1); assert.equal(frame.state.choice, 'preview');
      await page.keyboard.press('Enter'); frame = await command(page, 'capture'); assert.equal(frame.state.choice, 'execute');
      await page.keyboard.press('ArrowUp'); await page.keyboard.press('Space'); frame = await command(page, 'capture'); assert.equal(frame.state.choice, 'preview');
      const execute = await cell(5, 4); await page.mouse.click(execute.x, execute.y); frame = await command(page, 'capture'); assert.equal(frame.state.choice, 'execute');
      await page.locator('.native-terminal').screenshot({ path: `/tmp/ncurses-choice-${mono ? 'mono' : 'color'}.png` });
    }
    await open('described-choice.submit'); await page.keyboard.press('Enter'); await command(page, 'capture');
    assert.match(await page.locator('.native-feedback').textContent(), /Submitted.*Reset/);
    await open('file-browser.constrained'); await command(page, 'resize', 4, 12);
    assert.match(await page.locator('.native-viewport-note').textContent(), /Stress viewport/);
    await page.getByRole('button', { name: 'Standard', exact: true }).click(); frame = await command(page, 'capture'); assert.equal(frame.frame.cols, 80);
    assert.equal(await page.locator('.native-viewport-note').textContent(), '');
    await open('text-editor.code'); await page.keyboard.press('F8'); frame = await command(page, 'capture'); assert.equal(frame.state.modal, true);
    await page.keyboard.press('ArrowDown'); await page.keyboard.press('Enter'); frame = await command(page, 'capture');
    assert.match(frame.state.text, /printf\($/); assert.equal(frame.state.focus, 'TextEditorWidget');
    assert.ok(frame.frame.cells.map(cell => cell.text).join('').includes('fmt'));
    await page.locator('.native-terminal').screenshot({ path: '/tmp/ncurses-code-editor.png' });
    await page.keyboard.press('Control+z'); frame = await command(page, 'capture'); assert.match(frame.state.text, /pri$/);
    await page.keyboard.press('F8'); await page.keyboard.press('Escape'); frame = await command(page, 'capture'); assert.equal(frame.state.modal, false);
    await page.keyboard.type('ntf');
    for (let i = 0; i < 3; i++) { await page.keyboard.press('ArrowLeft'); }
    await page.keyboard.press('F8'); await page.keyboard.press('ArrowDown'); await page.keyboard.press('Enter');
    frame = await command(page, 'capture'); assert.match(frame.state.text, /printf\($/); assert.ok(!frame.state.text.includes('printf(ntf'));
    await page.keyboard.press('Control+z'); frame = await command(page, 'capture'); assert.match(frame.state.text, /printf$/);
    await command(page, 'resize', 20, 100);
    await page.keyboard.press('F8'); frame = await command(page, 'capture'); assert.equal(frame.state.modal, true);
    const assistanceOutside = await cell(99, 0); await page.mouse.click(assistanceOutside.x, assistanceOutside.y);
    frame = await command(page, 'capture'); assert.equal(frame.state.modal, false); assert.equal(frame.state.focus, 'TextEditorWidget');
    assert.ok(!frame.frame.cells.map(cell => cell.text).join('').includes('Assistance ['));
    await command(page, 'reset');
    await page.keyboard.press('F8'); frame = await command(page, 'capture'); assert.equal(frame.state.modal, true);
    const draftBeforeResize = frame.state.text;
    frame = await command(page, 'resize', 1, 1); assert.equal(frame.state.modal, false);
    assert.equal(frame.state.focus, 'TextEditorWidget');
    await page.keyboard.type('x'); frame = await command(page, 'capture'); assert.equal(frame.state.text, draftBeforeResize + 'x');
    await command(page, 'resize', 20, 100);
    await page.keyboard.press('F8'); frame = await command(page, 'capture'); assert.equal(frame.state.modal, true);
    await page.keyboard.press('Escape'); frame = await command(page, 'capture'); assert.equal(frame.state.modal, false);
    assert.equal(frame.state.text, draftBeforeResize + 'x'); assert.equal(frame.state.focus, 'TextEditorWidget');
    assert.deepEqual(errors, []); await command(page, 'dispose');
  } finally { await browser.close(); await server.close(); }
});

test('WebGL draws contiguous frame edges and reports lost graphics contexts', { timeout: 30000 }, async () => {
  const { PNG } = await import('pngjs');
  const server = await createBridgeServer({ port: 0, staticDir: fileURLToPath(new URL('../storybook-static/', import.meta.url)) });
  const browser = await chromium.launch({ args: browserArgs });
  try {
    const page = await browser.newPage();
    await openStory(page, `http://127.0.0.1:${server.port}`, server.stories.find(story => story.id === 'completion-popup.focused'));
    const data = await page.locator('ncurses-native-terminal').evaluate(e => ({ renderer: e.dataset.renderer, cols: e.term.cols, rows: e.term.rows,
      lines: Array.from({ length: e.term.rows }, (_, y) => e.term.buffer.active.getLine(y).translateToString()) }));
    assert.equal(data.renderer, 'webgl');
    const png = PNG.sync.read(await page.locator('.xterm-screen').screenshot());
    const cellWidth = png.width / data.cols, cellHeight = png.height / data.rows;
    const lit = (x, y) => { const offset = (y * png.width + x) * 4; return png.data[offset] > 60 || png.data[offset + 1] > 60 || png.data[offset + 2] > 60; };
    let joins = 0;
    for (let y = 0; y + 1 < data.rows; y++) {
      for (let x = 0; x < data.cols; x++) {
        if (data.lines[y][x] !== '│' || data.lines[y + 1][x] !== '│') { continue; }
        const middle = Math.floor((x + 0.5) * cellWidth);
        for (let py = Math.ceil(y * cellHeight); py < Math.floor((y + 2) * cellHeight); py++) {
          assert.ok([-2, -1, 0, 1, 2].some(dx => lit(middle + dx, py)), `border gap at row ${py}`);
        }
        joins++;
      }
    }
    assert.ok(joins > 0, 'the real popup must contain adjacent vertical border cells');
    const lost = await page.locator('ncurses-native-terminal').evaluate(async e => {
      const closed = new Promise(resolve => e.socket.addEventListener('close', resolve, { once: true }));
      const canvas = [...e.querySelectorAll('canvas')].find(c => c.getContext('webgl2'));
      canvas.getContext('webgl2').getExtension('WEBGL_lose_context').loseContext();
      await closed; return { closing: e.closing, message: e.status.textContent };
    });
    assert.equal(lost.closing, true); assert.match(lost.message, /Reload the story/);
    await command(page, 'dispose');
  } finally { await browser.close(); await server.close(); }
});

test('empty hidden-cursor frames erase previously rendered cursor pixels', { timeout: 30000 }, async () => {
  const { PNG } = await import('pngjs');
  const server = await createBridgeServer({ port: 0, staticDir: fileURLToPath(new URL('../storybook-static/', import.meta.url)) });
  const browser = await chromium.launch({ args: browserArgs });
  try {
    const page = await browser.newPage();
    for (const id of ['transcript.empty', 'code-view.empty']) {
      for (const mono of [false, true]) {
        const frame = await openStory(page, `http://127.0.0.1:${server.port}`, server.stories.find(story => story.id === id), mono);
        assert.equal(frame.frame.cursor.visibility, 0);
        // A cursor-only redraw of an otherwise blank terminal must clear the old
        // cursor too. Await actual rendering and compositor screenshots each time.
        const cursor = async visible => {
          await page.locator('ncurses-native-terminal').evaluate(async (element, visible) => {
            element.term.blur();
            await new Promise(resolve => element.term.write(`\x1b[1;1H\x1b[?25${visible ? 'h' : 'l'}`, resolve));
          }, visible);
          await command(page, 'capture');
          const png = PNG.sync.read(await page.locator('.native-terminal').screenshot());
          let foreground = 0;
          for (let i = 0; i < png.data.length; i += 4) {
            if (png.data[i] !== 16 || png.data[i + 1] !== 20 || png.data[i + 2] !== 24 || png.data[i + 3] !== 255) { foreground++; }
          }
          return foreground;
        };
        assert.ok(await cursor(true) > 0, `${id}: visible cursor must be drawn`);
        assert.equal(await cursor(false), 0, `${id}: hidden cursor must leave a blank terminal`);
        await command(page, 'dispose');
      }
    }
  } finally { await browser.close(); await server.close(); }
});

test('glyph rasterization is identical with grayscale and RGB host font profiles', { timeout: 30000 }, async () => {
  const fs = await import('node:fs/promises'); const os = await import('node:os'); const path = await import('node:path');
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'ncurses-font-profiles-'));
  const server = await createBridgeServer({ port: 0, staticDir: fileURLToPath(new URL('../storybook-static/', import.meta.url)) });
  const images = [];
  try {
    for (const profile of ['none', 'rgb']) {
      const config = path.join(directory, `${profile}.conf`);
      await fs.writeFile(config, `<?xml version="1.0"?><!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd"><fontconfig><include>/etc/fonts/fonts.conf</include><match target="font"><edit name="rgba" mode="assign"><const>${profile}</const></edit></match></fontconfig>`);
      const browser = await chromium.launch({ args: browserArgs, env: { ...process.env, FONTCONFIG_FILE: config } });
      try {
        const page = await browser.newPage({ viewport: { width: 1400, height: 1000 }, deviceScaleFactor: 1 });
        await openStory(page, `http://127.0.0.1:${server.port}`, server.stories.find(story => story.id === 'label.default'));
        images.push(await page.locator('.native-terminal').screenshot()); await command(page, 'dispose');
      } finally { await browser.close(); }
    }
    assert.equal(imageDiff(images[0], images[1]).pixels, 0);
  } finally { await server.close(); await fs.rm(directory, { recursive: true, force: true }); }
});


test('qrepl quit renders its final frame, closes normally and Reset starts a new session', { timeout: 30000 }, async () => {
  const server = await createBridgeServer({ port: 0, staticDir: fileURLToPath(new URL('../storybook-static/', import.meta.url)) });
  const browser = await chromium.launch({ args: browserArgs });
  try {
    const page = await browser.newPage({ viewport: { width: 1400, height: 1000 } });
    const errors = []; page.on('pageerror', error => errors.push(error.message));
    await page.goto(`http://127.0.0.1:${server.port}/iframe.html?id=native-qrepl--default&viewMode=story`);
    const terminal = page.locator('ncurses-native-terminal');
    await terminal.evaluate(element => element.ready);
    const evaluated = await command(page, 'step');
    assert.equal(evaluated.state.text, ''); assert.equal(evaluated.state.empty, false);
    assert.ok(evaluated.frame.cells.map(cell => cell.text).join('').includes('42'));
    assert.doesNotMatch(await page.locator('.native-feedback').textContent(), /Empty state/);
    const result = await terminal.evaluate(async element => {
      const closed = new Promise(resolve => element.socket.addEventListener('close', event => resolve(event.code), { once: true }));
      const frame = await element.input('\x11');
      return { code: await closed, modal: frame.state.modal, error: element.status.dataset.error, status: element.status.textContent };
    });
    assert.equal(result.code, 1000); assert.equal(result.modal, false); assert.equal(result.error, undefined);
    assert.match(result.status, /Session ended/);
    await page.getByRole('button', { name: 'Reset story', exact: true }).click();
    const fresh = await terminal.evaluate(element => element.ready);
    assert.equal(fresh.state.text, '6 * 7');
    assert.equal((await terminal.evaluate(element => element.capture())).state.evaluating, false);
    assert.deepEqual(errors, []);
  } finally { await browser.close(); await server.close(); }
});

test('finish-and-quit renders the final result and error before closing the browser transport', { timeout: 30000 }, async () => {
  const server = await createBridgeServer({ port: 0, staticDir: fileURLToPath(new URL('../storybook-static/', import.meta.url)) });
  const browser = await chromium.launch({ args: browserArgs });
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'ncurses-browser-final-'));
  try {
    for (const failure of [false, true]) {
      const gate = path.join(dir, failure ? 'error' : 'result'); await promisify(execFile)('mkfifo', [gate]);
      const page = await browser.newPage({ viewport: { width: 1400, height: 1000 } });
      let active = false; let released = false;
      try {
        await page.goto(`http://127.0.0.1:${server.port}/iframe.html?id=native-qrepl--default&viewMode=story`);
        const terminal = page.locator('ncurses-native-terminal'); await terminal.evaluate(element => element.ready);
        const action = failure ? 'throw "BROWSER-" + "FINAL-ERROR", "completed with an error";'
          : 'stdout.write("browser-final-" + "result\\n");';
        const source = `ReadOnlyFile gate("${gate}"); gate.readLine(); ${action}`;
        const started = await terminal.evaluate((element, source) => element.input('\x15' + source + '\r'), source);
        active = true; assert.equal(started.state.evaluating, true);
        const accepted = await terminal.evaluate(async element => {
          element.finalEvidence = new Promise(resolve => element.socket.addEventListener('close', event => resolve({
            code: event.code, frame: element.frame, error: element.status.dataset.error, status: element.status.textContent,
            rendered: Array.from({ length: element.term.rows }, (_, y) => element.term.buffer.active.getLine(y).translateToString()).join(''),
          }), { once: true }));
          const rejected = await element.reset().then(() => '', error => error.message);
          await element.resize(12, 60);
          await element.input('\x11'); const accepted = await element.input('\r');
          return { rejected, interacted: element.interacted, evaluating: accepted.state.evaluating, modal: accepted.state.modal };
        });
        assert.match(accepted.rejected, /GALLERY-BUSY/); assert.equal(accepted.interacted, true);
        assert.equal(accepted.evaluating, true); assert.equal(accepted.modal, false);
        await fs.writeFile(gate, 'release\n'); released = true;
        const result = await terminal.evaluate(element => element.finalEvidence);
        const expected = failure ? 'BROWSER-FINAL-ERROR' : 'browser-final-result';
        assert.equal(result.code, 1000); assert.equal(result.frame.state.evaluating, false);
        assert.ok(result.frame.frame.cells.map(cell => cell.text).join('').includes(expected));
        assert.ok(result.rendered.includes(expected)); assert.equal(result.error, undefined); assert.match(result.status, /Session ended/);
      } finally {
        try {
          if (active && !released) {
            try {
              const writer = await fs.open(gate, constants.O_WRONLY | constants.O_NONBLOCK);
              try { await writer.write('release\n'); } finally { await writer.close(); }
            } catch (error) { if (error.code !== 'ENXIO') { throw error; } }
          }
        } finally { await page.close(); }
      }
    }
  } finally {
    try { await browser.close(); await server.close(); }
    finally { await fs.rm(dir, { recursive: true, force: true }); }
  }
});
