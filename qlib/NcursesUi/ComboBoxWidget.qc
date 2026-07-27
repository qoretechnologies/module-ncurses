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

/** Text input with dropdown list (combo box).

    Combines a text input field with a filterable dropdown list.
    Type to filter options, use Up/Down to navigate the dropdown,
    Enter to select.

    @since ncurses 2.0
*/
public namespace NcursesUi {
public class ComboBoxWidget inherits NcursesUi::Widget {
    private {
        #! all options
        list<string> all_options = ();
        #! filtered options
        list<string> filtered_options = ();
        #! current text input
        string text = "";
        #! cursor position
        int cursor = 0;
        #! whether dropdown is open
        bool dropdown_open = False;
        #! highlighted option in dropdown
        int highlight_index = -1;
        #! dropdown scroll offset
        int dropdown_scroll = 0;
        #! max visible dropdown items
        int max_dropdown_items = 8;
        #! callback on selection
        *code on_select;
        #! callback on text change
        *code on_change;
        #! input style
        hash<auto> input_style;
        #! highlight style
        hash<auto> highlight_style = {"attrs": Ncurses::Attr::Reverse};
    }

    /** Creates a new ComboBoxWidget.
        @param options the available options
        @since ncurses 2.0
    */
    constructor(list<string> options = ()) {
        all_options = options;
        filtered_options = options;
        setFocusable(True);
    }

    /** Sets the options.
        @param options the available options
        @since ncurses 2.0
    */
    nothing setOptions(list<string> options) {
        all_options = options;
        updateFilter();
        markDirty();
    }

    /** Returns all options.
        @since ncurses 2.0
    */
    list<string> getOptions() {
        return all_options;
    }

    /** Returns the current text.
        @since ncurses 2.0
    */
    string getText() {
        return text;
    }

    /** Sets the text.
        @param t the text
        @since ncurses 2.0
    */
    nothing setText(string t) {
        text = t;
        cursor = text.length();
        updateFilter();
        markDirty();
    }

    /** Returns whether the dropdown is open.
        @since ncurses 2.0
    */
    bool isDropdownOpen() {
        return dropdown_open;
    }

    /** Returns the highlighted index in the dropdown.
        @since ncurses 2.0
    */
    int getHighlightIndex() {
        return highlight_index;
    }

    /** Returns the filtered options.
        @since ncurses 2.0
    */
    list<string> getFilteredOptions() {
        return filtered_options;
    }

    /** Sets the selection callback.
        @param cb callback(string selected_text)
        @since ncurses 2.0
    */
    nothing setOnSelect(*code cb) {
        on_select = cb;
    }

    /** Sets the text change callback.
        @param cb callback(string text)
        @since ncurses 2.0
    */
    nothing setOnChange(*code cb) {
        on_change = cb;
    }

    /** Draws the combo box.
        @param w the window
        @since ncurses 2.0
    */
    nothing draw(Ncurses::Window w) {
        hash<NcursesUi::Rect> cr = contentRect();

        # draw input line
        string display = text;
        string padded = TerminalText::fitRight(display, max(0, cr.cols - 2));
        string arrow = dropdown_open ? "^" : "v";
        string input_text = padded + " " + arrow;

        hash<auto> style;
        if (hasFocus()) {
            style = {"attrs": Ncurses::Attr::Bold};
        }
        w.drawHLine(cr.y, cr.x, cr.cols, " ");
        w.drawText(cr.y, cr.x, input_text, style);

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
                        filtered_options[idx], cr.cols);

                    hash<auto> opt_style = (idx == highlight_index) ? highlight_style : {};
                    w.drawText(row, cr.x, opt_text, opt_style);
                }
            }
        }
    }

    /** Handles events.
        @param ev the input event
        @return EventResult
        @since ncurses 2.0
    */
    hash<NcursesUi::EventResult> processEvent(hash<Ncurses::InputEvent> ev) {
        if (ev.type == Ncurses::InputType::Key) {
            string name = ev.name ?? "";
            if (name == "KEY_UP" && dropdown_open) {
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
            } else if (name == "KEY_BACKSPACE") {
                if (cursor > 0) {
                    text = text.substr(0, cursor - 1) + text.substr(cursor);
                    cursor -= 1;
                    updateFilter();
                    markDirty();
                    notifyChange();
                }
                return <NcursesUi::EventResult>{"handled": True};
            }
        } else if (ev.type == Ncurses::InputType::Char) {
            string ch = ev.ch ?? "";
            int code = ord(ch);
            if (code == 0x0a) {
                if (dropdown_open && highlight_index >= 0
                        && highlight_index < filtered_options.size()) {
                    selectOption(filtered_options[highlight_index]);
                } else {
                    closeDropdown();
                }
                return <NcursesUi::EventResult>{"handled": True, "action": "select"};
            } else if (code == 0x1b) {
                if (dropdown_open) {
                    closeDropdown();
                    return <NcursesUi::EventResult>{"handled": True};
                }
            } else if (code >= 32) {
                text = text.substr(0, cursor) + ch + text.substr(cursor);
                cursor += ch.length();
                updateFilter();
                openDropdown();
                markDirty();
                notifyChange();
                return <NcursesUi::EventResult>{"handled": True};
            }
        }
        return <NcursesUi::EventResult>{"handled": False};
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
        text = opt;
        cursor = text.length();
        closeDropdown();
        markDirty();
        if (on_select) {
            on_select(opt);
        }
    }

    private nothing updateFilter() {
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

    private nothing ensureDropdownVisible() {
        int visible = min(filtered_options.size(), max_dropdown_items);
        if (highlight_index < dropdown_scroll) {
            dropdown_scroll = highlight_index;
        } else if (highlight_index >= dropdown_scroll + visible) {
            dropdown_scroll = highlight_index - visible + 1;
        }
    }

    private nothing notifyChange() {
        if (on_change) {
            on_change(text);
        }
    }
}

} # namespace NcursesUi
