#! @file TestHarness.qc Test utility for NcursesUi

/*  TestHarness.qc Copyright 2026 Qore Technologies, s.r.o.

    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the "Software"),
    to deal in the Software without restriction, including without limitation
    the rights to use, copy, modify, merge, publish, distribute, sublicense,
    and/or sell copies of the Software, and to permit persons to whom the
    Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
    DEALINGS IN THE SOFTWARE.
*/

#! @defgroup test_harness TestHarness
#! Testing utility for NcursesUi widgets and applications

/** Test harness for NcursesUi components.

    Wraps a @ref Qore::Ncurses::TestTerminal "TestTerminal" and @ref Qore::Ncurses::Session "Session" with sensible
    defaults, providing assertion helpers and event injection for deterministic
    testing.

    @par Example
    @code
    NcursesUi::TestHarness th(24, 80);
    th.session().screen().drawText(0, 0, "Hello", {});
    th.session().screen().refresh();
    th.assertTextAt(test, 0, 0, "Hello");
    th.close();
    @endcode

    @since ncurses 2.0
*/
public class NcursesUi::TestHarness {
    private {
        Ncurses::TestTerminal terminal;
        Ncurses::Session sess;
        int term_rows;
        int term_cols;
    }

    /** Creates a new test harness.

        @param rows terminal rows (default 24)
        @param cols terminal columns (default 80)
        @param opts optional session options to override defaults

        @since ncurses 2.0
    */
    constructor(int rows = 24, int cols = 80, *hash<auto> opts) {
        term_rows = rows;
        term_cols = cols;
        terminal = new Ncurses::TestTerminal(rows, cols, "xterm-256color");
        terminal.open();
        hash<auto> defaults = {
            "test_terminal": terminal,
            "echo": False,
            "raw": True,
            "cbreak": False,
            "keypad": True,
            "mouse": True,
            "use_colors": True,
            "use_default_colors": True,
            "cursor": 0,
        };
        if (opts) {
            map defaults{$1.key} = $1.value, opts.pairIterator();
        }
        sess = new Ncurses::Session(defaults);
    }

    /** Returns the session.
        @since ncurses 2.0
    */
    Ncurses::Session session() {
        return sess;
    }

    /** Returns the screen window.
        @since ncurses 2.0
    */
    Ncurses::Window screen() {
        return sess.screen();
    }

    /** Returns the terminal rows.
        @since ncurses 2.0
    */
    int rows() {
        return term_rows;
    }

    /** Returns the terminal columns.
        @since ncurses 2.0
    */
    int cols() {
        return term_cols;
    }

    /** Closes the session and terminal.
        @since ncurses 2.0
    */
    nothing close() {
        if (sess.isOpen()) {
            sess.close();
        }
    }

    /** Performs a full draw cycle: updatePanels + doupdate.
        @since ncurses 2.0
    */
    nothing refresh() {
        sess.updatePanels();
        sess.doupdate();
    }

    /** Returns the current screen as a list of strings.
        @param y start row (default 0)
        @param rows number of rows (default all)
        @param ncols number of columns (default all)
        @return list of strings, one per row

        @since ncurses 2.0
    */
    list<string> snapshot(*int y, *int rows, *int ncols) {
        return sess.snapshot(y, rows, ncols);
    }

    # ---- Assertion helpers ----

    /** Asserts that exact text appears at a position.
        @param test the QUnit::Test instance
        @param row the row to check
        @param col the column to check
        @param expected the expected text
        @param msg optional message

        @since ncurses 2.0
    */
    nothing assertTextAt(QUnit::Test test, int row, int col, string expected, *string msg) {
        Ncurses::Window w = sess.screen();
        string actual = w.readText(row, col, expected.length());
        test.assertEq(expected, actual, msg ?? sprintf("text at (%d,%d)", row, col));
    }

