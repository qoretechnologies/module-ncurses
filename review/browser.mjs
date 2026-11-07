// Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT
export const browserOptions = {
  viewport: { width: 1500, height: 1100 }, deviceScaleFactor: 1, locale: 'en-US', timezoneId: 'UTC',
  colorScheme: 'dark', reducedMotion: 'reduce',
};
export const browserArgs = ['--disable-lcd-text', '--font-render-hinting=none',
  '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'];

export function storybookId(story) {
  return `native-${story.widget.toLowerCase()}--${story.id.split('.')[1]}`;
}

/** Translate registry events to xterm-256color input bytes, retaining one source of expectations. */
export function inputBytes(event) {
  const keys = { KEY_ENTER: '\r', KEY_UP: '\x1bOA', KEY_DOWN: '\x1bOB', KEY_RIGHT: '\x1bOC', KEY_LEFT: '\x1bOD',
    KEY_HOME: '\x1bOH', KEY_END: '\x1bOF', KEY_PPAGE: '\x1b[5~', KEY_NPAGE: '\x1b[6~', 'KEY_F(7)': '\x1b[18~', 'KEY_F(8)': '\x1b[19~' };
  if (event.type === 1) { return event.ch; }
  if (event.type === 5) { return '\x1b' + event.ch; }
  if (event.type === 6) { return '\x1b[200~' + event.ch + '\x1b[201~'; }
  if (event.type === 2 && keys[event.name]) { return keys[event.name]; }
  if (event.type === 3 && event.mouse) {
    const { x, y, button_state: button } = event.mouse;
    if (button === 4) { return `\x1b[<0;${x + 1};${y + 1}M\x1b[<0;${x + 1};${y + 1}m`; }
    if ([65536, 2097152].includes(button)) { return `\x1b[<${button === 65536 ? 64 : 65};${x + 1};${y + 1}M`; }
  }
  throw new Error(`No PTY encoding for registry event ${JSON.stringify(event)}`);
}

/** DOM registration, native draw, xterm parse and render are completion events. */
export async function openStory(page, origin, story, monochrome = false, geometry = story.geometry, timeout = 20000) {
  const args = `monochrome:${monochrome};rows:${geometry.rows};cols:${geometry.cols}`;
  await page.goto(`${origin}/iframe.html?id=${storybookId(story)}&viewMode=story&args=${args}`);
  return await page.evaluate(async timeout => {
    let observer, timer, finished = false;
    try {
      return await Promise.race([
        (async () => {
          await customElements.whenDefined('ncurses-native-terminal');
          if (finished) { return; }
          const element = document.querySelector('ncurses-native-terminal') ?? await new Promise(resolve => {
            observer = new MutationObserver(() => {
              const element = document.querySelector('ncurses-native-terminal');
              if (element) { observer.disconnect(); resolve(element); }
            });
            observer.observe(document.body, { childList: true, subtree: true });
          });
          return await element.ready;
        })(),
        new Promise((_, reject) => { timer = setTimeout(() => reject(new Error('Story readiness deadline exceeded')), timeout); }),
      ]);
    } finally { finished = true; clearTimeout(timer); observer?.disconnect(); }
  }, timeout);
}

export async function command(page, name, ...args) {
  if (!['capture', 'step', 'input', 'reset', 'resize', 'dispose'].includes(name)) { throw new Error('Unknown browser action'); }
  return await page.evaluate(([name, args]) => document.querySelector('ncurses-native-terminal')[name](...args), [name, args]);
}
