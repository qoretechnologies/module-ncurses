#! @file AttachmentWidget.qc Application-owned attachment summaries and media fallbacks
/* Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT */
public namespace NcursesUi {
#! Attachment metadata; previews are explicit application-provided text, never implicit file reads.
public hashdecl AttachmentInfo inherits NcursesUi::FileSelectionEntry {
    string description = ""; *string text_preview; *NcursesUi::TextChart chart;
}
hashdecl AttachmentActionSpan {
    int start;
    int end;
    int operation;
}
/** Scrollable attachment details with explicit open/save/export actions.
    Unsupported media remains understandable through its name, path, type, size and
    description. Optional text/chart previews are supplied by the application; no
    media decoder, network request or external application is launched implicitly.
    Enter/O opens, S saves, E exports; primary clicks on displayed action labels
    perform the same operations, including after wrapping and scrolling.
    Callbacks return False for cancellation or
    throw on failure; completed actions require reset() before another dispatch.
*/
public class AttachmentWidget inherits NcursesUi::ScrollableWidget {
    private {
        hash<NcursesUi::AttachmentInfo> attachment;
        NcursesUi::FileSelectionModel model();
        NcursesUi::LineListContent lines();
        int observed_revision = -1; int rendered_columns = -1;
        int action_line = -1;
        list<hash<NcursesUi::AttachmentActionSpan>> action_spans = ();
    }
    /** Creates an attachment surface. @param value validated metadata */
    constructor(hash<NcursesUi::AttachmentInfo> value) { lines.setWordWrap(True); setContent(lines); setAttachment(value); }
    /** Replaces metadata atomically; active/completed operations require reset first.
        @param value attachment metadata @throw FILE-SELECTION-DATA for invalid metadata */
    nothing setAttachment(hash<NcursesUi::AttachmentInfo> value) {
        model.setFiles((value,)); attachment = value;
        if (!model.isSelected(value.id)) { model.toggle(value.id); }
        rendered_columns = -1; setScrollY(0); markDirty();
    }
    /** Returns the exact metadata, including unmodified application-provided text. @return immutable metadata */
    hash<NcursesUi::AttachmentInfo> getAttachment() { return attachment; }
    /** Sets an explicit application operation. @param operation FileOperation @param callback True success, False cancelled */
    nothing setHandler(int operation, *code<bool(hash<NcursesUi::AttachmentInfo>)> callback) {
        model.setHandler(operation, callback ? bool sub (list<hash<NcursesUi::FileSelectionEntry>> selected) { return callback(attachment); } : NOTHING); markDirty();
    }
    /** Dispatches a configured operation once. @param operation FileOperation @return completed; failures propagate */
    bool activate(int operation) { if (!isAvailable()) { return False; } on_exit markDirty(); return model.dispatch(operation); }
    /** Permits another operation while preserving attachment metadata. */
    nothing reset() { model.reset(); markDirty(); }
    /** Returns operation lifecycle state. @return ActionState */
    int getState() { return model.getState(); }
    /** Returns validation/callback error text. @return error or NOTHING */
    *string getError() { return model.getError(); }
    /** Returns the safe textual presentation. @return normalized summary and preview */
    list<string> getSummaryLines() { sync(); return lines.getLines(); }
    /** Includes operation revisions. @return needs paint */
    bool needsOwnDraw() { return observed_revision != model.getRevision() || ScrollableWidget::needsOwnDraw(); }
    /** Includes child invalidation. @return needs paint */
    bool isDirty() { return needsOwnDraw() || ScrollableWidget::isDirty(); }
    /** Reconciles hidden metadata. */
    nothing onDrawClipped() { sync(); ScrollableWidget::onDrawClipped(); }
    /** Paints against actual clipped bounds. @param window target */
    nothing draw(Ncurses::Window window) { prepareDrawViewport(window); sync(); ScrollableWidget::draw(window); }
    /** Handles explicit operations and scrolling. @param event input @return handled/action */
    hash<NcursesUi::EventResult> processEvent(hash<Ncurses::InputEvent> event) {
        if (!isAvailable()) { return <NcursesUi::EventResult>{}; } sync();
        *int operation;
        if ((event.type == Ncurses::InputType::Key && event.name == "KEY_ENTER") || (event.type == Ncurses::InputType::Char && (event.ch == "\n" || event.ch == "\r" || event.ch == "o" || event.ch == "O"))) { operation = NcursesUi::FileOperation::Open; }
        else if (event.type == Ncurses::InputType::Char && (event.ch == "s" || event.ch == "S")) { operation = NcursesUi::FileOperation::Save; }
        else if (event.type == Ncurses::InputType::Char && (event.ch == "e" || event.ch == "E")) { operation = NcursesUi::FileOperation::Export; }
        else if (event.type == Ncurses::InputType::Mouse && event.mouse
                && (event.mouse.button_state & (Ncurses::BUTTON1_CLICKED | Ncurses::BUTTON1_PRESSED))) {
            hash<NcursesUi::Rect> view = getViewportRect();
            if (NcursesUi::Geometry::rectContains(view, event.mouse.y, event.mouse.x)) {
                int row = event.mouse.y - view.y + getScrollY(); int col = event.mouse.x - view.x + getScrollX();
                hash<Ncurses::Position> source = lines.visualToSource(row, col);
                hash<Ncurses::Position> painted = lines.sourceToVisual(source.y, source.x);
                if (source.y == action_line && painted.y == row && painted.x == col) {
                    foreach hash<NcursesUi::AttachmentActionSpan> span in (action_spans) {
                        if (source.x >= span.start && source.x < span.end) { operation = span.operation; break; }
                    }
                }
            }
        }
        if (exists operation && model.hasHandler(operation)) { return <NcursesUi::EventResult>{"handled": True, "action": activate(operation) ? "attachment" : NOTHING}; }
        return ScrollableWidget::processEvent(event);
    }
    private nothing sync() {
        int columns = max(0, getViewportRect().cols); if (observed_revision == model.getRevision() && rendered_columns == columns) { return; }
        list<string> rows = (attachment.name, "Path: " + attachment.path, "Type: " + attachment.type,
            exists attachment.size ? sprintf("Size: %d bytes", attachment.size) : "Size: unknown");
        if (attachment.description != "") { rows += split("\n", attachment.description, False, True); }
        if (exists attachment.error) { rows += "Unavailable: " + attachment.error; }
        else if (!attachment.enabled) { rows += "Unavailable"; }
        if (exists attachment.text_preview) { rows += "Text preview:"; rows += split("\n", attachment.text_preview, False, True); }
        int chart_line = -1;
        if (attachment.chart) { rows += attachment.chart.getSummary(); chart_line = rows.size(); rows += attachment.chart.sparkline(columns); rows += "Scale: low to high; ? = missing sample"; }
        if (!exists attachment.text_preview && !attachment.chart) { rows += "No terminal preview; use an available Open or Export action."; }
        list<string> actions = ();
        list<hash<NcursesUi::AttachmentActionSpan>> spans = (); int offset = 0;
        foreach int operation in ((NcursesUi::FileOperation::Open, NcursesUi::FileOperation::Save, NcursesUi::FileOperation::Export)) {
            if (!model.hasHandler(operation)) { continue; }
            string label = operation == NcursesUi::FileOperation::Open ? "Enter/O: Open" : operation == NcursesUi::FileOperation::Save ? "S: Save" : "E: Export";
            spans += <NcursesUi::AttachmentActionSpan>{"start": offset, "end": offset + label.size(), "operation": operation};
            actions += label; offset += label.size() + 2;
        }
        int action_row = rows.size();
        if (model.getState() == NcursesUi::ActionState::Completed) { rows += "Completed"; }
        else { rows += actions ? join("  ", actions) : "No application actions configured"; }
        if (model.getState() == NcursesUi::ActionState::Cancelled) { rows += "Cancelled; attachment retained"; }
        if (exists model.getError()) { rows += "Error: " + model.getError(); }
        int normalized_action = -1;
        list<string> normalized = ();
        for (int i = 0; i < rows.size(); ++i) {
            if (i == action_row) { normalized_action = normalized.size(); }
            normalized += split("\n", NcursesUi::TextEditorWidget::normalizePaste(rows[i]), False, True);
        }
        lines.setLines(normalized);
        # Normalization may expand a row, so reconstruct only when width changed.
        int final_columns = max(0, getViewportRect().cols);
        if (chart_line >= 0 && final_columns != columns) {
            rows[chart_line] = attachment.chart.sparkline(final_columns); normalized = ();
            foreach string row in (rows) { normalized += split("\n", NcursesUi::TextEditorWidget::normalizePaste(row), False, True); } lines.setLines(normalized);
        }
        observed_revision = model.getRevision(); rendered_columns = final_columns;
        action_line = normalized_action;
        action_spans = model.getState() == NcursesUi::ActionState::Completed ? () : spans;
    }
}
} # namespace NcursesUi
