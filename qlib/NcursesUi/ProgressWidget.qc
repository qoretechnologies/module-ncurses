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
    list<string> getStatusLines() { sync(); return lines.getLines(); }
    /** Includes model changes in invalidation. @return needs repaint */
    bool needsOwnDraw() { return observed_revision != model.getRevision() || ScrollableWidget::needsOwnDraw(); }
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
        if (observed_revision == model.getRevision() && rendered_columns == columns) { return; }
        int state = model.getState(); list<string> rows = (model.getLabel(), ("Pending", "Running", "Cancelled", "Failed", "Completed")[state]);
        *float total = model.getTotal(); *float done = model.getCompleted();
        if (exists total && exists done) {
            int width = max(0, min(40, columns - 2)); int filled = min(width, int(done / total * width));
            rows += columns < 2 ? "#" : "[" + strmul("#", filled) + strmul("-", width - filled) + "]";
            rows += sprintf("%d%% (%g / %g)", int(done / total * 100.0), done, total);
        } else if (state == NcursesUi::ActionState::Running) { rows += exists done ? sprintf("Working: %g processed", done) : "Working…"; }
        if (model.getMessage() != "") { rows += split("\n", model.getMessage(), False, True); }
        if (exists model.getError()) { rows += split("\n", "Error: " + model.getError(), False, True); }
        if (model.getStarted()) { rows += "Started: " + format_date("YYYY-MM-DD HH:mm:SS", model.getStarted()); }
        if (model.getFinished()) { rows += "Finished: " + format_date("YYYY-MM-DD HH:mm:SS", model.getFinished()); }
        action_line = -1;
        if (state == NcursesUi::ActionState::Running) { action_line = rows.size(); rows += "[C / Escape: Cancel]"; }
        else if (state != NcursesUi::ActionState::Completed && starter) { action_line = rows.size(); rows += state == NcursesUi::ActionState::Pending ? "[Enter: Start]" : "[Enter: Retry]"; }
        list<string> before = lines.getLines();
        if (before.size() != rows.size()) { lines.setLines(rows); }
        else { for (int i = 0; i < rows.size(); ++i) { if (before[i] != rows[i]) { lines.setLine(i, rows[i]); } } }
        int final_columns = max(1, getViewportRect().cols);
        if (exists total && exists done && final_columns != columns) {
            int width = max(0, min(40, final_columns - 2)); int filled = min(width, int(done / total * width));
            lines.setLine(2, final_columns < 2 ? "#" : "[" + strmul("#", filled) + strmul("-", width - filled) + "]");
        }
        observed_revision = model.getRevision(); rendered_columns = final_columns;
    }
}
} # namespace NcursesUi
