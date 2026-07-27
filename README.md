# Qore Ncurses Module

Modern, thread-safe terminal UI support for Qore 2.3 using the system ncurses library.

## Status

This module is a complete redesign with a clean, high-level API. It is not backward-compatible with the legacy module.

## Requirements

- Qore 2.3 (development branch)
- ncurses (with panel support)
- CMake 3.21+ (Alpine CI uses CMake 4)

## Build

```bash
mkdir -p build
cd build
cmake ..
make
```

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

## License

MIT.
