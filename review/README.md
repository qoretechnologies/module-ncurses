# Native widget review

Copyright 2026 Qore Technologies, s.r.o.

Storybook presents the actual Qore/ncurses gallery through a PTY and xterm.js. The
widgets, fixtures, steps and assertions come from `examples/gallery/`. The HTML
around the terminal provides review controls; it does not implement the widgets.
The native gallery works without Node or a browser.

## Run locally

Requirements: Linux, Python 3.9+ with PTY support, Node 24, Qore with the local
ncurses module built, astparser 3.0+ and QoreRepl for the code stories, and the Chromium dependencies reported by Playwright. Build
`build-debug/` as Debug with the same install prefix as `which qore`; see the main
build instructions. Nothing needs to be installed over the system module.

```sh
cmake --build build-debug -j4
cd review
nvm use v24
npm ci
npx playwright install chromium
# On supported Ubuntu/Debian hosts, install missing browser libraries with:
# npx playwright install-deps chromium
npm run dev
```

Open <http://127.0.0.1:6006>. The PTY bridge binds to `127.0.0.1:6007`; both ports
must be free. Select a widget/state in the Storybook tree, use its native keyboard
and mouse controls, paste text, reset, inspect focus/cursor, or change viewport
size. The status line updates only after native draw and browser rendering finish.
For example, open the editor directly:

<http://127.0.0.1:6006/?path=/story/native-texteditorwidget--boundaries>

Monochrome and geometry are Storybook args. A direct iframe URL can use
`iframe.html?id=native-tablewidget--scrolling&viewMode=story&args=monochrome:true;rows:24;cols:80`.
The toolbar offers an explicit 4×12 stress test, Standard (24×80) and Wide (32×120). Compact stories start at 8×40, exercise extreme clipping and recovery, then perform a real interaction. Reset returns to the story's
initial args and fixture, including its modal state. Next checkpoint executes the
next registered event/model delivery and checks its expected state. After manual input, reset before replaying recorded steps; the checkpoint button explains this and disables at the end. Focus terminal returns keyboard input to xterm. Live feedback explains empty/disabled/closed states and completed actions. There are no
external services or user-file mutations in fixtures.

`NCURSES_BUILD_DIR` selects another local binary build (for example `../build`,
resolved relative to the invoking working directory). The source Qore modules
always come from this checkout's `qlib`. Missing local binaries fail before launch.
Use Ctrl+C to shut down both development servers and their stories.

For native-only review from the repository root:

```sh
QORE_MODULE_DIR=build-debug:qlib qore --enable-debug --warnings-are-errors \
  examples/widget-gallery.qr --story completion-popup.overlap
QORE_MODULE_DIR=build-debug:qlib qore --enable-debug --warnings-are-errors \
  examples/widget-gallery.qr --headless --story transcript.background-reading
```

## Code and choice examples

`native-texteditorwidget--code` highlights Qore syntax with astparser's tree-sitter grammar.
F8 opens qrepl's reflection-backed completion service; Enter accepts a suggestion,
Escape dismisses it, and Ctrl-Z undoes the insertion. Signature hints update as the
caret moves. Drafts are never evaluated and REPL history is disabled. This example
provides symbol completion and call hints, not a project-wide language server.
Incomplete source remains editable even when the parser has no highlight spans.
`CodeViewWidget` stories use the same syntax provider for read-only source.

`native-describedchoicewidget--default` remains freely selectable. Bold cyan titles,
indented descriptions, green recommendation text, blank group separators and a filled
selection circle distinguish roles. Reverse video marks keyboard focus independently
of the chosen value. Monochrome retains weight, markers and spacing. The separate
`--submit` story demonstrates one-shot submission and explains Reset after completion.
Ordinary default labels contain no unexplained Unicode stress glyphs; use `--unicode`.

## Tests, artifacts and acceptance

```sh
cd review
npm run build
npm test
npm run review
# Limit a development run to matching stable IDs/configurations:
npm run review -- --filter completion-popup
```

