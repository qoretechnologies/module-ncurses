#! @file DialogWidget.qc Modal dialog with buttons

/*  DialogWidget.qc Copyright 2026 Qore Technologies, s.r.o.

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
/** Modal dialog widget with message and configurable buttons.

    Displays a centered dialog with a title, message text, and
    one or more buttons. Navigate buttons with Tab/Arrow keys,
    activate with Enter, dismiss with Escape.

    @par Factory methods
    - @ref confirm() - confirmation dialog with OK/Cancel
    - @ref error() - error dialog with OK button

    @since ncurses 1.0
*/
public class DialogWidget inherits NcursesUi::PanelWidget {
    private {
        int message_offset = 0;
        bool show_message = False;
        #! message lines
        list<string> message_lines = ();
        #! button labels
        list<string> buttons = ();
        #! currently focused button index
        int focused_button = 0;
        #! callback on button press: code(int index, string label)
        *code<nothing(int, string)> on_button;
        #! callback on dismiss (Escape)
        *code<nothing()> on_dismiss;
        #! button style
        hash<auto> button_style = {"attrs": Ncurses::Attr::Bold};
        #! focused button style
        hash<auto> focused_button_style = {"fg": Ncurses::Color::Yellow, "bg": Ncurses::Color::Blue,
            "attrs": Ncurses::Attr::Bold};
        #! panel-local rects for each button (for mouse hit testing)
        list<hash<NcursesUi::Rect>> button_rects = ();
    }

    /** Creates a new DialogWidget.
        @param s the session
        @param title_text the dialog title
        @param msg the message text (newlines create multiple lines)
        @param btn_labels button labels
        @since ncurses 1.0
    */
    constructor(Ncurses::Session s, string title_text, string msg, list<string> btn_labels = ("OK",))
            : PanelWidget(s, title_text) {
        message_lines = msg.split("\n");
        buttons = btn_labels;
        setFocusable(True);
        setCenterTitle(True);
    }

    /** Sets the message text.
        @param msg the message
        @since ncurses 1.0
    */
    nothing setMessage(string msg) {
        message_lines = msg.split("\n");
        markDirty();
    }

    /** Returns the message lines.
        @since ncurses 1.0
    */
    list<string> getMessageLines() {
        return message_lines;
    }

    /** Sets the buttons.
        @param btn_labels the button labels
        @since ncurses 1.0
    */
    nothing setButtons(list<string> btn_labels) {
        buttons = btn_labels;
        if (focused_button >= buttons.size()) {
            focused_button = 0;
        }
        markDirty();
    }

    /** Returns the button labels.
        @since ncurses 1.0
    */
    list<string> getButtons() {
        return buttons;
    }

    /** Returns the focused button index.
        @since ncurses 1.0
    */
    int getFocusedButton() {
        return focused_button;
    }

    /** Sets the button press callback.
        @param cb callback(int index, string label)
        @since ncurses 1.0
    */
    nothing setOnButton(*code<nothing(int, string)> cb) {
        on_button = cb;
    }

    /** Sets the dismiss (Escape) callback.
        @param cb callback
        @since ncurses 1.0
    */
    nothing setOnDismiss(*code<nothing()> cb) {
        on_dismiss = cb;
    }

    /** Centers the dialog within the given screen dimensions.
        @param screen_rows terminal rows
        @param screen_cols terminal columns
        @since ncurses 1.0
    */
    nothing centerOn(int screen_rows, int screen_cols) {
        # inner padding inside the content rect (inside border)
        int pad_h = 1;  # top and bottom padding rows
        int pad_w = 1;  # left and right padding columns

        # calculate needed content size
        int max_msg_width = 0;
        foreach string line in (message_lines) {
            int w = Ncurses::Ansi::len(line);
            if (w > max_msg_width) {
                max_msg_width = w;
            }
        }

        # button row width (must match draw()'s total_btn_width calculation)
        int btn_width = 0;
        for (int i = 0; i < buttons.size(); ++i) {
            btn_width += TerminalText::displayWidth(buttons[i]) + 4;  # "[ label ]"
            if (i < buttons.size() - 1) {
                btn_width += 1;  # space between buttons
            }
        }

        int content_width = max(max_msg_width, btn_width);
        # border(2) + inner padding(2*pad_w) + content padding(2)
        int dialog_width = content_width + 4 + (2 * pad_w);
        # border(2) + top_pad + msg_lines + gap(1) + buttons(1) + bottom_pad
        int dialog_height = message_lines.size() + 5 + (2 * pad_h);

        # clamp to screen with minimums
        dialog_width = max(0, min(max(dialog_width, 24), screen_cols > 26 ? screen_cols - 2 : screen_cols));
        dialog_height = max(0, min(max(dialog_height, 7), screen_rows > 9 ? screen_rows - 2 : screen_rows));
        setHasBorder(dialog_height >= 3 && dialog_width >= 3);

        # ensure buttons can be perfectly centered (even remainder)
        if ((dialog_width - 2 - btn_width) % 2 != 0 && dialog_width < screen_cols - 2) {
            dialog_width += 1;
        }

        int dy = (screen_rows - dialog_height) / 2;
        int dx = (screen_cols - dialog_width) / 2;

        resize(NcursesUi::Geometry::makeRect(dy, dx, dialog_height, dialog_width));
    }

