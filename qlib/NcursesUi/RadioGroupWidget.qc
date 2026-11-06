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

public namespace NcursesUi {
/** Radio button group widget.

    Displays a list of labeled radio buttons where exactly one is
    selected. Navigate with Up/Down, select with Space/Enter.

    @since ncurses 1.0
*/
public class RadioGroupWidget inherits NcursesUi::Widget {
    private {
        *hash<NcursesUi::Rect> draw_bounds;
        #! list of option labels
        list<string> options = ();
        #! currently selected index
        int selected_index = 0;
        #! currently highlighted index (for keyboard navigation)
        int highlight_index = 0;
        #! callback fired on selection change
        *code<nothing(int)> on_select;
        int scroll_offset = 0;
    }

    /** Creates a new RadioGroupWidget.
        @param opts the option labels
        @param initial_index initially selected index
        @since ncurses 1.0
    */
    constructor(list<string> opts, int initial_index = 0) {
        options = opts;
        selected_index = options ? max(0, min(initial_index, options.size() - 1)) : -1;
        highlight_index = selected_index;
        setFocusable(True);
    }

    /** Returns the selected index.
        @since ncurses 1.0
    */
    int getSelectedIndex() {
        return selected_index;
    }

    /** Returns the selected option label.
        @since ncurses 1.0
    */
    string getSelectedOption() {
        if (options.empty()) {
            return "";
        }
        return options[selected_index];
    }

    /** Returns the highlighted index.
        @since ncurses 1.0
    */
    int getHighlightIndex() {
        return highlight_index;
    }

    /** Sets the selected index.
        @param idx the index
        @since ncurses 1.0
    */
    nothing setSelectedIndex(int idx) {
        if (idx >= 0 && idx < options.size()) {
            selected_index = idx;
            highlight_index = idx;
            ensureVisible(); markDirty();
        }
    }

    /** Sets the selection callback.
        @param cb callback receiving the selected index
        @since ncurses 1.0
    */
    nothing setOnSelect(*code<nothing(int)> cb) {
        on_select = cb;
    }

    /** Returns the option labels.
        @since ncurses 1.0
    */
    list<string> getOptions() {
        return options;
    }

    /** Sets the options.
        @param opts the new options
        @since ncurses 1.0
    */
    nothing setOptions(list<string> opts) {
        options = opts;
        selected_index = options ? max(0, min(selected_index, options.size() - 1)) : -1;
        highlight_index = options ? max(0, min(highlight_index, options.size() - 1)) : -1;
        ensureVisible(); markDirty();
    }

    /** Draws the radio group.
        @param w the window
        @since ncurses 1.0
    */
    nothing draw(Ncurses::Window w) {
        hash<Ncurses::Position> origin = w.position(); hash<Ncurses::Size> size = w.size();
        draw_bounds = NcursesUi::Geometry::makeRect(origin.y, origin.x, size.rows, size.cols);
        ensureVisible();
        hash<NcursesUi::Rect> cr = viewRect(); cr.y -= origin.y; cr.x -= origin.x;
        for (int row = 0; row < cr.rows; ++row) {
            int i = scroll_offset + row;
            w.drawHLine(cr.y + row, cr.x, cr.cols, " ");
            if (i >= options.size()) { continue; }
            string text = (cr.cols > 4 ? (i == selected_index ? "(o) " : "( ) ") : "") + options[i];
            w.drawText(cr.y + row, cr.x, TerminalText::clipRight(text, cr.cols),
                hasFocus() && i == highlight_index ? {"attrs": Ncurses::Attr::Bold} : {});
        }
    }

    /** Handles navigation and selection events.
        @param ev the input event
        @return EventResult
        @since ncurses 1.0
    */
    hash<NcursesUi::EventResult> processEvent(hash<Ncurses::InputEvent> ev) {
        if (!isAvailable() || !options) { return <NcursesUi::EventResult>{"handled": False}; }
        if (ev.type == Ncurses::InputType::Key) {
            switch (ev.name ?? "") {
                case "KEY_UP": --highlight_index; break;
                case "KEY_DOWN": ++highlight_index; break;
                case "KEY_HOME": highlight_index = 0; break;
                case "KEY_END": highlight_index = options.size() - 1; break;
                case "KEY_PPAGE": highlight_index -= max(1, viewRect().rows); break;
                case "KEY_NPAGE": highlight_index += max(1, viewRect().rows); break;
                case "KEY_ENTER": selectHighlighted(); return <NcursesUi::EventResult>{"handled": True, "action": "select"};
                default: return <NcursesUi::EventResult>{"handled": False};
            }
        } else if (ev.type == Ncurses::InputType::Char && (ev.ch == " " || ev.ch == "\n" || ev.ch == "\r")) {
            selectHighlighted(); return <NcursesUi::EventResult>{"handled": True, "action": "select"};
        } else if (ev.type == Ncurses::InputType::Mouse && ev.mouse) {
            hash<NcursesUi::Rect> cr = viewRect();
            if (!NcursesUi::Geometry::rectContains(cr, ev.mouse.y, ev.mouse.x)) {
                return <NcursesUi::EventResult>{"handled": False};
            }
            int bs = ev.mouse.button_state;
            if (bs & Ncurses::BUTTON4_PRESSED) { --highlight_index; }
            else if (bs & Ncurses::BUTTON5_PRESSED) { ++highlight_index; }
            else if (bs & (Ncurses::BUTTON1_PRESSED | Ncurses::BUTTON1_CLICKED
                    | Ncurses::BUTTON1_DOUBLE_CLICKED | Ncurses::BUTTON1_TRIPLE_CLICKED)) {
                int index = scroll_offset + ev.mouse.y - cr.y;
                if (index >= options.size()) { return <NcursesUi::EventResult>{"handled": False}; }
                highlight_index = index; selectHighlighted();
                return <NcursesUi::EventResult>{"handled": True, "action": "select"};
            } else { return <NcursesUi::EventResult>{"handled": False}; }
        } else { return <NcursesUi::EventResult>{"handled": False}; }
        highlight_index = max(0, min(highlight_index, options.size() - 1));
        ensureVisible(); markDirty();
        return <NcursesUi::EventResult>{"handled": True};
    }

    private hash<NcursesUi::Rect> viewRect() {
        hash<NcursesUi::Rect> rect = NcursesUi::Geometry::intersect(contentRect(), visibleRect());
        return draw_bounds ? NcursesUi::Geometry::intersect(rect, draw_bounds) : rect;
    }

    private nothing ensureVisible() {
        int count = max(1, viewRect().rows);
        scroll_offset = max(0, min(scroll_offset, options.size() - count));
        if (highlight_index < scroll_offset) { scroll_offset = max(0, highlight_index); }
        else if (highlight_index >= scroll_offset + count) { scroll_offset = highlight_index - count + 1; }
    }

    private nothing selectHighlighted() {
        selected_index = highlight_index;
        ensureVisible(); markDirty();
        if (on_select) {
            on_select(selected_index);
        }
    }
}

} # namespace NcursesUi
