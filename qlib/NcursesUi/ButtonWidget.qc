#! @file ButtonWidget.qc Keyboard and mouse action button
/* Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT */
public namespace NcursesUi {
/** Action button with reentrancy protection and optional one-shot completion.
    A failed callback preserves an enabled retry action. Callback exceptions propagate.
*/
public class ButtonWidget inherits NcursesUi::Widget {
    private { string label; string id; *code<nothing(string)> callback; bool busy = False; bool completed = False; bool single_use = False; bool pressed = False; *hash<NcursesUi::Rect> draw_bounds; }
    /** Creates a button. @param text label @param action stable identifier independent of label */
    constructor(string text, string action = "activate") { label = text; id = action; setFocusable(True); }
    /** Sets an action handler. @param handler receives the stable action identifier */
    nothing setOnActivate(*code<nothing(string)> handler) { callback = handler; }
    /** Sets the label. @param text visible label */
    nothing setLabel(string text) { label = text; markDirty(); }
    /** Enables one-shot behavior. @param value successful activation disables further activation until reset */
    nothing setSingleUse(bool value) { single_use = value; markDirty(); }
    /** Resets completed state. @throw BUTTON-BUSY-ERROR during activation */
    nothing reset() { if (busy) { throw "BUTTON-BUSY-ERROR", "Cannot reset an active button"; } completed = False; markDirty(); }
    /** Returns whether a callback is active. @return busy state */
    bool isBusy() { return busy; }
    /** Returns successful one-shot completion. @return completed state */
    bool isCompleted() { return completed; }
    /** Returns whether a primary mouse press is held over this button. @return pressed appearance */
    bool isPressed() { return pressed; }
    /** Cancels a held press when focus or mouse capture is lost. */
    nothing onMouseCaptureLost() { if (pressed) { pressed = False; markDirty(); } }
    /** Cancels a held press when keyboard focus leaves. */
    nothing onFocusOut() { onMouseCaptureLost(); }
    /** Invokes the handler once when available. @return True when an action ran */
    bool activate() {
        if (!isAvailable() || busy || completed || !callback) { return False; }
        busy = True; markDirty(); on_exit { busy = False; markDirty(); }
        callback(id); if (single_use) { completed = True; } return True;
    }
    /** Returns button dimensions. @return one row and the complete label width */
    hash<NcursesUi::Rect> getPreferredSize() { return NcursesUi::Geometry::makeRect(0, 0, 1, NcursesUi::TerminalText::displayWidth(label) + 4); }
    /** Draws an appropriately styled button. @param window output window */
    nothing draw(Ncurses::Window window) {
        hash<Ncurses::Position> origin = window.position(); hash<Ncurses::Size> size = window.size();
        draw_bounds = NcursesUi::Geometry::makeRect(origin.y, origin.x, size.rows, size.cols);
        hash<NcursesUi::Rect> rect = drawContentRect(window);
        string text = (pressed ? "< " : "[ ") + (busy ? "Working…" : label) + (pressed ? " >" : " ]");
        int attrs = !isAvailable() || completed ? Ncurses::Attr::Dim : (hasFocus() ? Ncurses::Attr::Reverse : Ncurses::Attr::Bold);
        if (pressed) { attrs |= Ncurses::Attr::Bold | Ncurses::Attr::Underline; }
        hash<auto> style = {"attrs": attrs};
        if (isAvailable() && !completed) { style.fg = Ncurses::Color::Cyan; }
        window.drawTextClipped(rect.y, rect.x, NcursesUi::TerminalText::clipRight(text, rect.cols), style);
    }
    /** Clears the mouse target when the surface is fully clipped. */
    nothing onDrawClipped() { onMouseCaptureLost(); draw_bounds = NcursesUi::Geometry::makeRect(0, 0, 0, 0); Widget::onDrawClipped(); }
    private bool actionHit(int y, int x) {
        return textActionHit("[ " + (busy ? "Working…" : label) + " ]", draw_bounds, y, x);
    }
    /** Handles Enter, Space and primary clicks. A mouse press arms the button;
        releasing inside activates, while releasing outside cancels. Synthesized
        clicks activate immediately. @param event input @return handled/action result
    */
    hash<NcursesUi::EventResult> processEvent(hash<Ncurses::InputEvent> event) {
        if (event.type == Ncurses::InputType::Mouse && event.mouse) {
            bool inside = actionHit(event.mouse.y, event.mouse.x);
            if (event.mouse.button_state & Ncurses::BUTTON1_RELEASED) {
                bool activate_now = pressed && inside; onMouseCaptureLost();
                return <NcursesUi::EventResult>{"handled": activate_now,
                    "action": activate_now && activate() ? id : NOTHING};
            }
            if (event.mouse.button_state & Ncurses::BUTTON1_PRESSED) {
                if (!inside || !isAvailable() || busy || completed || !callback) { return <NcursesUi::EventResult>{}; }
                pressed = True; markDirty();
                return <NcursesUi::EventResult>{"handled": True, "mouse_capture": self};
            }
        }
        bool hit = event.type == Ncurses::InputType::Char && (event.ch == "\n" || event.ch == "\r" || event.ch == " ");
        hit = hit || (event.type == Ncurses::InputType::Key && event.name == "KEY_ENTER");
        hit = hit || (event.type == Ncurses::InputType::Mouse && event.mouse && actionHit(event.mouse.y, event.mouse.x)
            && (event.mouse.button_state & Ncurses::BUTTON1_CLICKED));
        if (!hit) { return <NcursesUi::EventResult>{}; }
        return <NcursesUi::EventResult>{"handled": True, "action": activate() ? id : NOTHING};
    }
}
} # namespace NcursesUi
