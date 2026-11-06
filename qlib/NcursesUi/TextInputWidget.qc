#! @file TextInputWidget.qc Single-line text input with cursor and history

/*  TextInputWidget.qc Copyright 2026 Qore Technologies, s.r.o.

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

public namespace NcursesUi {
/** Single-line text input widget with cursor, editing, and history.

    Wraps @ref NcursesReplUi::InputBuffer for editing and optionally
    @ref QoreHistory::History for command history. Supports all
    standard editing keys: Home/End, Ctrl+A/E/K/U/W/B/F/D,
    Backspace/Delete, arrow keys, and history navigation with
    Up/Down.

    @since ncurses 1.0
*/
public class TextInputWidget inherits NcursesUi::Widget {
    private {
        *hash<NcursesUi::Rect> draw_bounds;
        #! the input buffer
        NcursesReplUi::InputBuffer buffer();
        #! optional history
        *QoreHistory::History history;
        #! the prompt string
        string prompt = "";
        #! callback on submit (Enter)
        *code<nothing(string)> on_submit;
        #! callback on text change
        *code<nothing(string)> on_change;
        #! horizontal scroll offset for long input
        int scroll_x = 0;
        *Ncurses::Window cursor_window;
        int cursor_request = 0;
    }

    /** Creates a new TextInputWidget.
        @param p the prompt string
        @since ncurses 1.0
    */
    constructor(string p = "") {
        prompt = p;
        setFocusable(True);
    }

    /** Sets the prompt.
        @param p the prompt string
        @since ncurses 1.0
    */
    nothing setPrompt(string p) {
        prompt = p;
        markDirty();
    }

    /** Returns the prompt.
        @since ncurses 1.0
    */
    string getPrompt() {
        return prompt;
    }

    /** Returns the input buffer.
        @since ncurses 1.0
    */
    NcursesReplUi::InputBuffer getBuffer() {
        return buffer;
    }

    /** Returns the current text.
        @since ncurses 1.0
    */
    string getText() {
        return buffer.getText();
    }

    /** Sets the text.
        @param t the text
        @since ncurses 1.0
    */
    nothing setText(string t) {
        buffer.setText(t);
        markDirty();
    }

    /** Sets a history instance.
        @param h the history
        @since ncurses 1.0
    */
    nothing setHistory(*QoreHistory::History h) {
        history = h;
    }

    /** Returns the history instance.
        @since ncurses 1.0
    */
    *QoreHistory::History getHistory() {
        return history;
    }

    /** Sets the submit callback.
        @param cb callback receiving the submitted text
        @since ncurses 1.0
    */
    nothing setOnSubmit(*code<nothing(string)> cb) {
        on_submit = cb;
    }

    /** Sets the text change callback.
        @param cb callback receiving the current text
        @since ncurses 1.0
    */
    nothing setOnChange(*code<nothing(string)> cb) {
        on_change = cb;
    }

    /** Returns the cursor position.
        @since ncurses 1.0
    */
    int getCursorPos() {
        return buffer.getCursor();
    }

    destructor() {
        releaseCursor();
    }

    /** Returns True because this widget edits text with a terminal caret.
        @return True
        @since ncurses 1.0
    */
    bool wantsCursor() {
        return True;
    }

    /** Releases this input's cursor request when focus leaves it.
        @since ncurses 1.0
    */
    nothing onFocusOut() {
        releaseCursor();
    }

    /** Releases cursor ownership when the widget has no drawable area. */
    nothing onDrawClipped() {
        releaseCursor();
        Widget::onDrawClipped();
    }

    /** Draws the input, clipping to its rectangle and the target window.
        @param w the window
        @since ncurses 1.0
    */
    nothing draw(Ncurses::Window w) {
        releaseCursor();
        hash<NcursesUi::Rect> cr = drawContentRect(w);
        hash<Ncurses::Size> size = w.size();
        hash<Ncurses::Position> origin = w.position();
        draw_bounds = NcursesUi::Geometry::makeRect(origin.y, origin.x, size.rows, size.cols);
        if (cr.rows <= 0 || cr.cols <= 0 || cr.y < 0 || cr.y >= size.rows) {
            return;
        }
        int left = max(0, cr.x);
        int width = max(0, min(cr.x + cr.cols, size.cols) - left);
        if (!width) {
            return;
        }
        int cursor_col = cursorColumn();
        updateScroll(inputColumns());
        string visible = TerminalText::columnSlice(prompt + buffer.getText(), scroll_x + left - cr.x, width);
        w.drawText(cr.y, left, visible, hasFocus() ? {"attrs": Ncurses::Attr::Bold} : {});
        int x = cr.x + cursor_col - scroll_x;
        if (hasFocus() && x >= left && x < left + width) {
            cursor_request = w.claimCursor(cr.y, x);
            cursor_window = w;
        }
    }

