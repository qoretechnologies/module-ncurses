# Qore Ncurses Module

Modern, thread-safe terminal UI support for Qore 2.3 using the system ncurses library.

## Status

Version 1.0 is the initial release, providing a high-level terminal API and reusable UI widgets.

## Requirements

- Qore 2.3 (development branch)
- ncurses (with panel support)
- CMake 3.21+ (Alpine CI uses CMake 4)

## Build

```bash
which qore
# This example matches /usr/bin/qore; use /usr/local for /usr/local/bin/qore.
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
cmake --build build -j4
```

Use `build-debug/` with `-DCMAKE_BUILD_TYPE=Debug` for debugging. The install prefix
must match the existing Qore installation so binary module paths remain compatible.

## Widget review

The shared gallery covers all 27 concrete widgets, applicable states, viewport
sizes, keyboard and mouse interactions. Run it natively or review its actual PTY
output in Storybook. See [review/README.md](review/README.md) for local commands,
deterministic captures, baseline/current/diff artifacts and explicit reviewed
baseline acceptance. The initial interaction review is recorded in
[docs/ux-review-2026-11.md](docs/ux-review-2026-11.md).

## Usage

```qore
%modern
%requires ncurses

Ncurses::Session s();
Ncurses::Window w = s.screen();

w.clear();
w.drawText(1, 2, "Hello, Ncurses!", {fg: Ncurses::Color::Cyan, attrs: Ncurses::Attr::Bold});
w.refresh();

w.readEvent();
s.close();
```

If you need ncurses I/O on a dedicated TTY (for example to capture stdout while still using ncurses),
create the session with `use_tty: True`. When `use_tty` is enabled, stdout/stderr are set to unbuffered
by default to keep output capture responsive; this can be disabled with `unbuffered_stdio: False`.

### Safe Drawing Helpers

To avoid overwriting borders, use the clipped drawing helpers:

```qore
w.drawTextClipped(1, -2, "Hello");  # clipped to window bounds
w.drawTextInside(0, 0, "Title");    # clipped to inner area of a boxed window
w.drawTextInsideLine(1, "Value");   # clears the line, then draws
```

### Batched Refresh

For low-flicker updates, use queued refreshes and a single flush:

```qore
w.noutrefresh();
s.updatePanels();
s.doupdate();
```

To keep the cursor in a specific window while updating others:

```qore
info.setLeaveOk(True);
```

You can also save and restore cursor positions around updates:

```qore
hash pos = input.saveCursor();
info.drawTextInsideLine(0, "Time: 12:00");
input.restoreCursor(pos);
```

## Tools

The module installs a full-screen REPL frontend backed by the QoreRepl module:

```bash
qrepl
```

The output pane supports mouse wheel scrolling and keyboard paging (click the output pane, then use the wheel, arrow keys, PgUp/PgDn, Home/End).

`/help` opens scrollable command help at the beginning; Escape returns to the prompt.
`/threads` lists threads in the current program, `/cancel <tid|all>` requests cooperative
termination, and `/join <tid|all>` waits for them to leave the program. Parsing, `/type`,
`/load`, and `/reset` require an idle program. When threads are running, qrepl offers
**Wait**, **Cancel request**, and **Terminate threads**. Completion closes the dialog and
resumes the pending request automatically; cancelling the request preserves the input.
Thread termination is cooperative, so code can catch or defer it.

This workflow requires Qore 3.0 with the Program thread coordination APIs and the matching
QoreRepl module. `NcursesUi::BackgroundTask::cancel()`, `Dialogs::choose()`, and
`Dialogs::text()` expose the reusable worker cancellation, asynchronous dialog, and
scrollable help behavior for other applications. Completion uses the application's wake
queue and a Program condition variable, without periodic thread-list polling.

## UI Widgets

The `NcursesUi` helper module provides reusable widgets for pop-up menus and browsers:

```qore
%requires NcursesUi

NcursesUi::PanelWidget popup();
NcursesUi::MenuBarWidget menu();
```

These widgets are used by `qrepl` to provide mouse-driven menus, a reflection browser, and a filesystem browser.

For column-aligned terminal output, `NcursesUi::TerminalText` measures display
columns and clips or pads plain text without splitting Unicode grapheme
clusters:

```qore
string label = NcursesUi::TerminalText::fitRight("ステップの例", 16);
```

## Mouse Support

Mouse input is supported via `Window::readEvent()` when `Session` is created with
`mouse: True` (default). Mouse events are reported as input events with
`type == Ncurses::InputType::Mouse` and include a `mouse` hash with coordinates
and button state.

## Threading

All ncurses calls are serialized with a module-level recursive lock. Input calls release the lock between polling cycles to allow concurrent rendering from other threads.

## Documentation

Doxygen documentation is generated from the QPP sources and `docs/mainpage.dox.tmpl`.

