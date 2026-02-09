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

/** Single-line text input widget with cursor, editing, and history.

    Wraps @ref NcursesReplUi::InputBuffer for editing and optionally
    @ref NcursesReplUi::History for command history. Supports all
    standard editing keys: Home/End, Ctrl+A/E/K/U/W/B/F/D,
    Backspace/Delete, arrow keys, and history navigation with
    Up/Down.

    @since ncurses 2.0
*/
public class NcursesUi::TextInputWidget inherits NcursesUi::Widget {
    private {
        #! the input buffer
        NcursesReplUi::InputBuffer buffer();
        #! optional history
        *NcursesReplUi::History history;
        #! the prompt string
        string prompt = "";
        #! callback on submit (Enter)
        *code on_submit;
        #! callback on text change
        *code on_change;
        #! horizontal scroll offset for long input
        int scroll_x = 0;
    }

    /** Creates a new TextInputWidget.
        @param p the prompt string
        @since ncurses 2.0
    */
    constructor(string p = "") {
        prompt = p;
        setFocusable(True);
    }

    /** Sets the prompt.
        @param p the prompt string
        @since ncurses 2.0
    */
    nothing setPrompt(string p) {
        prompt = p;
        markDirty();
    }

    /** Returns the prompt.
        @since ncurses 2.0
    */
    string getPrompt() {
        return prompt;
    }

    /** Returns the input buffer.
        @since ncurses 2.0
    */
    NcursesReplUi::InputBuffer getBuffer() {
        return buffer;
    }

    /** Returns the current text.
        @since ncurses 2.0
    */
    string getText() {
        return buffer.getText();
    }

    /** Sets the text.
        @param t the text
        @since ncurses 2.0
    */
    nothing setText(string t) {
        buffer.setText(t);
        markDirty();
    }

    /** Sets a history instance.
        @param h the history
        @since ncurses 2.0
    */
    nothing setHistory(*NcursesReplUi::History h) {
        history = h;
    }

    /** Returns the history instance.
        @since ncurses 2.0
    */
    *NcursesReplUi::History getHistory() {
        return history;
    }

    /** Sets the submit callback.
        @param cb callback receiving the submitted text
        @since ncurses 2.0
    */
    nothing setOnSubmit(*code cb) {
        on_submit = cb;
    }

    /** Sets the text change callback.
        @param cb callback receiving the current text
        @since ncurses 2.0
    */
    nothing setOnChange(*code cb) {
        on_change = cb;
    }

    /** Returns the cursor position.
        @since ncurses 2.0
    */
    int getCursorPos() {
        return buffer.getCursor();
    }

    /** Draws the text input.
        @param w the window
        @since ncurses 2.0
    */
    nothing draw(Ncurses::Window w) {
        hash<NcursesUi::Rect> cr = contentRect();
        int row = cr.y;
        int width = cr.cols;

        # prompt + text
        string full = prompt + buffer.getText();
        int cursor_screen = prompt.length() + buffer.getCursor();

        # adjust scroll_x so cursor is visible
        if (cursor_screen < scroll_x) {
            scroll_x = cursor_screen;
        } else if (cursor_screen >= scroll_x + width) {
            scroll_x = cursor_screen - width + 1;
        }

        # extract visible portion
        string visible;
        if (scroll_x < full.length()) {
            visible = full.substr(scroll_x);
        } else {
            visible = "";
        }
        if (visible.length() > width) {
            visible = visible.substr(0, width);
        }

        # pad to width
        if (visible.length() < width) {
            visible += strmul(" ", width - visible.length());
        }

        hash<auto> style;
        if (hasFocus()) {
            style = {"attrs": Ncurses::Attr::Bold};
        }
        w.drawText(row, cr.x, visible, style);

        # position cursor
        if (hasFocus()) {
            int cx = cr.x + cursor_screen - scroll_x;
            if (cx >= cr.x && cx < cr.x + width) {
                w.moveCursor(row, cx);
            }
        }
    }

    /** Handles input events.
        @param ev the input event
        @return EventResult
        @since ncurses 2.0
    */
    hash<NcursesUi::EventResult> processEvent(hash<Ncurses::InputEvent> ev) {
        if (ev.type == Ncurses::InputType::Key) {
            return processKeyEvent(ev);
        } else if (ev.type == Ncurses::InputType::Char) {
            return processCharEvent(ev);
        }
        return <NcursesUi::EventResult>{"handled": False};
    }

