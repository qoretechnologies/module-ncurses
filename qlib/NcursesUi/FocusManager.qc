#! @file FocusManager.qc Focus traversal manager

/*  FocusManager.qc Copyright 2026 Qore Technologies, s.r.o.

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

/** Focus traversal manager for the widget tree.

    Tracks the currently focused widget and implements Tab/Shift+Tab
    navigation through focusable widgets.

    @since ncurses 2.0
*/
public class NcursesUi::FocusManager {
    private {
        #! the currently focused widget (or NOTHING)
        *NcursesUi::Widget current_focus;
    }

    /** Returns the currently focused widget.
        @since ncurses 2.0
    */
    *NcursesUi::Widget getCurrentFocus() {
        return current_focus;
    }

    /** Sets focus to a specific widget.

        Unfocuses the old widget and focuses the new one.

        @param w the widget to focus (or NOTHING to unfocus all)
        @since ncurses 2.0
    */
    nothing setFocus(*NcursesUi::Widget w) {
        if (current_focus == w) {
            return;
        }
        if (current_focus) {
            current_focus.setFocused(False);
        }
        current_focus = w;
        if (current_focus) {
            current_focus.setFocused(True);
        }
    }

    /** Moves focus in the given direction through the widget tree.

        Collects all focusable widgets from the root, finds the current
        one, and moves to the next/previous.

        @param root the root widget of the tree
        @param direction FocusDirection::Next or FocusDirection::Previous
        @return True if focus was moved
        @since ncurses 2.0
    */
    bool moveFocus(NcursesUi::Widget root, int direction) {
        list<NcursesUi::Widget> focusable = root.collectFocusable();
        if (!focusable.size()) {
            return False;
        }

        # find current index
        int current_idx = -1;
        for (int i = 0; i < focusable.size(); ++i) {
            if (focusable[i] == current_focus) {
                current_idx = i;
                break;
            }
        }

        int next_idx;
        if (direction == NcursesUi::FocusDirection::Next) {
            if (current_idx < 0) {
                next_idx = 0;
            } else {
                next_idx = (current_idx + 1) % focusable.size();
            }
        } else {
            if (current_idx < 0) {
                next_idx = focusable.size() - 1;
            } else {
                next_idx = (current_idx - 1 + focusable.size()) % focusable.size();
            }
        }

        setFocus(focusable[next_idx]);
        return True;
    }

    /** Handles Tab and Shift+Tab events for focus traversal.

        @param root the root widget of the tree
        @param ev the input event
        @return True if the event was consumed (Tab/Shift+Tab)
        @since ncurses 2.0
    */
    bool handleFocusEvent(NcursesUi::Widget root, hash<Ncurses::InputEvent> ev) {
        if (ev.type == Ncurses::InputType::Char && ord(ev.ch ?? "") == 0x09) {
            return moveFocus(root, NcursesUi::FocusDirection::Next);
        }
        if (ev.type == Ncurses::InputType::Key) {
            string name = ev.name ?? "";
            if (name == "KEY_BTAB") {
                return moveFocus(root, NcursesUi::FocusDirection::Previous);
            }
        }
        return False;
    }
}
