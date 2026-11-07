#! @file ProgressWidget.qc Determinate and indeterminate operation presentation
/* Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT */
public namespace NcursesUi {
/** Scrollable progress/status control with guarded start, cancel and retry hooks.
    Enter starts or retries; C/Escape cancels pending/running work. Mouse activation
    on the final action row performs the same operation. Completed states display a
    receipt label and never repeat an action unless the model is explicitly reset.
    Unknown totals render an explicit working status; no timer or busy polling is required.
*/
public class ProgressWidget inherits NcursesUi::ScrollableWidget {
    private {
        NcursesUi::ActionModel model;
        NcursesUi::LineListContent lines();
        *code<nothing(hash<NcursesUi::ActionRequest>)> starter;
        *code<nothing(hash<NcursesUi::ActionRequest>)> canceller;
        int observed_revision = -1;
        int rendered_columns = -1;
        int action_line = -1;
        bool rendered_available = True;
        bool rendered_focus = False;
    }
    /** Binds an operation model. @param operation UI-thread-owned lifecycle */
    constructor(NcursesUi::ActionModel operation) { model = operation; lines.setWordWrap(True); setContent(lines); }
    /** Returns the operation model. @return shared model */
    NcursesUi::ActionModel getModel() { return model; }
    /** Sets the start/retry integration. @param callback receives the new attempt token */
    nothing setOnStart(*code<nothing(hash<NcursesUi::ActionRequest>)> callback) { starter = callback; observed_revision = -1; markDirty(); }
    /** Sets optional cancellation notification. @param callback receives the cancelled attempt token */
    nothing setOnCancel(*code<nothing(hash<NcursesUi::ActionRequest>)> callback) { canceller = callback; }
    /** Starts/retries once when available. @return True when dispatched; callback failures propagate after model failure */
    bool start() {
        if (!isAvailable() || !starter || model.getState() == NcursesUi::ActionState::Running || model.getState() == NcursesUi::ActionState::Completed) { return False; }
        on_exit markDirty(); model.dispatch(starter); return True;
    }
    /** Cancels the current attempt before notifying the application. @return True for a new cancellation */
    bool cancel() {
        if (!isAvailable()) { return False; } *hash<NcursesUi::ActionRequest> token = model.cancel(); if (!token) { return False; }
        on_exit markDirty(); if (canceller) { canceller(token); } return True;
    }
    /** Returns the rendered textual status. @return styled-free lines */
    list<string> getStatusLines() { sync(); return map NcursesUi::TerminalText::plainAnsi($1), lines.getLines(); }
    /** Includes model changes in invalidation. @return needs repaint */
    bool needsOwnDraw() { return observed_revision != model.getRevision() || rendered_available != isAvailable() || rendered_focus != hasFocus() || ScrollableWidget::needsOwnDraw(); }
    /** Includes descendant/model changes. @return needs repaint */
    bool isDirty() { return needsOwnDraw() || ScrollableWidget::isDirty(); }
    /** Acknowledges model changes after updating text while clipped. */
    nothing onDrawClipped() { sync(); ScrollableWidget::onDrawClipped(); }
    /** Renders progress against actual target bounds. @param window target */
    nothing draw(Ncurses::Window window) { prepareDrawViewport(window); sync(); ScrollableWidget::draw(window); }
    /** Handles operation activation/cancellation and read-only scrolling. @param event input @return result */
    hash<NcursesUi::EventResult> processEvent(hash<Ncurses::InputEvent> event) {
        if (!isAvailable()) { return <NcursesUi::EventResult>{}; } sync();
        bool activate = (event.type == Ncurses::InputType::Char && (event.ch == "\n" || event.ch == "\r")) || (event.type == Ncurses::InputType::Key && event.name == "KEY_ENTER");
        bool cancel_action = event.type == Ncurses::InputType::Char && (event.ch == "c" || event.ch == "C" || event.ch == "\x1b");
        if (event.type == Ncurses::InputType::Mouse && event.mouse && (event.mouse.button_state & (Ncurses::BUTTON1_CLICKED | Ncurses::BUTTON1_PRESSED))) {
            hash<NcursesUi::Rect> view = getViewportRect();
            if (NcursesUi::Geometry::rectContains(view, event.mouse.y, event.mouse.x)) {
                hash<Ncurses::Position> source = lines.visualToSource(event.mouse.y - view.y + getScrollY(), event.mouse.x - view.x + getScrollX());
                if (source.y == action_line) { cancel_action = model.getState() == NcursesUi::ActionState::Running; activate = !cancel_action; }
            }
        }
        if (activate) { return <NcursesUi::EventResult>{"handled": True, "action": start() ? "start" : NOTHING}; }
        if (cancel_action) { return <NcursesUi::EventResult>{"handled": True, "action": cancel() ? "cancel" : NOTHING}; }
        return ScrollableWidget::processEvent(event);
    }
    private nothing sync() {
        int columns = max(1, getViewportRect().cols);
        bool available = isAvailable(); bool focused = hasFocus();
        if (observed_revision == model.getRevision() && rendered_columns == columns && rendered_available == available && rendered_focus == focused) { return; }
        int state = model.getState();
        string state_style = ("\e[2m", "\e[1;36m", "\e[1;33m", "\e[1;31m", "\e[1;32m")[state];
        list<string> rows = (styled(model.getLabel(), "\e[1;36m"), styled(("Pending", "Running", "Cancelled", "Failed", "Completed")[state], state_style));
        *float total = model.getTotal(); *float done = model.getCompleted();
        if (exists total && exists done) {
            rows += bar(columns, done, total, state_style);
            rows += styled(sprintf("%d%% (%g / %g)", int(done / total * 100.0), done, total), "\e[1m");
        } else if (state == NcursesUi::ActionState::Running) { rows += exists done ? sprintf("Working: %g processed", done) : "Working…"; }
        if (model.getMessage() != "") { rows += split("\n", model.getMessage(), False, True); }
        if (exists model.getError()) { rows += split("\n", styled("Error: " + model.getError(), "\e[1;31m"), False, True); }
        if (model.getStarted()) { rows += styled("Started: " + format_date("YYYY-MM-DD HH:mm:SS", model.getStarted()), "\e[2m"); }
        if (model.getFinished()) { rows += styled("Finished: " + format_date("YYYY-MM-DD HH:mm:SS", model.getFinished()), "\e[2m"); }
        action_line = -1;
        if (state == NcursesUi::ActionState::Running) { action_line = rows.size(); rows += "[C / Escape: Cancel]"; }
        else if (state != NcursesUi::ActionState::Completed && starter) { action_line = rows.size(); rows += state == NcursesUi::ActionState::Pending ? "[Enter: Start]" : "[Enter: Retry]"; }
        if (action_line >= 0) { rows[action_line] = styled(rows[action_line], focused ? "\e[1;7;36m" : "\e[1;36m"); }
        if (!available) { rows = map styled(NcursesUi::TerminalText::plainAnsi($1), "\e[2m"), rows; }
        list<string> before = lines.getLines();
        if (before.size() != rows.size()) { lines.setLines(rows); }
        else { for (int i = 0; i < rows.size(); ++i) { if (before[i] != rows[i]) { lines.setLine(i, rows[i]); } } }
        int final_columns = max(1, getViewportRect().cols);
        if (exists total && exists done && final_columns != columns) {
            string value = bar(final_columns, done, total, state_style);
            lines.setLine(2, available ? value : styled(NcursesUi::TerminalText::plainAnsi(value), "\e[2m"));
        }
        observed_revision = model.getRevision(); rendered_columns = final_columns; rendered_available = available; rendered_focus = focused;
    }
    private static string styled(string text, string style) {
        return style + join("\e[0m\n" + style, split("\n", text, False, True)) + "\e[0m";
    }
    private static string bar(int columns, float done, float total, string style) {
        int width = max(0, min(40, columns - 2)); int filled = min(width, int(done / total * width));
        return columns < 2 ? styled("#", style) : styled("[", "\e[2m") + styled(strmul("#", filled), style)
            + styled(strmul("-", width - filled) + "]", "\e[2m");
    }
}
} # namespace NcursesUi
