#! @file CheckboxWidget.qc Checkbox toggle widget

/*  CheckboxWidget.qc Copyright 2026 Qore Technologies, s.r.o.

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

/** Checkbox toggle widget.

    Displays a labeled checkbox that can be toggled on/off with
    Space, Enter, or mouse click.

    @since ncurses 2.0
*/
public namespace NcursesUi {
public class CheckboxWidget inherits NcursesUi::Widget {
    private {
        #! the label text
        string label;
        #! whether the checkbox is checked
        bool checked = False;
        #! callback fired on toggle
        *code on_toggle;
    }

    /** Creates a new CheckboxWidget.
        @param lbl the label
        @param initial_checked initial state
        @since ncurses 2.0
    */
    constructor(string lbl, bool initial_checked = False) {
        label = lbl;
        checked = initial_checked;
        setFocusable(True);
    }

    /** Returns whether the checkbox is checked.
        @since ncurses 2.0
    */
    bool isChecked() {
        return checked;
    }

    /** Sets the checked state.
        @param v the state
        @since ncurses 2.0
    */
    nothing setChecked(bool v) {
        checked = v;
        markDirty();
    }

    /** Toggles the checked state.
        @since ncurses 2.0
    */
    nothing toggle() {
        checked = !checked;
        markDirty();
        if (on_toggle) {
            on_toggle(checked);
        }
    }

    /** Sets the toggle callback.
        @param cb callback receiving the new checked state
        @since ncurses 2.0
    */
    nothing setOnToggle(*code cb) {
        on_toggle = cb;
    }

    /** Returns the label text.
        @since ncurses 2.0
    */
    string getLabel() {
        return label;
    }

    /** Sets the label text.
        @param lbl the new label
        @since ncurses 2.0
    */
    nothing setLabel(string lbl) {
        label = lbl;
        markDirty();
    }

    /** Draws the checkbox.
        @param w the window
        @since ncurses 2.0
    */
    nothing draw(Ncurses::Window w) {
        hash<NcursesUi::Rect> cr = contentRect();
        string indicator = checked ? "[X]" : "[ ]";
        string text = indicator + " " + label;

        # truncate to fit
        text = TerminalText::clipRight(text, cr.cols);

        hash<auto> style;
        if (hasFocus()) {
            style = {"attrs": Ncurses::Attr::Bold};
        }

        w.drawHLine(cr.y, cr.x, cr.cols, " ");
        w.drawText(cr.y, cr.x, text, style);
    }

    /** Handles toggle events.
        @param ev the input event
        @return EventResult
        @since ncurses 2.0
    */
    hash<NcursesUi::EventResult> processEvent(hash<Ncurses::InputEvent> ev) {
        if (ev.type == Ncurses::InputType::Char) {
            int code = ord(ev.ch ?? "");
            if (code == 0x20 || code == 0x0a) {
                toggle();
                return <NcursesUi::EventResult>{"handled": True, "action": "toggle"};
            }
        } else if (ev.type == Ncurses::InputType::Mouse) {
            int bs = ev.mouse.button_state;
            if (bs & Ncurses::BUTTON1_CLICKED || bs & Ncurses::BUTTON1_PRESSED) {
                toggle();
                return <NcursesUi::EventResult>{"handled": True, "action": "toggle"};
            }
        }
        return <NcursesUi::EventResult>{"handled": False};
    }
}

} # namespace NcursesUi