`npm test` covers the PTY protocol, browser input/lifecycle, registry parity,
rendering/font bounds, missing story registration, artifact comparison, missing/corrupt baselines, failed
capture and deliberate acceptance. It replays all default and mouse stories using
real terminal bytes and compares their focus, scroll, cursor and composed cells
with the same native checkpoints. The native QUnit suite runs every registered
story, including background delivery and cancellation/stale-result scenarios.

The complete visual matrix runs every registered state/checkpoint in color and
monochrome. Each widget's default also runs at tiny, standard and wide sizes.
`artifacts/current/` contains PNGs and compressed JSON with the complete native
frame, palette/attributes, cursor and widget state. `artifacts/diff/` contains
exact pixel diffs and JSON paths for semantic changes. `artifacts/index.html`
shows baseline/current/diff together and links only comparisons produced by the
current run; old generated diffs are cleared even when a baseline is missing or
capture fails. Generated output must not overlap the accepted baseline directory.
`report.json` is the machine-readable failure report. Missing, changed, removed
or invalid evidence fails the command.
A failed run invalidates its completion manifest; it cannot reuse a previous
successful run for acceptance.

Serve the review directory to inspect the report and baseline image links:

```sh
python3 -m http.server 6010 --bind 127.0.0.1 --directory review
# Open http://127.0.0.1:6010/artifacts/index.html (run this command from repo root).
```

Acceptance is a separate, deliberate action after inspecting the changes,
interacting with the affected widgets and recording findings and dispositions:

```sh
# Run from review/, after an unfiltered, complete capture:
node visual.mjs --accept --reviewer 'Reviewer name' \
  --evidence ../docs/ux-review-2026-11.md
npm run review
# Inspect the baseline Git diff and the acceptance evidence before committing.
```

Acceptance verifies that artifact hashes have not changed after the capture,
requires a nonempty evidence file and reviewer, and refuses partial/filtered runs.
CI cannot accept baselines. The manifest records the evidence digest. Acceptance
does not delete obsolete baseline files; review removals explicitly with the Git
diff. Changing fixture behavior or rendering dependencies requires a new review.
Do not raise pixel tolerances to hide differences: comparison includes antialiasing
and uses zero color threshold.

## Add or change a case

1. Edit the executable registry/factory under `examples/gallery/`. Give the story a
   stable `widget.scenario` ID, fixture, geometry, instructions and meaningful
   expected state. `Step.action` is restricted to implemented fixture-model
   deliveries, such as appending output or delivering an obsolete completion.
2. Add assertions for focus, selection, scroll, cursor and the resulting text.
   Keep non-applicable states explained in `Variants.qc`. Add a mouse scenario for
   each interactive widget; Label and StatusBar have no mouse action.
3. Run `test/ncurses-gallery.qtest` with debugging/warnings-as-errors, regenerate
   `python3 tools/widget_catalog.py`, and run `test/test_widget_catalog.py`.
4. Rebuild Storybook, run tests, inspect the affected captures and interact with
   the widget. Run the complete matrix and record the review before acceptance.

`generate.mjs` creates Storybook definitions from the native `--catalog` export.
Generated files are ignored. `browser.mjs` translates registered input events to
terminal bytes for integration tests; adding a new event encoding must have a
regression test. Fixtures are never copied into a separate JavaScript catalog.

## Reproducibility and limitations

The lockfile pins Storybook, xterm.js, Playwright/Chromium and fallback fonts. The
renderer pins theme, 14 px font size, weight, line height, no blinking cursor, no
scrollback, device scale 1, browser locale/time zone, and Linux headless Chromium
launch flags. Native processes use `TERM=xterm-256color`, `LC_ALL=C.UTF-8` and
`TZ=UTC`. Fixtures supply fixed timestamps and deterministic data. The complete
Noto Sans Mono regular/bold fonts are vendored with upstream commit, SHA-256 and
OFL license in `fonts/`; the web subsets omit box-drawing glyphs and are unsuitable
for consistent ordinary text and fallback. CJK and emoji fallback packages are pinned.

