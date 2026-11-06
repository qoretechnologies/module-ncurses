#! @file ComboBoxWidget.qc Text input with dropdown list

/*  ComboBoxWidget.qc Copyright 2026 Qore Technologies, s.r.o.

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
/** Text input with dropdown list (combo box).

    Combines a text input field with a filterable dropdown list.
    Type to filter options, use Up/Down to navigate the dropdown,
    Enter to select. Drawing establishes the target window's available extent;
    dropdown scrolling and mouse hit-testing use that same clipped geometry.
    Before the first draw, the widget frame supplies the available extent.

    @since ncurses 1.0
*/
public class ComboBoxWidget inherits NcursesUi::Widget {
    private {
        #! all options
        list<string> all_options = ();
        #! filtered options
        list<string> filtered_options = ();
        #! current text input
        NcursesReplUi::InputBuffer buffer();
        int scroll_x = 0;
        *Ncurses::Window cursor_window;
        int cursor_request = 0;
        #! most recently painted window extent, shared by drawing and hit testing
        *hash<Ncurses::Size> draw_size;
        #! whether dropdown is open
        bool dropdown_open = False;
        #! highlighted option in dropdown
        int highlight_index = -1;
        #! dropdown scroll offset
        int dropdown_scroll = 0;
        #! max visible dropdown items
        int max_dropdown_items = 8;
        #! callback on selection
        *code<nothing(string)> on_select;
        #! callback on text change
        *code<nothing(string)> on_change;
        #! input style
        hash<auto> input_style;
        #! highlight style
        hash<auto> highlight_style = {"attrs": Ncurses::Attr::Reverse};
    }

    /** Creates a new ComboBoxWidget.
        @param options the available options
        @since ncurses 1.0
    */
    constructor(list<string> options = ()) {
        all_options = options;
        filtered_options = options;
        setFocusable(True);
    }

    /** Sets the options.
        @param options the available options
        @since ncurses 1.0
    */
    nothing setOptions(list<string> options) {
        all_options = options;
        updateFilter();
        markDirty();
    }

    /** Returns all options.
        @since ncurses 1.0
    */
    list<string> getOptions() {
        return all_options;
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
        updateFilter();
        markDirty();
    }

    /** Returns whether the dropdown is open.
        @since ncurses 1.0
    */
    bool isDropdownOpen() {
        return dropdown_open;
    }

    /** Returns the highlighted index in the dropdown.
        @since ncurses 1.0
    */
    int getHighlightIndex() {
        return highlight_index;
    }

    /** Returns the filtered options.
        @since ncurses 1.0
    */
    list<string> getFilteredOptions() {
        return filtered_options;
    }

    /** Sets the selection callback.
        @param cb callback(string selected_text)
        @since ncurses 1.0
    */
    nothing setOnSelect(*code<nothing(string)> cb) {
        on_select = cb;
    }

    /** Sets the text change callback.
        @param cb callback(string text)
        @since ncurses 1.0
    */
    nothing setOnChange(*code<nothing(string)> cb) {
        on_change = cb;
    }

    /** Returns the cursor as a Qore character offset at a grapheme boundary.
        @return character offset in the current text
        @since ncurses 1.0
    */
    int getCursorPos() {
        return buffer.getCursor();
    }

    /** Returns True because the combo box includes a text editor.
        @return True
        @since ncurses 1.0
    */
    bool wantsCursor() {
        return True;
    }

    destructor() {
        releaseCursor();
    }

    /** Releases the cursor and closes the dropdown on focus loss.
        @since ncurses 1.0
    */
    nothing onFocusOut() {
        releaseCursor();
        closeDropdown();
    }