    /** Returns the button rects in panel-local coordinates.
        @since ncurses 1.0
    */
    list<hash<NcursesUi::Rect>> getButtonRects() {
        return button_rects;
    }

    /** Draws the dialog content (message + buttons).
        @param w the window
        @since ncurses 1.0
    */
    nothing draw(Ncurses::Window w) {
        PanelWidget::draw(w);
        if (!getWindow()) { return; }
        w = getWindow();
        hash<NcursesUi::Rect> cr = localContentRect();
        int pad = cr.rows >= 5 && cr.cols >= 4 ? 1 : 0;
        int width = max(0, cr.cols - 2 * pad);
        bool compact_message = show_message && cr.rows <= 2;
        int message_rows = compact_message ? cr.rows : max(0, cr.rows - 2 * pad - (buttons ? 2 : 0));
        list<string> lines = wrappedMessage(max(1, width));
        message_offset = max(0, min(message_offset, lines.size() - max(1, message_rows)));
        for (int i = 0; i < message_rows && i + message_offset < lines.size(); ++i) {
            string line = lines[i + message_offset];
            int offset = max(0, (width - Ncurses::Ansi::len(line)) / 2);
            w.drawAnsiText(cr.y + pad + i, cr.x + pad + offset, line);
        }
        button_rects = ();
        int total = 0;
        foreach string label in (buttons) { total += TerminalText::displayWidth(label) + 5; }
        if (buttons) { --total; }
        int row = cr.y + cr.rows - 1 - pad;
        int x = cr.x + max(0, (cr.cols - total) / 2);
        for (int i = 0; i < buttons.size(); ++i) {
            hash<NcursesUi::Rect> rect = NcursesUi::Geometry::makeRect(row, cr.x, 0, 0);
            # On narrow screens show the focused action; Tab still reaches every action.
            if (!compact_message && cr.rows > 0 && cr.cols > 0 && (total <= cr.cols || i == focused_button)) {
                string full = "[ " + buttons[i] + " ]";
                string label = TerminalText::clipRight(TerminalText::displayWidth(full) <= cr.cols
                    ? full : (buttons[i] == "" ? "[]" : buttons[i]), cr.cols);
                int count = TerminalText::displayWidth(label);
                rect = NcursesUi::Geometry::makeRect(row, x, 1, count);
                w.drawText(row, x, label, i == focused_button ? focused_button_style : button_style);
                x += count + 1;
            }
            button_rects += rect;
        }
        if (focused_button >= 0 && focused_button < button_rects.size()) {
            hash<NcursesUi::Rect> rect = button_rects[focused_button];
            if (rect.rows > 0 && rect.cols > 0) {
                hash<NcursesUi::Rect> frame = getFrame();
                getSession().screen().moveCursor(frame.y + rect.y, frame.x + rect.x + min(2, rect.cols - 1));
            }
        }
    }

    /** Reflows the dialog on terminal resize while retaining the active action.
        @param rows screen height
        @param cols screen width
    */
    nothing fitToScreen(int rows, int cols) { centerOn(rows, cols); }

    private list<string> wrappedMessage(int width) {
        list<string> lines = ();
        foreach string line in (message_lines) {
            list<string> wrapped = Ncurses::Ansi::wrap(line, width, Ncurses::WrapMode::Hard);
            lines += wrapped ? wrapped : ("",);
        }
        return lines;
    }

    private nothing scrollMessage(int direction, bool page = False) {
        hash<NcursesUi::Rect> cr = localContentRect();
        int pad = cr.rows >= 5 && cr.cols >= 4 ? 1 : 0;
        int visible = max(1, cr.rows - 2 * pad - (buttons ? 2 : 0));
        int count = wrappedMessage(max(1, cr.cols - 2 * pad)).size();
        if (!show_message && cr.rows <= 2) { show_message = True; }
        else { message_offset = max(0, min(message_offset + direction * (page ? visible : 1), count - visible)); }
        markDirty();
    }