    /** Asserts that a row contains a pattern (regex match).
        @param test the QUnit::Test instance
        @param row the row to check
        @param pattern the regex pattern to match
        @param msg optional message

        @since ncurses 2.0
    */
    nothing assertRowContains(QUnit::Test test, int row, string pattern, *string msg) {
        list<string> lines = sess.snapshot(row, 1, term_cols);
        string line = lines.size() ? lines[0] : "";
        test.assertTrue(regex(line, pattern),
            msg ?? sprintf("row %d matches /%s/ (got: '%s')", row, pattern, line));
    }

    /** Asserts that a row is blank (all spaces).
        @param test the QUnit::Test instance
        @param row the row to check
        @param msg optional message

        @since ncurses 2.0
    */
    nothing assertRowEmpty(QUnit::Test test, int row, *string msg) {
        list<string> lines = sess.snapshot(row, 1, term_cols);
        string line = lines.size() ? lines[0] : "";
        test.assertTrue(trim(line) == "",
            msg ?? sprintf("row %d is empty (got: '%s')", row, trim(line)));
    }

    # ---- Event injection ----

    /** Injects a key event.
        @param code the key code (e.g. Ncurses::KEY_UP)

        @since ncurses 2.0
    */
    nothing injectKey(int code) {
        hash<Ncurses::InputEvent> ev();
        ev.type = Ncurses::InputType::Key;
        ev.code = code;
        sess.injectEvent(ev);
    }

    /** Injects a character event.
        @param ch the character string

        @since ncurses 2.0
    */
    nothing injectChar(string ch) {
        hash<Ncurses::InputEvent> ev();
        ev.type = Ncurses::InputType::Char;
        ev.ch = ch;
        sess.injectEvent(ev);
    }

    /** Injects a mouse event.
        @param x the column
        @param y the row
        @param button_state the button state mask

        @since ncurses 2.0
    */
    nothing injectMouse(int x, int y, int button_state) {
        hash<Ncurses::MouseEvent> mouse();
        mouse.x = x;
        mouse.y = y;
        mouse.button_state = button_state;
        hash<Ncurses::InputEvent> ev();
        ev.type = Ncurses::InputType::Mouse;
        ev.mouse = mouse;
        sess.injectEvent(ev);
    }

    /** Injects a mouse wheel-up event.
        @param x the column
        @param y the row

        @since ncurses 2.0
    */
    nothing injectWheelUp(int x, int y) {
        injectMouse(x, y, Ncurses::BUTTON4_PRESSED);
    }

    /** Injects a mouse wheel-down event.
        @param x the column
        @param y the row

        @since ncurses 2.0
    */
    nothing injectWheelDown(int x, int y) {
        injectMouse(x, y, Ncurses::BUTTON5_PRESSED);
    }

    /** Injects a resize event.
        @since ncurses 2.0
    */
    nothing injectResize() {
        hash<Ncurses::InputEvent> ev();
        ev.type = Ncurses::InputType::Resize;
        sess.injectEvent(ev);
    }

    /** Reads the next event from the screen window.
        @param timeout_ms timeout in milliseconds (default 500)
        @param poll_ms poll interval in milliseconds (default 25)
        @return the event or NOTHING on timeout

        @since ncurses 2.0
    */
    *hash<Ncurses::InputEvent> readEvent(int timeout_ms = 500, int poll_ms = 25) {
        return sess.screen().readEvent(timeout_ms, poll_ms);
    }

    /** Injects a key event and reads it back from the event queue.
        @param code the key code
        @param timeout_ms timeout for reading (default 500)
        @return the event or NOTHING on timeout

        @since ncurses 2.0
    */
    *hash<Ncurses::InputEvent> injectAndReadKey(int code, int timeout_ms = 500) {
        injectKey(code);
        return readEvent(timeout_ms);
    }

    /** Injects a character event and reads it back from the event queue.
        @param ch the character
        @param timeout_ms timeout for reading (default 500)
        @return the event or NOTHING on timeout

        @since ncurses 2.0
    */
    *hash<Ncurses::InputEvent> injectAndReadChar(string ch, int timeout_ms = 500) {
        injectChar(ch);
        return readEvent(timeout_ms);
    }
}