    /** Draws the combo box.
        @param w the window
        @since ncurses 1.0
    */
    nothing draw(Ncurses::Window w) {
        releaseCursor();
        draw_size = w.size();
        hash<NcursesUi::Rect> cr = drawableRect();
        if (cr.rows <= 0 || cr.cols <= 0) {
            return;
        }
        int cols = cr.cols;
        int width = max(0, cols - 2);
        updateScroll(width);
        string padded = TerminalText::columnSlice(buffer.getText(), scroll_x, width);
        string arrow = dropdown_open ? "^" : "v";
        string input_text = cols == 1 ? arrow : padded + " " + arrow;

        hash<auto> style;
        if (hasFocus()) {
            style = {"attrs": Ncurses::Attr::Bold};
        }
        w.drawHLine(cr.y, cr.x, cols, " ");
        w.drawText(cr.y, cr.x, input_text, style);
        if (hasFocus() && width > 0) {
            int col = NcursesReplUi::TextPosition::columnForOffset(buffer.getText(), buffer.getCursor());
            cursor_request = w.claimCursor(cr.y, cr.x + col - scroll_x);
            cursor_window = w;
        }
        # Clear rows occupied by a previous dropdown, including an empty filter.
        for (int row = cr.y + 1; row < cr.y + cr.rows; ++row) {
            w.drawHLine(row, cr.x, cols, " ");
        }
        ensureDropdownVisible();

        # draw dropdown if open
        if (dropdown_open && filtered_options.size() > 0) {
            int dd_rows = min(filtered_options.size(), max_dropdown_items);
            dd_rows = min(dd_rows, cr.rows - 1);  # available space below input

            for (int i = 0; i < dd_rows; ++i) {
                int idx = dropdown_scroll + i;
                int row = cr.y + 1 + i;
                if (row >= cr.y + cr.rows) {
                    break;
                }

                if (idx >= 0 && idx < filtered_options.size()) {
                    string opt_text = TerminalText::fitRight(
                        filtered_options[idx], cols);

                    hash<auto> opt_style = (idx == highlight_index) ? highlight_style : {};
                    w.drawText(row, cr.x, opt_text, opt_style);
                }
            }
        }
    }

    /** Handles events.
        @param ev the input event
        @return EventResult
        @since ncurses 1.0
    */
    hash<NcursesUi::EventResult> processEvent(hash<Ncurses::InputEvent> ev) {
        if (ev.type == Ncurses::InputType::Key) {
            string name = ev.name ?? "";
            if (name == "KEY_ENTER") {
                return activateSelection();
            } else if (name == "KEY_UP" && dropdown_open) {
                if (highlight_index > 0) {
                    highlight_index -= 1;
                    ensureDropdownVisible();
                    markDirty();
                }
                return <NcursesUi::EventResult>{"handled": True};
            } else if (name == "KEY_DOWN") {
                if (!dropdown_open) {
                    openDropdown();
                } else if (highlight_index < filtered_options.size() - 1) {
                    highlight_index += 1;
                    ensureDropdownVisible();
                    markDirty();
                }
                return <NcursesUi::EventResult>{"handled": True};
            }
        } else if (ev.type == Ncurses::InputType::Char) {
            string ch = ev.ch ?? "";
            int code = ord(ch);
            if (code == 0x0a || code == 0x0d) {
                return activateSelection();
            } else if (code == 0x1b) {
                if (dropdown_open) {
                    closeDropdown();
                    return <NcursesUi::EventResult>{"handled": True};
                }
            }
        } else if (ev.type == Ncurses::InputType::Mouse && ev.mouse) {
            hash<NcursesUi::Rect> cr = drawableRect();
            if (ev.mouse.y == cr.y && isVisible()
                    && NcursesUi::Geometry::rectContains(cr, ev.mouse.y, ev.mouse.x)
                    && (ev.mouse.button_state & (Ncurses::BUTTON1_CLICKED | Ncurses::BUTTON1_PRESSED
                        | Ncurses::BUTTON1_DOUBLE_CLICKED | Ncurses::BUTTON1_TRIPLE_CLICKED))) {
                if (ev.mouse.x >= cr.x + max(0, cr.cols - 2)) {
                    if (dropdown_open) {
                        closeDropdown();
                    } else {
                        openDropdown();
                    }
                } else {
                    updateScroll(max(0, cr.cols - 2));
                    buffer.setCursor(NcursesReplUi::TextPosition::offsetForColumn(
                        buffer.getText(), scroll_x + ev.mouse.x - cr.x));
                    markDirty();
                }
                return <NcursesUi::EventResult>{"handled": True};
            }
        }
        string before = buffer.getText();
        if (buffer.processEvent(ev)) {
            if (buffer.getText() != before) {
                updateFilter();
                if (ev.type == Ncurses::InputType::Char && ord(ev.ch ?? "") >= 32) {
                    openDropdown();
                }
                markDirty();
                notifyChange();
            } else {
                markDirty();
            }
            return <NcursesUi::EventResult>{"handled": True};
        }
        return <NcursesUi::EventResult>{"handled": False};
    }

