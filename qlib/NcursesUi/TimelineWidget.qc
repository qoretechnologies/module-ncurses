#! @file TimelineWidget.qc Timestamped operation history with retained source identities
/* Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT */
public namespace NcursesUi {
#! One immutable event snapshot. State transitions are represented by subsequent events.
public hashdecl TimelineEvent {
    string id;
    *date timestamp;
    string title;
    list<string> details = ();
    int state = NcursesUi::ActionState::Completed;
}
class TimelineRecord {
    public { hash<NcursesUi::TimelineEvent> event; int block; int first_id; int last_id; bool collapsed = False; }
    constructor(hash<NcursesUi::TimelineEvent> value, int block, int first_id, int last_id) {
        event = value; event.details = (); self.block = block; self.first_id = first_id; self.last_id = last_id;
    }
}
/** Searchable timestamped history with expandable details and stable event identities.
    Up/Down select events; Enter/Space toggles details; A invokes the optional
    application activation callback. Page and wheel navigation preserve transcript
    reading/follow behavior. Combine with ProgressWidget for cancel/retry and
    DescribedChoiceWidget for guarded review actions; history records remain immutable.
    The inherited content provider is read-only. Use appendEvent() for mutations.
*/
public class TimelineWidget inherits NcursesUi::TranscriptWidget {
    private {
        hash<string, NcursesUi::TimelineRecord> events = {};
        hash<string, string> block_events = {};
        hash<string, int> indices = {};
        list<string> order = ();
        int first = 0;
        *int event_retained_first;
        *string selected;
        *code<nothing(*hash<NcursesUi::TimelineEvent>)> on_select;
        *code<nothing(hash<NcursesUi::TimelineEvent>)> on_activate;
    }
    /** Appends a validated history snapshot. @param event unique retained ID, title, details and state
        @return transcript block ID @throw TIMELINE-EVENT-ERROR for invalid metadata or a duplicate retained ID */
    int appendEvent(hash<NcursesUi::TimelineEvent> event) {
        pruneEvents();
        if (event.id == "" || event.title == "" || !exists event.state || event.state < NcursesUi::ActionState::Pending || event.state > NcursesUi::ActionState::Completed || exists events{event.id}) {
            throw "TIMELINE-EVENT-ERROR", "Events need a unique retained ID, title and valid action state";
        }
        if (!event.timestamp) { event.timestamp = now(); }
        string title = replace(NcursesUi::TextEditorWidget::normalizePaste(event.title), "\n", " ");
        string header = format_date("YYYY-MM-DD HH:mm:SS", event.timestamp) + " [" + ("Pending", "Running", "Cancelled", "Failed", "Completed")[event.state] + "] " + title;
        list<string> rows = (header,);
        if (event.details) { rows += split("\n", NcursesUi::TextEditorWidget::normalizePaste(join("\n", event.details)), False, True); }
        int block = TranscriptWidget::appendBlock(rows, "timeline", event.title);
        NcursesUi::LineListContent text = getTranscriptContent(); int kept = min(rows.size(), text.lineCount());
        int header_id = kept == rows.size() ? text.getLineId(text.lineCount() - kept) : -1;
        NcursesUi::TimelineRecord record(event, block, header_id, text.getLineId(text.lineCount() - 1));
        events{event.id} = record; block_events{string(block)} = event.id; indices{event.id} = order.size(); order += event.id;
        pruneEvents();
        if (!exists selected) { selected = event.id; notifySelection(); }
        return block;
    }
    /** Returns retained metadata and normalized retained details. @param id event identity
        @return snapshot; a partially trimmed event exposes only surviving detail lines @throw TIMELINE-EVENT-ERROR if expired */
    hash<NcursesUi::TimelineEvent> getEvent(string id) {
        pruneEvents(); NcursesUi::TimelineRecord record = getRecord(id); hash<NcursesUi::TimelineEvent> event = record.event;
        list<string> rows = split("\n", getBlockText(record.block), False, True);
        if (getTranscriptContent().lineForId(record.first_id) >= 0) { shift rows; }
        event.details = rows; return event;
    }
    /** Returns event identities in retained order. @return retained IDs */
    list<string> getEventIds() { pruneEvents(); return first < order.size() ? order[first .. order.size() - 1] : (); }
    /** Returns the selected retained identity. @return ID or NOTHING */
    *string getSelectedEventId() { pruneEvents(); return selected; }
    /** Selects an event and reveals its first retained source line. @param id retained event identity */
    nothing selectEvent(string id) {
        pruneEvents(); NcursesUi::TimelineRecord record = getRecord(id); *string before = selected; selected = id;
        NcursesUi::LineListContent text = getTranscriptContent(); int line = max(0, text.lineForId(record.first_id));
        int line_id = text.getLineId(line); TranscriptWidget::select(<NcursesUi::TextAnchor>{"line_id": line_id, "offset": 0}, <NcursesUi::TextAnchor>{"line_id": line_id, "offset": getSourceLine(line).length()});
        getViewportRect(); setScrollY(text.sourceToVisibleAnchor(line, 0).y);
        if (before !== selected) { notifySelection(); }
    }
    /** Collapses or expands an event's retained details. @param id event identity @param value collapsed */
    nothing setEventCollapsed(string id, bool value) { pruneEvents(); setCollapsed(getRecord(id).block, value); }
    /** Returns detail visibility. @param id event identity @return collapsed */
    bool isEventCollapsed(string id) { pruneEvents(); return getRecord(id).collapsed; }
    /** Keeps transcript search expansion and timeline metadata synchronized. @param id transcript block ID @param value collapsed */
    nothing setCollapsed(int id, bool value) {
        TranscriptWidget::setCollapsed(id, value); *string event = block_events{string(id)};
        if (exists event) { events{event}.collapsed = value; }
    }
    /** Sets selection notification. @param callback committed selection or NOTHING after trimming/clear */
    nothing setOnEventSelect(*code<nothing(*hash<NcursesUi::TimelineEvent>)> callback) { on_select = callback; }
    /** Sets an application-owned inspection/action hook. @param callback selected snapshot; failures propagate
        Use an ActionModel for operation callbacks that require one-shot activation. */
    nothing setOnEventActivate(*code<nothing(hash<NcursesUi::TimelineEvent>)> callback) { on_activate = callback; }
    /** Invokes the application hook without changing event state. @return True if invoked */
    bool activateEvent() { pruneEvents(); if (!isAvailable() || !exists selected || !on_activate) { return False; } on_activate(getEvent(selected)); return True; }
    /** Trims history by retained logical lines. @param maximum nonnegative bound; zero is unlimited */
    nothing setRetentionLimit(int maximum) { TranscriptWidget::setRetentionLimit(maximum); pruneEvents(); }
    /** Clears history and notifies selection removal. */
    nothing clear() {
        bool notify = exists selected; TranscriptWidget::clear(); events = {}; block_events = {}; indices = {}; order = (); first = 0; selected = NOTHING; event_retained_first = NOTHING;
        if (notify) { notifySelection(); }
    }
    /** Rejects untyped history insertion. @param lines ignored @param kind ignored @param title ignored @return never
        @throw TIMELINE-EVENT-ERROR always */
    int appendBlock(list<string> lines, string kind = "output", string title = "") { throw "TIMELINE-EVENT-ERROR", "Use appendEvent() for timeline history"; }
    /** Rejects direct appends. @param lines ignored @throw TIMELINE-EVENT-ERROR always */
    nothing appendLines(list<string> lines) { throw "TIMELINE-EVENT-ERROR", "Use appendEvent() for timeline history"; }
    /** Rejects direct appends. @param line ignored @throw TIMELINE-EVENT-ERROR always */
    nothing appendLine(string line) { throw "TIMELINE-EVENT-ERROR", "Use appendEvent() for timeline history"; }
    /** Rejects mutation of immutable event snapshots. @param id ignored @param lines ignored @throw TIMELINE-EVENT-ERROR always */
    nothing appendBlockLines(int id, list<string> lines) { throw "TIMELINE-EVENT-ERROR", "Append a new event for a history update"; }
    /** Handles event navigation, expansion and application activation. @param event input @return handling result */
    hash<NcursesUi::EventResult> processEvent(hash<Ncurses::InputEvent> event) {
        if (!isAvailable()) { return <NcursesUi::EventResult>{}; } pruneEvents();
        if (event.type == Ncurses::InputType::Key && (event.name == "KEY_UP" || event.name == "KEY_DOWN")) {
            int index = exists selected ? indices{selected} : first;
            index = max(first, min(order.size() - 1, index + (event.name == "KEY_UP" ? -1 : 1)));
            if (index < order.size()) { selectEvent(order[index]); } return <NcursesUi::EventResult>{"handled": True};
        }
        bool toggle = (event.type == Ncurses::InputType::Key && event.name == "KEY_ENTER") || (event.type == Ncurses::InputType::Char && (event.ch == " " || event.ch == "\n" || event.ch == "\r"));
        if (event.type == Ncurses::InputType::Mouse && event.mouse && (event.mouse.button_state & (Ncurses::BUTTON1_PRESSED | Ncurses::BUTTON1_CLICKED | Ncurses::BUTTON1_DOUBLE_CLICKED))) {
            hash<NcursesUi::Rect> view = getViewportRect();
            if (NcursesUi::Geometry::rectContains(view, event.mouse.y, event.mouse.x)) {
                hash<Ncurses::Position> source = getTranscriptContent().visualToSource(event.mouse.y - view.y + getScrollY(), event.mouse.x - view.x + getScrollX());
                *int line = getTranscriptContent().getLineId(source.y); *string id = exists line ? eventForLine(line) : NOTHING;
                if (exists id) { selectEvent(id); toggle = !!(event.mouse.button_state & Ncurses::BUTTON1_DOUBLE_CLICKED); if (!toggle) { return <NcursesUi::EventResult>{"handled": True}; } }
            }
        }
        if (toggle && exists selected) { setEventCollapsed(selected, !isEventCollapsed(selected)); selectEvent(selected); return <NcursesUi::EventResult>{"handled": True, "action": "toggle"}; }
        if (event.type == Ncurses::InputType::Char && (event.ch == "a" || event.ch == "A")) { return <NcursesUi::EventResult>{"handled": activateEvent(), "action": "activate"}; }
        return TranscriptWidget::processEvent(event);
    }
    private NcursesUi::TimelineRecord getRecord(string id) { if (!exists events{id}) { throw "TIMELINE-EVENT-ERROR", "Unknown or expired event: " + id; } return events{id}; }
    private nothing notifySelection() { if (on_select) { on_select(exists selected ? getEvent(selected) : NOTHING); } }
    private *string eventForLine(int line_id) {
        int lo = first; int hi = order.size();
        while (lo < hi) { int mid = (lo + hi) / 2; if (events{order[mid]}.last_id < line_id) { lo = mid + 1; } else { hi = mid; } }
        return lo < order.size() ? order[lo] : NOTHING;
    }
    private nothing pruneEvents() {
        NcursesUi::LineListContent text = getTranscriptContent(); *int start = text.lineCount() ? text.getLineId(0) : NOTHING;
        if (start === event_retained_first) { return; } event_retained_first = start; *string before = selected;
        while (first < order.size() && text.lineForId(events{order[first]}.last_id) < 0) {
            string id = order[first++]; remove block_events{string(events{id}.block)}; remove events{id}; remove indices{id};
        }
        if (exists selected && !exists events{selected}) { selected = first < order.size() ? order[first] : NOTHING; }
        if (first > 256 && first * 2 >= order.size()) {
            order = first < order.size() ? order[first .. order.size() - 1] : (); first = 0; indices = {};
            for (int i = 0; i < order.size(); ++i) { indices{order[i]} = i; }
        }
        if (before !== selected) { notifySelection(); }
    }
}
} # namespace NcursesUi
