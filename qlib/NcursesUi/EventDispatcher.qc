#! @file EventDispatcher.qc Typed event dispatch with modal stack

/*  EventDispatcher.qc Copyright 2026 Qore Technologies, s.r.o.

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

/** Typed event dispatch with modal stack and hit-testing.

    Routes events through the widget tree with support for:
    - Modal widget stack (modal widget receives ALL events)
    - Mouse hit-testing (depth-first reverse order)
    - Keyboard routing to focused widget
    - Global key handlers for app-wide shortcuts
    - Escape handling (closes top modal/popup)

    @since ncurses 2.0
*/
public class NcursesUi::EventDispatcher {
    private {
        #! the focus manager
        NcursesUi::FocusManager focus_mgr;
        #! modal widget stack (last = topmost)
        list<NcursesUi::Widget> modal_stack = ();
        #! global key handler callback
        *code<hash<NcursesUi::EventResult>(hash<Ncurses::InputEvent>)> global_key_handler;
    }

    /** Creates a new EventDispatcher.
        @since ncurses 2.0
    */
    constructor() {
        focus_mgr = new NcursesUi::FocusManager();
    }

    /** Returns the focus manager.
        @since ncurses 2.0
    */
    NcursesUi::FocusManager getFocusManager() {
        return focus_mgr;
    }

    /** Pushes a modal widget onto the stack.

        While a modal is active, ALL events are routed to it.

        @param w the widget to make modal
        @since ncurses 2.0
    */
    nothing pushModal(NcursesUi::Widget w) {
        modal_stack += w;
    }

    /** Pops the topmost modal widget.
        @return the popped widget, or NOTHING if no modals
        @since ncurses 2.0
    */
    *NcursesUi::Widget popModal() {
        if (!modal_stack.size()) {
            return NOTHING;
        }
        NcursesUi::Widget top = modal_stack[modal_stack.size() - 1];
        if (modal_stack.size() == 1) {
            modal_stack = ();
        } else {
            modal_stack = modal_stack[0 .. modal_stack.size() - 2];
        }
        return top;
    }

    /** Returns the topmost modal widget.
        @return the top modal or NOTHING
        @since ncurses 2.0
    */
    *NcursesUi::Widget topModal() {
        if (!modal_stack.size()) {
            return NOTHING;
        }
        return modal_stack[modal_stack.size() - 1];
    }

    /** Returns whether there are active modals.
        @since ncurses 2.0
    */
    bool hasModal() {
        return modal_stack.size() > 0;
    }

    /** Returns the modal stack (for drawing).
        @return list of modal widgets, bottom-to-top
        @since ncurses 2.0
    */
    list<NcursesUi::Widget> getModalStack() {
        return modal_stack;
    }

    /** Sets a global key handler for app-wide shortcuts.

        The handler is called before normal dispatch. If it returns
        handled=True, normal dispatch is skipped.

        @param handler callback that receives InputEvent and returns EventResult
        @since ncurses 2.0
    */
    nothing setGlobalKeyHandler(*code<hash<NcursesUi::EventResult>(hash<Ncurses::InputEvent>)> handler) {
        global_key_handler = handler;
    }

    /** Dispatches an event through the widget tree.

        Dispatch order:
        1. Global key handler (if set)
        2. Modal widget (if active, gets ALL events)
        3. Focus manager (Tab/Shift+Tab)
        4. Mouse hit-test from topmost widget
        5. Keyboard to focused widget via tree

        @param root the root widget of the tree
        @param ev the input event
        @return EventResult indicating whether the event was handled
        @since ncurses 2.0
    */
    hash<NcursesUi::EventResult> dispatch(NcursesUi::Widget root, hash<Ncurses::InputEvent> ev) {
        # 1. try global key handler first (for all event types except Resize)
        if (global_key_handler && ev.type != Ncurses::InputType::Resize) {
            hash<NcursesUi::EventResult> result = global_key_handler(ev);
            if (result.handled) {
                return result;
            }
        }

        # 2. modal widget gets ALL events
        *NcursesUi::Widget modal = topModal();
        if (modal) {
            hash<NcursesUi::EventResult> result = modal.handleEvent(ev);
            if (result.handled) {
                return result;
            }
            # for mouse events, fall through to normal dispatch if modal didn't handle it
            # this allows clicks outside a dropdown to reach the menu bar
            if (ev.type == Ncurses::InputType::Mouse) {
                # continue to step 3 (focus traversal) and beyond
            } else {
                # keyboard/char/alt events stay captured by the modal
                return result;
            }
        }

        # 3. focus traversal
        if (focus_mgr.handleFocusEvent(root, ev)) {
            return <NcursesUi::EventResult>{"handled": True};
        }

        # 4. mouse hit-test
        if (ev.type == Ncurses::InputType::Mouse) {
            int mx = ev.mouse.x;
            int my_row = ev.mouse.y;
            *NcursesUi::Widget hit = hitTestTree(root, my_row, mx);
            if (hit) {
                hash<NcursesUi::EventResult> result = hit.processEvent(ev);
                if (result.handled) {
                    return result;
                }
            }
        }

        # 5. keyboard to focused widget via tree
        return root.handleEvent(ev);
    }

    /** Performs depth-first reverse-order hit-test on the widget tree.

        Returns the deepest, topmost widget that contains the point.

        @param w the widget to test
        @param py the row coordinate
        @param px the column coordinate
        @return the hit widget or NOTHING
        @since ncurses 2.0
    */
    private *NcursesUi::Widget hitTestTree(NcursesUi::Widget w, int py, int px) {
        if (!w.isVisible() || !w.hitTest(py, px)) {
            return NOTHING;
        }
        # check children in reverse order (topmost first)
        list<NcursesUi::Widget> kids = w.getChildren();
        for (int i = kids.size() - 1; i >= 0; --i) {
            *NcursesUi::Widget hit = hitTestTree(kids[i], py, px);
            if (hit) {
                return hit;
            }
        }
        return w;
    }
}
