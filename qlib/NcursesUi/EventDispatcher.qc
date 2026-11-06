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

public namespace NcursesUi {
/** Event dispatch with focus scopes, modal capture, and popup dismissal.
    Explicit global handlers run first. Tab is offered to the active widget
    (for controls with internal traversal), then cycles within the active scope.
    Mouse activation focuses the eligible hit target; unhandled events bubble
    only along its ancestor path. A modal captures all remaining input. An
    explicit popup may dismiss on an outside primary click and pass that click
    to the underlying scope.
    @since ncurses 1.0
*/
public class EventDispatcher {
    private {
        NcursesUi::FocusManager focus_mgr();
        list<hash<NcursesUi::ModalFocusState>> modal_stack = ();
        bool changing_scope = False;
        *code<hash<NcursesUi::EventResult>(hash<Ncurses::InputEvent>)> global_key_handler;
    }

    /** Returns the focus manager.
        @return focus manager
        @since ncurses 1.0
    */
    NcursesUi::FocusManager getFocusManager() {
        return focus_mgr;
    }

    /** Updates the application scope, including while a modal is active.
        Replacing the root invalidates a suspended focus outside the new tree.
        @param root current application root
        @since ncurses 1.0
    */
    nothing setRootScope(NcursesUi::Widget root) {
        if (changing_scope || focus_mgr.isChangingFocus()) {
            throw "MODAL-SCOPE-ERROR", "A focus callback cannot replace the root scope";
        }
        if (modal_stack) {
            modal_stack[0].previous_scope = root;
            *NcursesUi::Widget previous = modal_stack[0].previous_focus;
            if (previous && !root.containsWidget(previous)) {
                modal_stack[0].previous_focus = NOTHING;
            }
        } else {
            focus_mgr.reconcile(root);
        }
    }

    /** Pushes a modal and moves focus into its subtree.
        Existing focus is suspended and restored on pop if still eligible.
        @param w visible, enabled modal root
        @throw MODAL-SCOPE-ERROR for an unavailable or already active modal
        @since ncurses 1.0
    */
    nothing pushModal(NcursesUi::Widget w) {
        pushScope(w, False);
    }

    /** Pushes a popup that dismisses on an outside primary click.
        The popup receives the outside event first so it can run its close
        callback. If still active and unhandled, the dispatcher pops it. The
        unhandled click then reaches the underlying scope.
        @param w visible, enabled popup root
        @throw MODAL-SCOPE-ERROR for an unavailable or already active popup
        @since ncurses 1.0
    */
    nothing pushPopup(NcursesUi::Widget w) {
        pushScope(w, True);
    }

    private nothing pushScope(NcursesUi::Widget w, bool popup) {
        if (changing_scope || focus_mgr.isChangingFocus()) {
            throw "MODAL-SCOPE-ERROR", "A focus callback cannot change the modal stack";
        }
        changing_scope = True;
        on_exit changing_scope = False;
        if (!w.isAvailable()) {
            throw "MODAL-SCOPE-ERROR", "A modal scope must be visible and enabled";
        }
        foreach hash<NcursesUi::ModalFocusState> entry in (modal_stack) {
            if (entry.widget == w) {
                throw "MODAL-SCOPE-ERROR", "The widget is already an active modal scope";
            }
        }
        hash<NcursesUi::ModalFocusState> entry = <NcursesUi::ModalFocusState>{
            "widget": w, "previous_focus": focus_mgr.getCurrentFocus(),
            "previous_scope": focus_mgr.getScope(), "popup": popup};
        modal_stack += entry;
        try {
            focus_mgr.setScope(w);
            *NcursesUi::Widget focused = w.findFocused();
            if (focused) {
                focus_mgr.setFocus(focused);
            } else {
                focus_mgr.moveFocus(w, NcursesUi::FocusDirection::Next);
            }
        } catch (hash<ExceptionInfo> ex) {
            removeTop();
            try {
                restoreFocus(entry);
            } catch (hash<ExceptionInfo> restore_error) {
                # Both focus transitions clear their pointers before callbacks;
                # preserve the original failure without leaving a stale owner.
            }
            rethrow;
        }
    }

    /** Pops the top scope and restores the prior valid focus.
        No unrelated replacement control receives focus when the old target was
        hidden, disabled, detached, or reparented out of its original scope.
        @return popped widget, or NOTHING for an empty stack
        @since ncurses 1.0
    */
    *NcursesUi::Widget popModal() {
        if (changing_scope || focus_mgr.isChangingFocus()) {
            throw "MODAL-SCOPE-ERROR", "A focus callback cannot change the modal stack";
        }
        changing_scope = True;
        on_exit changing_scope = False;
        if (!modal_stack) {
            return NOTHING;
        }
        hash<NcursesUi::ModalFocusState> entry = modal_stack[modal_stack.size() - 1];
        removeTop();
        restoreFocus(entry);
        return entry.widget;
    }