    private hash<NcursesUi::EventResult> processKeyEvent(hash<Ncurses::InputEvent> ev) {
        string name = ev.name ?? "";

        if (name == "KEY_LEFT") {
            buffer.moveLeft();
            markDirty();
            return <NcursesUi::EventResult>{"handled": True};
        } else if (name == "KEY_RIGHT") {
            buffer.moveRight();
            markDirty();
            return <NcursesUi::EventResult>{"handled": True};
        } else if (name == "KEY_HOME") {
            buffer.moveHome();
            markDirty();
            return <NcursesUi::EventResult>{"handled": True};
        } else if (name == "KEY_END") {
            buffer.moveEnd();
            markDirty();
            return <NcursesUi::EventResult>{"handled": True};
        } else if (name == "KEY_BACKSPACE") {
            buffer.backspace();
            markDirty();
            notifyChange();
            return <NcursesUi::EventResult>{"handled": True};
        } else if (name == "KEY_DC") {
            buffer.deleteChar();
            markDirty();
            notifyChange();
            return <NcursesUi::EventResult>{"handled": True};
        } else if (name == "KEY_UP") {
            if (history) {
                *string prev = history.prev();
                if (exists prev) {
                    buffer.setText(prev);
                    markDirty();
                }
            }
            return <NcursesUi::EventResult>{"handled": True};
        } else if (name == "KEY_DOWN") {
            if (history) {
                *string nxt = history.next();
                if (exists nxt) {
                    buffer.setText(nxt);
                    markDirty();
                }
            }
            return <NcursesUi::EventResult>{"handled": True};
        }
        return <NcursesUi::EventResult>{"handled": False};
    }

    private hash<NcursesUi::EventResult> processCharEvent(hash<Ncurses::InputEvent> ev) {
        string ch = ev.ch ?? "";
        if (ch == "") {
            return <NcursesUi::EventResult>{"handled": False};
        }
        int code = ord(ch);

        if (code == 0x0a) {
            # submit
            string text = buffer.getText();
            if (history) {
                history.add(text);
            }
            buffer.reset();
            markDirty();
            if (on_submit) {
                on_submit(text);
            }
            return <NcursesUi::EventResult>{"handled": True, "action": "submit"};
        } else if (code == 0x01) {
            # Ctrl+A - home
            buffer.moveHome();
            markDirty();
            return <NcursesUi::EventResult>{"handled": True};
        } else if (code == 0x05) {
            # Ctrl+E - end
            buffer.moveEnd();
            markDirty();
            return <NcursesUi::EventResult>{"handled": True};
        } else if (code == 0x0b) {
            # Ctrl+K - kill to end
            buffer.killToEnd();
            markDirty();
            notifyChange();
            return <NcursesUi::EventResult>{"handled": True};
        } else if (code == 0x15) {
            # Ctrl+U - kill to start
            buffer.killToStart();
            markDirty();
            notifyChange();
            return <NcursesUi::EventResult>{"handled": True};
        } else if (code == 0x17) {
            # Ctrl+W - delete word back
            buffer.deleteWordBack();
            markDirty();
            notifyChange();
            return <NcursesUi::EventResult>{"handled": True};
        } else if (code == 0x02) {
            # Ctrl+B - left
            buffer.moveLeft();
            markDirty();
            return <NcursesUi::EventResult>{"handled": True};
        } else if (code == 0x06) {
            # Ctrl+F - right
            buffer.moveRight();
            markDirty();
            return <NcursesUi::EventResult>{"handled": True};
        } else if (code == 0x04) {
            # Ctrl+D - delete char
            buffer.deleteChar();
            markDirty();
            notifyChange();
            return <NcursesUi::EventResult>{"handled": True};
        } else if (code == 0x7f || code == 0x08) {
            # Backspace
            buffer.backspace();
            markDirty();
            notifyChange();
            return <NcursesUi::EventResult>{"handled": True};
        } else if (code >= 32) {
            # printable character
            buffer.insertChar(ch);
            markDirty();
            notifyChange();
            return <NcursesUi::EventResult>{"handled": True};
        }
        return <NcursesUi::EventResult>{"handled": False};
    }

    private nothing notifyChange() {
        if (on_change) {
            on_change(buffer.getText());
        }
    }
}