The semantic artifact is the authoritative ncurses composition, not an OCR of the
browser. ACS cells retain their original codepoint plus the alternate-character
attribute; the emulator translates them to box glyphs. Browser font rasterization,
Unicode width tables, emoji presentation and terminal-supported attributes can
differ from another terminal. The capture API's capability limits still apply.
The browser uses the pinned WebGL addon with custom box-drawing glyphs, which join at cell edges independently of font metrics. Browser tests and captures pin ANGLE/SwiftShader software rendering; the live browser uses its available WebGL context. Context creation failure is visible; context loss closes the native session and asks for a reload. Normalizing away cells, attributes or
cursor state is deliberately avoided.

Browser/desktop shortcuts such as Ctrl+L, Ctrl+W and some Alt combinations can be
reserved before xterm receives them. Use the native gallery for those bindings.
Mouse input uses negotiated SGR terminal reports. Native platforms may deliver
primary presses/releases instead of synthesized clicks; both paths are covered.
Bracketed paste is supported. The review bridge reserves U+001E as its input
completion fence and rejects it in pasted/typed payloads; other applications using
the native widgets do not have this tooling restriction. A command accepts at most
16 KiB of input; geometry is 1..100 rows and 1..240 columns, with four simultaneous
local sessions. Each connection allows at most 64 outstanding commands and 1 MiB
of queued JSON; exceeding either limit closes and cleans up the session. Completed
commands release their queue budget. These are review-tool resource bounds, not widget API limits.
Outbound buffering is capped at 8 MiB; a non-reading peer is disconnected and its
native process is cleaned up.
An exception while dispatching terminal input closes that session because its
completion fence may be unread. Select the story again to start a fresh session.

Only known story IDs and fixed gallery commands are accepted. WebSocket origins
must match the loopback review server (or the explicit development origin).
There is no shell or arbitrary executable endpoint. Process startup, commands and
teardown have failure deadlines; successful synchronization uses completion
signals, never sleeping or polling for a frame. Commands serialize through browser
render completion; see [the implemented protocol](../design/widget-review.md).

The existing Ubuntu CI job installs the checksum-pinned Node 24.11.1 runtime and
the lockfile's Chromium, then runs build, integration tests and the full visual
comparison as the unprivileged Qore user. Baseline/current/diff artifacts are
retained for 14 days, including failures. Alpine runs native registry/state tests;
the glibc Chromium binary is not run on musl. No extra platform jobs are added, and
the existing successful-identical-tree develop reuse covers the complete gate.
The runtime's prebundled Storybook vendor chunk has an explicit 900 kB budget;
application/adapter chunks have a tested 400 kB budget.

## Review criteria

The review record distinguishes agent interaction/visual inspection from automated
checks; neither is a human usability study. Apply observable criteria informed by
[Laws of UX](https://lawsofux.com/):

- [Jakob's law](https://lawsofux.com/jakobs-law/): arrows, Home/End, Tab, Enter and
  Escape have familiar, documented effects; dismissal restores focus and caret.
- [Hick's law](https://lawsofux.com/hicks-law/): choices can be searched/navigated,
  defaults have explanations, unavailable choices explain their status. No
  arbitrary seven-item limit is imposed.
- [Proximity](https://lawsofux.com/law-of-proximity/): labels, help and validation
  remain next to their fields; errors retain the user's input. Choice descriptions
  stay with their title, with more space between choices than within a choice.
- [Common region](https://lawsofux.com/law-of-common-region/): floating overlays
  have continuous frames; full-width docked regions use shared separators without
  spending columns on redundant outer side borders.
- [Von Restorff effect](https://lawsofux.com/von-restorff-effect/): titles, the focused
  action and recommendations have distinct emphasis. Color is reinforced by weight,
  spacing and marks; highlighting every line equally does not create hierarchy.
- [Fitts's law](https://lawsofux.com/fittss-law/): visible labels and rows provide
  useful mouse targets; padding, clipped areas and unrelated blank space do not
  activate another action.
- [Doherty threshold](https://lawsofux.com/doherty-threshold/): completed actions
  provide immediate state feedback and progress reflects real model data. There
  are no intentional typing delays, and 400 ms is not treated as a typing budget.
- Focus, selection, disabled states and progress remain understandable in
  monochrome through cursor, marks, reverse/bold/dim attributes and explicit text.
