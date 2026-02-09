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

/** Modal dialog widget with message and configurable buttons.

    Displays a centered dialog with a title, message text, and
    one or more buttons. Navigate buttons with Tab/Arrow keys,
    activate with Enter, dismiss with Escape.

    @par Factory methods
    - @ref confirm() - confirmation dialog with OK/Cancel
    - @ref error() - error dialog with OK button

    @since ncurses 2.0
*/
public class NcursesUi::DialogWidget inherits NcursesUi::PanelWidget {
    private {
        #! message lines
        list<string> message_lines = ();
        #! button labels
        list<string> buttons = ();
        #! currently focused button index
        int focused_button = 0;
        #! callback on button press: code(int index, string label)
        *code on_button;
        #! callback on dismiss (Escape)
        *code on_dismiss;
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
        @since ncurses 2.0
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
        @since ncurses 2.0
    */
    nothing setMessage(string msg) {
        message_lines = msg.split("\n");
        markDirty();
    }

    /** Returns the message lines.
        @since ncurses 2.0
    */
    list<string> getMessageLines() {
        return message_lines;
    }

    /** Sets the buttons.
        @param btn_labels the button labels
        @since ncurses 2.0
    */
    nothing setButtons(list<string> btn_labels) {
        buttons = btn_labels;
        if (focused_button >= buttons.size()) {
            focused_button = 0;
        }
        markDirty();
    }

    /** Returns the button labels.
        @since ncurses 2.0
    */
    list<string> getButtons() {
        return buttons;
    }

    /** Returns the focused button index.
        @since ncurses 2.0
    */
    int getFocusedButton() {
        return focused_button;
    }

    /** Sets the button press callback.
        @param cb callback(int index, string label)
        @since ncurses 2.0
    */
    nothing setOnButton(*code cb) {
        on_button = cb;
    }

    /** Sets the dismiss (Escape) callback.
        @param cb callback
        @since ncurses 2.0
    */
    nothing setOnDismiss(*code cb) {
        on_dismiss = cb;
    }

    /** Centers the dialog within the given screen dimensions.
        @param screen_rows terminal rows
        @param screen_cols terminal columns
        @since ncurses 2.0
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
            btn_width += buttons[i].length() + 4;  # "[ label ]"
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
        dialog_width = min(dialog_width, screen_cols - 2);
        dialog_height = min(dialog_height, screen_rows - 2);
        dialog_width = max(dialog_width, 24);
        dialog_height = max(dialog_height, 7);

        # ensure buttons can be perfectly centered (even remainder)
        if ((dialog_width - 2 - btn_width) % 2 != 0 && dialog_width < screen_cols - 2) {
            dialog_width += 1;
        }

        int dy = (screen_rows - dialog_height) / 2;
        int dx = (screen_cols - dialog_width) / 2;

        resize(NcursesUi::Geometry::makeRect(dy, dx, dialog_height, dialog_width));
    }

    /** Returns the button rects in panel-local coordinates.
        @since ncurses 2.0
    */
    list<hash<NcursesUi::Rect>> getButtonRects() {
        return button_rects;
    }

    /** Draws the dialog content (message + buttons).
        @param w the window
        @since ncurses 2.0
    */
    nothing draw(Ncurses::Window w) {
        # draw border and title via PanelWidget
        PanelWidget::draw(w);

        hash<NcursesUi::Rect> cr = localContentRect();

        # inner padding
        int pad_top = 1;
        int pad_left = 1;
        int pad_bottom = 1;
        int usable_width = cr.cols - (2 * pad_left);

        # draw message lines (centered horizontally)
        for (int i = 0; i < message_lines.size() && i < cr.rows - 2 - pad_top - pad_bottom; ++i) {
            string line = message_lines[i];
            int line_len = Ncurses::Ansi::len(line);
            if (line_len > usable_width) {
                line = line.substr(0, usable_width);
                line_len = usable_width;
            }
            int offset = max(0, (usable_width - line_len) / 2);
            w.drawText(cr.y + pad_top + i, cr.x + pad_left + offset, line);
        }

        # compute total button width for centering
        int total_btn_width = 0;
        for (int i = 0; i < buttons.size(); ++i) {
            total_btn_width += buttons[i].length() + 4;  # "[ label ]"
            if (i < buttons.size() - 1) {
                total_btn_width += 1;  # space between buttons
            }
        }

        # draw buttons on the row before bottom padding (centered)
        int btn_row = cr.y + cr.rows - 1 - pad_bottom;
        int btn_start = cr.x + max(0, (cr.cols - total_btn_width) / 2);
        int btn_x = btn_start;

        button_rects = ();
        for (int i = 0; i < buttons.size(); ++i) {
            string btn_text = "[ " + buttons[i] + " ]";
            if (btn_x + btn_text.length() > cr.x + cr.cols) {
                break;
            }
            hash<auto> style = (i == focused_button) ? focused_button_style : button_style;
            w.drawText(btn_row, btn_x, btn_text, style);
            # store panel-local rect for mouse hit testing
            button_rects += NcursesUi::Geometry::makeRect(btn_row, btn_x, 1, btn_text.length());
            btn_x += btn_text.length() + 1;
        }

        # position cursor on focused button via absolute screen coordinates
        # this overrides ScrollableWidget's cursor because modals draw after root
        if (button_rects.size() > focused_button) {
            hash<NcursesUi::Rect> f = getFrame();
            hash<NcursesUi::Rect> br = button_rects[focused_button];
            int abs_y = f.y + br.y;
            int abs_x = f.x + br.x + 2;  # +2 to skip "[ "
            getSession().screen().moveCursor(abs_y, abs_x);
        }
    }

    /** Handles dialog events.
        @param ev the input event
        @return EventResult
        @since ncurses 2.0
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
                    if (local_y == br.y && local_x >= br.x && local_x < br.x + br.cols) {
                        focused_button = i;
                        markDirty();
                        pressButton();
                        return <NcursesUi::EventResult>{"handled": True, "action": "button",
                            "data": {"index": i, "label": buttons[i]}};
                    }
                }
                # click inside dialog but not on a button — consume event
                return <NcursesUi::EventResult>{"handled": True};
            }
            # consume all other mouse events inside the dialog
            return <NcursesUi::EventResult>{"handled": True};
        } else if (ev.type == Ncurses::InputType::Char) {
            int code = ord(ev.ch ?? "");
            if (code == 0x0a) {
                if (buttons.empty()) {
                    return <NcursesUi::EventResult>{"handled": True};
                }
                pressButton();
                return <NcursesUi::EventResult>{"handled": True, "action": "button",
                    "data": {"index": focused_button, "label": buttons[focused_button]}};
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
                focused_button = (focused_button + 1) % buttons.size();
                markDirty();
                return <NcursesUi::EventResult>{"handled": True};
            }
        } else if (ev.type == Ncurses::InputType::Key) {
            string name = ev.name ?? "";
            if (name == "KEY_LEFT") {
                if (focused_button > 0) {
                    focused_button -= 1;
                    markDirty();
                }
                return <NcursesUi::EventResult>{"handled": True};
            } else if (name == "KEY_RIGHT") {
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
        @since ncurses 2.0
    */
    static NcursesUi::DialogWidget confirm(Ncurses::Session s, string title_text, string msg,
            *code cb) {
        NcursesUi::DialogWidget dlg(s, title_text, msg, ("OK", "Cancel"));
        dlg.setOnButton(cb);
        return dlg;
    }

    /** Creates an error dialog.
        @param s the session
        @param title_text the title
        @param msg the message
        @return the dialog widget
        @since ncurses 2.0
    */
    static NcursesUi::DialogWidget error(Ncurses::Session s, string title_text, string msg) {
        return new NcursesUi::DialogWidget(s, title_text, msg, ("OK",));
    }

    private nothing pressButton() {
        if (on_button && focused_button >= 0 && focused_button < buttons.size()) {
            on_button(focused_button, buttons[focused_button]);
        }
    }
}