    /** Handles dialog events.
        @param ev the input event
        @return EventResult
        @since ncurses 1.0
    */
    hash<NcursesUi::EventResult> processEvent(hash<Ncurses::InputEvent> ev) {
        if (ev.type == Ncurses::InputType::Mouse) {
            int bs = ev.mouse.button_state;
            if (bs & Ncurses::BUTTON1_CLICKED || bs & Ncurses::BUTTON1_PRESSED) {
                # convert absolute screen coords to panel-local coords
                hash<NcursesUi::Rect> f = getFrame();
                int local_x = ev.mouse.x - f.x;
                int local_y = ev.mouse.y - f.y;

                for (int i = 0; i < button_rects.size(); ++i) {
                    hash<NcursesUi::Rect> br = button_rects[i];
                    if (NcursesUi::Geometry::rectContains(br, local_y, local_x)) {
                        focused_button = i;
                        markDirty();
                        return pressButton();
                    }
                }
                # click inside dialog but not on a button — consume event
                return <NcursesUi::EventResult>{"handled": True};
            }
            # consume all other mouse events inside the dialog
            return <NcursesUi::EventResult>{"handled": True};
        } else if (ev.type == Ncurses::InputType::Char) {
            int code = ord(ev.ch ?? "");
            if (code == 0x0a || code == 0x0d) {
                if (buttons.empty()) {
                    return <NcursesUi::EventResult>{"handled": True};
                }
                return pressButton();
            } else if (code == 0x1b) {
                # Escape
                if (on_dismiss) {
                    on_dismiss();
                }
                return <NcursesUi::EventResult>{"handled": True, "action": "dismiss"};
            } else if (code == 0x09) {
                # Tab - next button
                if (buttons.empty()) {
                    return <NcursesUi::EventResult>{"handled": True};
                }
                show_message = False;
                focused_button = (focused_button + 1) % buttons.size();
                markDirty();
                return <NcursesUi::EventResult>{"handled": True};
            }
        } else if (ev.type == Ncurses::InputType::Key) {
            string name = ev.name ?? "";
            if (name == "KEY_UP" || name == "KEY_DOWN" || name == "KEY_PPAGE" || name == "KEY_NPAGE") {
                scrollMessage(name == "KEY_UP" || name == "KEY_PPAGE" ? -1 : 1,
                    name == "KEY_PPAGE" || name == "KEY_NPAGE");
                return <NcursesUi::EventResult>{"handled": True};
            } else if (name == "KEY_ENTER") { return pressButton();
            } else if (name == "KEY_LEFT") {
                show_message = False;
                if (focused_button > 0) {
                    focused_button -= 1;
                    markDirty();
                }
                return <NcursesUi::EventResult>{"handled": True};
            } else if (name == "KEY_RIGHT") {
                show_message = False;
                if (focused_button < buttons.size() - 1) {
                    focused_button += 1;
                    markDirty();
                }
                return <NcursesUi::EventResult>{"handled": True};
            } else if (name == "KEY_BTAB") {
                # Shift+Tab - previous button
                if (buttons.empty()) {
                    return <NcursesUi::EventResult>{"handled": True};
                }
                show_message = False;
                focused_button = (focused_button - 1 + buttons.size()) % buttons.size();
                markDirty();
                return <NcursesUi::EventResult>{"handled": True};
            }
        }
        return <NcursesUi::EventResult>{"handled": False};
    }

    /** Creates a confirmation dialog.
        @param s the session
        @param title_text the title
        @param msg the message
        @param cb callback(int index, string label)
        @return the dialog widget
        @since ncurses 1.0
    */
    static NcursesUi::DialogWidget confirm(Ncurses::Session s, string title_text, string msg,
            *code<nothing(int, string)> cb) {
        NcursesUi::DialogWidget dlg(s, title_text, msg, ("OK", "Cancel"));
        dlg.setOnButton(cb);
        return dlg;
    }

    /** Creates an error dialog.
        @param s the session
        @param title_text the title
        @param msg the message
        @return the dialog widget
        @since ncurses 1.0
    */
    static NcursesUi::DialogWidget error(Ncurses::Session s, string title_text, string msg) {
        return new NcursesUi::DialogWidget(s, title_text, msg, ("OK",));
    }

    private hash<NcursesUi::EventResult> pressButton() {
        if (focused_button < 0 || focused_button >= buttons.size()) {
            return <NcursesUi::EventResult>{"handled": True};
        }
        show_message = False;
        int index = focused_button; string label = buttons[index];
        if (on_button) { on_button(index, label); }
        return <NcursesUi::EventResult>{"handled": True, "action": "button",
            "data": {"index": index, "label": label}};
    }
}

} # namespace NcursesUi