    private hash<NcursesUi::EventResult> activateSelection() {
        if (dropdown_open && highlight_index >= 0 && highlight_index < filtered_options.size()) {
            selectOption(filtered_options[highlight_index]);
        } else {
            closeDropdown();
        }
        return <NcursesUi::EventResult>{"handled": True, "action": "select"};
    }

    private nothing openDropdown() {
        dropdown_open = True;
        if (filtered_options.size() > 0 && highlight_index < 0) {
            highlight_index = 0;
        }
        markDirty();
    }

    private nothing closeDropdown() {
        dropdown_open = False;
        highlight_index = -1;
        dropdown_scroll = 0;
        markDirty();
    }

    private nothing selectOption(string opt) {
        buffer.setText(opt);
        closeDropdown();
        markDirty();
        if (on_select) {
            on_select(opt);
        }
    }

    private nothing updateFilter() {
        string text = buffer.getText();
        if (text == "") {
            filtered_options = all_options;
        } else {
            string lower_text = text.lwr();
            filtered_options = ();
            foreach string opt in (all_options) {
                if (opt.lwr().find(lower_text) >= 0) {
                    filtered_options += opt;
                }
            }
        }
        if (highlight_index >= filtered_options.size()) {
            highlight_index = filtered_options.size() > 0 ? 0 : -1;
        }
        dropdown_scroll = 0;
    }

    private hash<NcursesUi::Rect> drawableRect() {
        hash<NcursesUi::Rect> rect = contentRect();
        rect.rows = max(0, rect.rows);
        rect.cols = max(0, rect.cols);
        if (rect.y < 0 || rect.x < 0) {
            rect.rows = 0;
            rect.cols = 0;
        } else if (draw_size) {
            rect.rows = max(0, min(rect.rows, draw_size.rows - rect.y));
            rect.cols = max(0, min(rect.cols, draw_size.cols - rect.x));
        }
        return rect;
    }

    private nothing ensureDropdownVisible() {
        int visible = min(filtered_options.size(), min(max_dropdown_items, max(0, drawableRect().rows - 1)));
        if (!visible || highlight_index < 0) {
            dropdown_scroll = 0;
            return;
        }
        dropdown_scroll = min(dropdown_scroll, max(0, filtered_options.size() - visible));
        if (highlight_index < dropdown_scroll) {
            dropdown_scroll = highlight_index;
        } else if (highlight_index >= dropdown_scroll + visible) {
            dropdown_scroll = highlight_index - visible + 1;
        }
    }

    private nothing updateScroll(int width) {
        int col = NcursesReplUi::TextPosition::columnForOffset(buffer.getText(), buffer.getCursor());
        if (width <= 0) {
            scroll_x = 0;
            return;
        }
        int last = max(0, TerminalText::displayWidth(buffer.getText()) - width + 1);
        scroll_x = max(0, min(scroll_x, min(col, last)));
        if (col >= scroll_x + width) {
            scroll_x = col - width + 1;
        }
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
