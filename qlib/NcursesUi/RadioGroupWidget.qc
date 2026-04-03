#! @file RadioGroupWidget.qc Radio button group widget

/*  RadioGroupWidget.qc Copyright 2026 Qore Technologies, s.r.o.

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

/** Radio button group widget.

    Displays a list of labeled radio buttons where exactly one is
    selected. Navigate with Up/Down, select with Space/Enter.

    @since ncurses 2.0
*/
public namespace NcursesUi {
public class RadioGroupWidget inherits NcursesUi::Widget {
    private {
        #! list of option labels
        list<string> options = ();
        #! currently selected index
        int selected_index = 0;
        #! currently highlighted index (for keyboard navigation)
        int highlight_index = 0;
        #! callback fired on selection change
        *code on_select;
    }

    /** Creates a new RadioGroupWidget.
        @param opts the option labels
        @param initial_index initially selected index
        @since ncurses 2.0
    */
    constructor(list<string> opts, int initial_index = 0) {
        options = opts;
        if (initial_index >= 0 && initial_index < options.size()) {
            selected_index = initial_index;
            highlight_index = initial_index;
        }
        setFocusable(True);
    }

    /** Returns the selected index.
        @since ncurses 2.0
    */
    int getSelectedIndex() {
        return selected_index;
    }

    /** Returns the selected option label.
        @since ncurses 2.0
    */
    string getSelectedOption() {
        if (options.empty()) {
            return "";
        }
        return options[selected_index];
    }

    /** Returns the highlighted index.
        @since ncurses 2.0
    */
    int getHighlightIndex() {
        return highlight_index;
    }

    /** Sets the selected index.
        @param idx the index
        @since ncurses 2.0
    */
    nothing setSelectedIndex(int idx) {
        if (idx >= 0 && idx < options.size()) {
            selected_index = idx;
            highlight_index = idx;
            markDirty();
        }
    }

    /** Sets the selection callback.
        @param cb callback receiving the selected index
        @since ncurses 2.0
    */
    nothing setOnSelect(*code cb) {
        on_select = cb;
    }

    /** Returns the option labels.
        @since ncurses 2.0
    */
    list<string> getOptions() {
        return options;
    }

    /** Sets the options.
        @param opts the new options
        @since ncurses 2.0
    */
    nothing setOptions(list<string> opts) {
        options = opts;
        if (selected_index >= options.size()) {
            selected_index = 0;
        }
        if (highlight_index >= options.size()) {
            highlight_index = 0;
        }
        markDirty();
    }

    /** Draws the radio group.
        @param w the window
        @since ncurses 2.0
    */
    nothing draw(Ncurses::Window w) {
        hash<NcursesUi::Rect> cr = contentRect();

        for (int i = 0; i < options.size() && i < cr.rows; ++i) {
            string indicator = (i == selected_index) ? "(o)" : "( )";
            string text = indicator + " " + options[i];

            # truncate to fit
            if (text.length() > cr.cols) {
                text = text.substr(0, cr.cols);
            }

            hash<auto> style;
            if (hasFocus() && i == highlight_index) {
                style = {"attrs": Ncurses::Attr::Bold};
            }

            w.drawHLine(cr.y + i, cr.x, cr.cols, " ");
            w.drawText(cr.y + i, cr.x, text, style);
        }
    }

    /** Handles navigation and selection events.
        @param ev the input event
        @return EventResult
        @since ncurses 2.0
    */
    hash<NcursesUi::EventResult> processEvent(hash<Ncurses::InputEvent> ev) {
        if (options.empty()) {
            return <NcursesUi::EventResult>{"handled": False};
        }

        if (ev.type == Ncurses::InputType::Key) {
            string name = ev.name ?? "";
            if (name == "KEY_UP") {
                if (highlight_index > 0) {
                    highlight_index -= 1;
                    markDirty();
                }
                return <NcursesUi::EventResult>{"handled": True};
            } else if (name == "KEY_DOWN") {
                if (highlight_index < options.size() - 1) {
                    highlight_index += 1;
                    markDirty();
                }
                return <NcursesUi::EventResult>{"handled": True};
            }
        } else if (ev.type == Ncurses::InputType::Char) {
            int code = ord(ev.ch ?? "");
            if (code == 0x20 || code == 0x0a) {
                selectHighlighted();
                return <NcursesUi::EventResult>{"handled": True, "action": "select"};
            }
        } else if (ev.type == Ncurses::InputType::Mouse) {
            int bs = ev.mouse.button_state;
            if (bs & Ncurses::BUTTON1_CLICKED || bs & Ncurses::BUTTON1_PRESSED) {
                hash<NcursesUi::Rect> cr = contentRect();
                int click_row = ev.mouse.y - cr.y;
                if (click_row >= 0 && click_row < options.size()) {
                    highlight_index = click_row;
                    selectHighlighted();
                    return <NcursesUi::EventResult>{"handled": True, "action": "select"};
                }
            }
        }
        return <NcursesUi::EventResult>{"handled": False};
    }

    private nothing selectHighlighted() {
        selected_index = highlight_index;
        markDirty();
        if (on_select) {
            on_select(selected_index);
        }
    }
}

} # namespace NcursesUi