    /** Handles text editing, history, submission, and mouse caret placement.
        @param ev the input event
        @return whether the event was handled, with action "submit" on Enter
        @since ncurses 1.0
    */
    hash<NcursesUi::EventResult> processEvent(hash<Ncurses::InputEvent> ev) {
        if (ev.type == Ncurses::InputType::Mouse) {
            hash<NcursesUi::Rect> cr = contentRect();
            if (ev.mouse && ev.mouse.y == cr.y && hitTest(ev.mouse.y, ev.mouse.x)
                    && (ev.mouse.button_state & (Ncurses::BUTTON1_CLICKED | Ncurses::BUTTON1_PRESSED
                        | Ncurses::BUTTON1_DOUBLE_CLICKED | Ncurses::BUTTON1_TRIPLE_CLICKED))) {
                updateScroll(inputColumns());
                int col = scroll_x + ev.mouse.x - cr.x - TerminalText::displayWidth(prompt);
                buffer.setCursor(NcursesReplUi::TextPosition::offsetForColumn(buffer.getText(), col));
                markDirty();
                return <NcursesUi::EventResult>{"handled": True};
            }
            return <NcursesUi::EventResult>{"handled": False};
        }
        string before = buffer.getText();
        if ((ev.type == Ncurses::InputType::Char && (ev.ch == "\n" || ev.ch == "\r"))
                || (ev.type == Ncurses::InputType::Key && ev.name == "KEY_ENTER")) {
            if (history) {
                history.add(before);
            }
            buffer.reset();
            scroll_x = 0;
            markDirty();
            if (before != "") {
                notifyChange();
            }
            if (on_submit) {
                on_submit(before);
            }
            return <NcursesUi::EventResult>{"handled": True, "action": "submit"};
        }
        bool handled;
        if (ev.type == Ncurses::InputType::Key && (ev.name == "KEY_UP" || ev.name == "KEY_DOWN")) {
            if (history) {
                *string entry = ev.name == "KEY_UP" ? history.prev() : history.next();
                if (exists entry) {
                    buffer.setText(entry);
                }
            }
            handled = True;
        } else {
            handled = buffer.processEvent(ev);
        }
        if (handled) {
            markDirty();
            if (buffer.getText() != before) {
                notifyChange();
            }
        }
        return <NcursesUi::EventResult>{"handled": handled};
    }

    private int cursorColumn() {
        return TerminalText::displayWidth(prompt)
            + NcursesReplUi::TextPosition::columnForOffset(buffer.getText(), buffer.getCursor());
    }

    private nothing updateScroll(int width) {
        int col = cursorColumn();
        if (width <= 0) {
            scroll_x = 0;
            return;
        }
        int last = max(0, TerminalText::displayWidth(prompt + buffer.getText()) - width + 1);
        scroll_x = max(0, min(scroll_x, min(col, last)));
        if (col >= scroll_x + width) {
            scroll_x = col - width + 1;
        }
    }

    private int inputColumns() {
        hash<NcursesUi::Rect> cr = contentRect();
        hash<NcursesUi::Rect> clip = NcursesUi::Geometry::intersect(cr, visibleRect());
        if (draw_bounds) { clip = NcursesUi::Geometry::intersect(clip, draw_bounds); }
        return clip.cols > 0 ? max(0, clip.x + clip.cols - cr.x) : 0;
    }

    private nothing releaseCursor() {
        if (cursor_window && cursor_request) {
            cursor_window.releaseCursor(cursor_request);
        }
        cursor_window = NOTHING;
        cursor_request = 0;
    }

    private nothing notifyChange() {
        if (on_change) {
            on_change(buffer.getText());
        }
    }
}

} # namespace NcursesUi
