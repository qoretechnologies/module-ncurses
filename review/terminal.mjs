// Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT
import { Terminal } from '@xterm/xterm';
import '@xterm/xterm/css/xterm.css';
import './fonts/terminal.css';
import '@fontsource/noto-sans-sc/400.css';
import '@fontsource/noto-emoji/400.css';
import './terminal.css';

export const theme = { background: '#101418', foreground: '#ecf0f4', cursor: '#ecf0f4',
  black: '#101418', red: '#e06c75', green: '#98c379', yellow: '#e5c07b', blue: '#61afef', magenta: '#c678dd', cyan: '#56b6c2', white: '#d8dee9',
  brightBlack: '#7f848e', brightRed: '#ff8f98', brightGreen: '#b4e095', brightYellow: '#ffe09a', brightBlue: '#8ac8ff', brightMagenta: '#e3a1ff', brightCyan: '#8bdbe3', brightWhite: '#ffffff' };
let previousDisposal = Promise.resolve();
function deferred() {
  let resolve, reject; const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  promise.catch(() => {}); return { promise, resolve, reject };
}

export class NativeTerminal extends HTMLElement {
  constructor() {
    super(); this.sequence = -1; this.requests = new Map(); this.fences = new Map(); this.seenFences = new Set();
    this.start = deferred(); this.ready = this.start.promise; this.resources = []; this.closing = false;
    this.renders = new Set(); this.requestChain = Promise.resolve();
  }
  connectedCallback() {
    if (!this.mounted) {
      this.mounted = true;
      this.startTimer = setTimeout(() => this.fail(new Error('Story mounting deadline exceeded')), 20000);
      void this.mount().catch(error => { this.fail(error); });
    }
  }
  disconnectedCallback() { previousDisposal = this.dispose().catch(() => {}); }
  async mount() {
    await previousDisposal;
    if (this.closing) { return; }
    const story = this.definition;
    this.className = 'native-review';
    const heading = document.createElement('h2'); heading.textContent = story.id; this.append(heading);
    const purpose = document.createElement('p'); purpose.textContent = story.purpose; this.append(purpose);
    const help = document.createElement('p'); help.className = 'native-help'; help.textContent = `${story.keyboard} ${story.mouse}`; this.append(help);
    const toolbar = document.createElement('div'); toolbar.className = 'native-toolbar'; this.append(toolbar);
    const button = (label, action) => {
      const control = document.createElement('button'); control.type = 'button'; control.textContent = label;
      control.addEventListener('click', () => { void action().catch(error => this.showError(error)); }); toolbar.append(control);
    };
    button('Reset story', () => this.reset()); button('Next checkpoint', () => this.step());
    button('Inspect frame', () => this.capture().then(frame => { this.inspection.hidden = false; this.inspection.textContent = JSON.stringify({ state: frame.state, cursor: frame.frame.cursor, rows: frame.frame.rows, cols: frame.frame.cols }, null, 2); }));
    for (const [label, size] of [['Tiny', { rows: 4, cols: 12 }], ['Standard', { rows: 24, cols: 80 }], ['Wide', { rows: 32, cols: 120 }]]) {
      button(label, () => this.resize(size.rows, size.cols));
    }
    const api = document.createElement('a'); api.href = story.api_url; api.textContent = 'Widget API source'; api.target = '_blank'; api.rel = 'noreferrer'; toolbar.append(api);
    this.status = document.createElement('p'); this.status.className = 'native-status'; this.status.setAttribute('role', 'status'); this.status.textContent = 'Starting native story…'; this.append(this.status);
    this.host = document.createElement('div'); this.host.className = 'native-terminal'; this.append(this.host);
    this.inspection = document.createElement('pre'); this.inspection.hidden = true; this.append(this.inspection);
    await Promise.all([
      document.fonts.load('400 14px "Noto Sans Mono"', 'ABCé┌─┐│●'), document.fonts.load('700 14px "Noto Sans Mono"', 'ABC┌─┐│●'),
      document.fonts.load('400 14px "Noto Sans SC"', '界'), document.fonts.load('400 14px "Noto Emoji"', '👩'),
    ]);
    await document.fonts.ready;
    if (this.closing) { return; }
    const size = this.geometry ?? story.geometry;
    this.term = new Terminal({ ...size, rows: size.rows, cols: size.cols, scrollback: 0, fontSize: 14,
      fontFamily: '"Noto Sans Mono", "Noto Sans SC", "Noto Emoji", monospace', fontWeight: '400', fontWeightBold: '700',
      lineHeight: 1, letterSpacing: 0, cursorBlink: false, cursorStyle: 'block', allowTransparency: false,
      customGlyphs: true, theme, allowProposedApi: true });
    this.term.open(this.host);
    this.resources.push(this.term.parser.registerOscHandler(777, data => {
      const match = /^ncurses-gallery;(\d+)$/.exec(data);
      if (!match) { return false; }
      const sequence = Number(match[1]); this.seenFences.add(sequence); this.fences.get(sequence)?.resolve(); return true;
    }));
    this.resources.push(this.term.onData(data => { void this.input(data).catch(error => this.showError(error)); }));
    this.resources.push(this.term.onBinary(data => { void this.input(data, 'latin1').catch(error => this.showError(error)); }));
    this.socket = new WebSocket(`${location.protocol === 'https:' ? 'wss:' : 'ws:'}//${location.host}/native`);
    this.socket.addEventListener('message', event => {
      try {
        const message = JSON.parse(event.data);
        if (message.type === 'terminal') {
          const bytes = Uint8Array.from(atob(message.data), char => char.charCodeAt(0)); this.term.write(bytes);
        } else if (message.type === 'geometry') { this.term.resize(message.cols, message.rows); }
        else if (message.type === 'frame') { void this.completeFrame(message).catch(error => this.fail(error)); }
        else if (message.type === 'closed') { this.requests.get(message.request)?.resolve(message); this.requests.delete(message.request); }
        else if (message.type === 'error') {
          const error = new Error(message.error); const pending = this.requests.get(message.request);
          if (pending) { pending.reject(error); this.requests.delete(message.request); }
          this.showError(error); if (message.fatal) { this.fail(error); }
        }
      } catch (error) { this.fail(error); }
    });
    this.socket.addEventListener('error', () => this.fail(new Error('Native bridge connection failed')));
    this.socket.addEventListener('close', () => {
      const error = new Error('Native connection closed');
      for (const pending of this.requests.values()) { pending.reject(error); }
      for (const pending of this.fences.values()) { pending.reject(error); }
      for (const painting of this.renders) { painting.reject(error); }
      this.requests.clear(); this.fences.clear(); this.start.reject(error);
    });
    await new Promise((resolve, reject) => {
      this.socket.addEventListener('open', resolve, { once: true });
      this.socket.addEventListener('error', reject, { once: true });
      this.socket.addEventListener('close', () => reject(new Error('Connection closed during startup')), { once: true });
    });
    if (this.closing) { this.socket.close(); return; }
    const initial = await this.request('start', { story: story.id, geometry: size, monochrome: this.monochrome === true });
    this.term.focus(); clearTimeout(this.startTimer); this.start.resolve(initial);
  }
  async completeFrame(message) {
    if (!this.seenFences.has(message.sequence)) {
      const barrier = this.fences.get(message.sequence) ?? deferred(); this.fences.set(message.sequence, barrier); await barrier.promise;
    }
    this.fences.delete(message.sequence); this.seenFences.delete(message.sequence);
    if (!this.requests.has(message.request)) { return; }
    const painting = deferred(); this.renders.add(painting);
    const rendered = this.term.onRender(() => { rendered.dispose(); painting.resolve(); });
    try {
      this.term.refresh(0, this.term.rows - 1);
      await painting.promise;
    } finally { rendered.dispose(); this.renders.delete(painting); }
    this.frame = message.artifact;
    this.status.textContent = `${this.frame.checkpoint} · ${this.frame.frame.rows}×${this.frame.frame.cols} · Focus: ${this.frame.state.focus || 'none'}`;
    const pending = this.requests.get(message.request); this.requests.delete(message.request); pending?.resolve(this.frame);
    this.dispatchEvent(new CustomEvent('native-frame', { detail: this.frame }));
  }
  request(type, values = {}) {
    const operation = this.requestChain.then(async () => {
      if (this.closing && type !== 'close') { throw new Error('Native story is closing'); }
      if (this.socket?.readyState !== WebSocket.OPEN) { throw new Error('Native connection is not open'); }
      const request = ++this.sequence; const result = deferred(); this.requests.set(request, result);
      const deadline = setTimeout(() => this.fail(new Error(`Native ${type} completion deadline exceeded`)), 20000);
      try {
        this.socket.send(JSON.stringify({ ...values, type, request }));
        // Frames resolve only after native draw, PTY parsing and browser rendering.
        // Sending the next command earlier can paint it over this frame's barrier.
        return await result.promise;
      } finally { clearTimeout(deadline); this.requests.delete(request); }
    });
    this.requestChain = operation.catch(() => {});
    return operation;
  }
  async input(data, encoding = 'utf8') { await this.ready; return await this.request('input', { data, encoding }); }
  async capture() { await this.ready; return await this.request('capture'); }
  async reset() { await this.ready; return await this.request('reset'); }
  async step() { await this.ready; return await this.request('step'); }
  async resize(rows, cols) { await this.ready; return await this.request('resize', { rows, cols }); }
  showError(error) { if (this.status) { this.status.textContent = error.message; this.status.dataset.error = 'true'; } }
  fail(error) {
    clearTimeout(this.startTimer);
    this.closing = true;
    this.showError(error); this.start.reject(error);
    for (const pending of this.requests.values()) { pending.reject(error); }
    for (const pending of this.fences.values()) { pending.reject(error); }
    for (const painting of this.renders) { painting.reject(error); }
    this.requests.clear(); this.fences.clear(); this.socket?.close();
  }
  async dispose() {
    if (this.disposal) { return await this.disposal; }
    this.closing = true;
    this.disposal = (async () => {
      try { if (this.socket?.readyState === WebSocket.OPEN) { await this.request('close'); } }
      finally {
        this.socket?.close(); this.fail(new Error('Native story disposed'));
        for (const resource of this.resources) { resource.dispose(); }
        this.term?.dispose();
      }
    })();
    this.disposal.catch(() => {}); return await this.disposal;
  }
}
customElements.define('ncurses-native-terminal', NativeTerminal);
export function renderStory(definition, options = {}) {
  const element = document.createElement('ncurses-native-terminal'); element.definition = definition;
  element.monochrome = options.monochrome; element.geometry = options.geometry; return element;
}