    private nothing removeTop() {
        modal_stack = modal_stack.size() == 1 ? () : modal_stack[0 .. modal_stack.size() - 2];
    }

    private nothing restoreFocus(hash<NcursesUi::ModalFocusState> entry) {
        focus_mgr.setScope(entry.previous_scope);
        focus_mgr.setFocus(entry.previous_focus);
    }

    /** Returns the topmost modal or popup.
        @return top widget or NOTHING
        @since ncurses 1.0
    */
    *NcursesUi::Widget topModal() {
        return modal_stack ? modal_stack[modal_stack.size() - 1].widget : NOTHING;
    }

    /** Returns whether a modal or popup captures input.
        @return True if the stack is nonempty
        @since ncurses 1.0
    */
    bool hasModal() {
        return modal_stack.size() > 0;
    }

    /** Returns modal widgets in drawing order, bottom to top.
        @return active widgets
        @since ncurses 1.0
    */
    list<NcursesUi::Widget> getModalStack() {
        return map $1.widget, modal_stack;
    }

    /** Registers an explicit application-wide override, including during modals.
        @param handler called first for all non-resize events; return handled
            True to prevent widget dispatch, or NOTHING to clear the handler
        @since ncurses 1.0
    */
    nothing setGlobalKeyHandler(*code<hash<NcursesUi::EventResult>(hash<Ncurses::InputEvent>)> handler) {
        global_key_handler = handler;
    }

    /** Dispatches an event within the active modal or root scope.
        @param root application root
        @param ev input event
        @return handling result
        @since ncurses 1.0
    */
    hash<NcursesUi::EventResult> dispatch(NcursesUi::Widget root, hash<Ncurses::InputEvent> ev) {
        if (global_key_handler && ev.type != Ncurses::InputType::Resize) {
            hash<NcursesUi::EventResult> result = global_key_handler(ev);
            if (result.handled) {
                return result;
            }
        }
        setRootScope(root);
        NcursesUi::Widget scope = topModal() ?? root;
        if (hasModal()) {
            focus_mgr.reconcile(scope);
        }
        if (ev.type == Ncurses::InputType::Mouse) {
            if (!ev.mouse) {
                return <NcursesUi::EventResult>{"handled": False};
            }
            if (hasModal() && !scope.hitTest(ev.mouse.y, ev.mouse.x)) {
                bool popup = modal_stack[modal_stack.size() - 1].popup;
                hash<NcursesUi::EventResult> result = scope.isAvailable()
                    ? scope.processEvent(ev) : <NcursesUi::EventResult>{"handled": False};
                if (result.handled || !popup || !primaryClick(ev)) {
                    return result;
                }
                if (topModal() == scope) {
                    popModal();
                }
                scope = topModal() ?? root;
                focus_mgr.reconcile(scope);
            }
            *NcursesUi::Widget hit = hitTestTree(scope, ev.mouse.y, ev.mouse.x);
            if (!hit || !hit.isAvailable()) {
                return <NcursesUi::EventResult>{"handled": False};
            }
            if (primaryClick(ev)) {
                *NcursesUi::Widget target = hit;
                while (target && scope.containsWidget(target)) {
                    if (target.isFocusable()) {
                        focus_mgr.setFocus(target);
                        break;
                    }
                    if (target == scope) {
                        break;
                    }
                    target = target.getParent();
                }
            }
            return scope.dispatchTo(hit, ev);
        }
        hash<NcursesUi::EventResult> result = scope.dispatchTo(focus_mgr.getCurrentFocus() ?? scope, ev);
        if (!result.handled && scope == (topModal() ?? root)
                && focus_mgr.handleFocusEvent(scope, ev)) {
            return <NcursesUi::EventResult>{"handled": True};
        }
        return result;
    }

    private static bool primaryClick(hash<Ncurses::InputEvent> ev) {
        return (ev.mouse.button_state & (Ncurses::BUTTON1_PRESSED | Ncurses::BUTTON1_CLICKED
            | Ncurses::BUTTON1_DOUBLE_CLICKED | Ncurses::BUTTON1_TRIPLE_CLICKED)) != 0;
    }

    private *NcursesUi::Widget hitTestTree(NcursesUi::Widget w, int py, int px) {
        if (!w.isVisible() || !w.hitTest(py, px)) {
            return NOTHING;
        }
        # Disabled visible controls still cover widgets below them.
        if (!w.isAvailable()) {
            return w;
        }
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

} # namespace NcursesUi