## Scrollable text and cursor positions

`LineListContent` measures wrapping before the viewport scrolls or draws. Use
`ScrollableWidget.setCursorLine(line, offset)` with a source character offset
excluding ANSI escapes; the widget maps it to terminal rows and columns. It
keeps a newly positioned caret visible, including after an exactly full final
row. Manual scrolling releases caret following until the next cursor update.
Horizontal slices preserve styling and keep complete graphemes inside the
widget rectangle. Resize preserves the source position at the top of the view.

`Window.claimCursor(y, x)` returns an ownership token for shared drawing surfaces.
`Window.releaseCursor(token)` releases only that active request, so clearing an
old widget cursor cannot cancel a newer cursor from another widget. Cursor
visibility remains a session setting.

## CI verification after merges

For pushes to `develop`, the `tree-already-tested` preflight checks whether the
current commit or an immediate parent with the identical Git tree already has a
successful module pipeline. It requires successful `test-ubuntu` and
`test-alpine` jobs. When that evidence is available, the platform jobs report
success to GitHub with a link to the earlier pipeline and finish before building
or testing. GitLab still creates the preflight and lightweight platform jobs.

Feature branches, tags, scheduled pipelines and pipelines started manually run
the full tests. Set `QORE_CI_FORCE_FULL=1` to require full verification on a
`develop` push, for example after updating the test images or dependencies
without changing this repository's tree.

The preflight first uses `CI_JOB_TOKEN`. If the server refuses pipeline reads,
configure the masked CI variable `QORE_CI_READ_API_TOKEN` with a token that has
`read_api` access to `mirror/module-ncurses`. Missing credentials, API errors,
invalid responses and incomplete platform results retain the full pipeline.
This follows Qore's successful-tree reuse mechanism introduced in commit
`22a9b5c721`, with explicit validation of the module's two platform jobs.

The deterministic preflight and status-reporting tests run on both CI platforms
before the module build. To run them locally:

```bash
python3 test/test_tree_tested.py
```

## License

MIT.

## Focus and Unicode input

Use `Application.getFocusManager().setFocus(widget)` to select an input, including
one nested inside non-focusable containers. Clicking an input transfers focus and
places its caret using terminal display columns. Hidden or disabled subtrees are
excluded from focus traversal; removing or reparenting a subtree clears focus.

`pushModal(widget)` captures input and keeps Tab/Shift+Tab in that subtree. A
control with internal Tab navigation gets the key first. Nested modal removal
restores the previous eligible control. Use `pushPopup(widget)` for menus that
should dismiss on an outside primary click and pass that click through. Explicit
global handlers still run first, including during modal operation.

`InputBuffer` and both input widgets move and delete complete Unicode graphemes.
`getCursor()` still returns a Qore character offset, not a byte or grapheme index.
`setCursor()` snaps partial clusters backward; `replaceRange(start, end, text)`
expands partial selections to whole clusters. `NcursesReplUi::TextPosition`
converts between these offsets and display columns. Combining accents, emoji
modifiers, regional-indicator pairs, and joined emoji therefore remain intact.

`Session.setCursor(visibility)` returns the previous visibility (or `-1` for an
unsupported request). Applications can ignore the result as before. Modal text
inputs show their caret; closing the last modal restores the prior visibility.
Focus callbacks that raise leave no stale owner; nested focus/modal transitions
from a focus callback raise an explicit error, including callbacks caused by
hiding, disabling, or detaching a widget. Focus queries remain safe during cleanup.
Composite controls can override
`handlesChildMouseEvents()` and `mouseFocusTarget(y, x)` to keep mouse delegation
and focus selection together; the file browser uses this contract for pane
selection and directory-preview navigation. Child frames and mouse events use
absolute screen coordinates, including inside panels. Custom drawing uses
`drawContentRect(window)` to convert to the target window. `drawTree()` clips
overflow to ancestor content and terminal bounds. Zero-area widgets do not draw.

Panels retain logical geometry and open intent separately from their clipped
native windows, recreate those windows after regrowth, and keep child positions
relative to a moved panel. Failed native replacement preserves the old resources.
Active dialogs and popups reflow on resize. Tiny dialogs show the focused action;
Tab reaches every action, and Up/Down or PageUp/PageDown scroll the message. On a one-row dialog these keys temporarily show the message;
Tab returns to the action labels.
Menus, radio groups, and combo boxes scroll their active choice into the available
rows and support Home/End, page navigation, wheel input, and primary clicks.

Tables support `auto`, `number`, `string`, and `date` column types plus custom
comparators. Numeric columns accept numeric strings; auto ordering is null,
numeric, date, then text. Equal keys retain input order. Use `setRowKey()` for
stable selection across refreshes, `setFilter()` for displayed-value filtering,
and `setOnAction()` for application row actions. Left/Right reveal columns;
Enter or double-click activates the selected row.
