#! @file DescribedChoiceWidget.qc Described choices and optional custom responses
/* Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT */
public namespace NcursesUi {
#! Typed choice result; custom text cannot be confused with a predefined stable value.
public hashdecl ChoiceSelection { string value; bool is_custom = False; }
/** Scrollable described choices with stable values and optional free text.
    Up/Down/Home/End move the highlight; Space chooses and Enter chooses/submits.
    Typing on the custom row edits it; pasted newlines become spaces. Disabled
    options are skipped. A successful submit is one-shot until resetSubmission().
    Callback failures preserve the selection and custom draft for retry.
*/
public class DescribedChoiceWidget inherits NcursesUi::ScrollableWidget {
    private {
        list<hash<NcursesUi::ChoiceItem>> items = ();
        NcursesUi::LineListContent lines();
        list<int> line_owner = ();
        list<int> option_lines = ();
        int highlight = -1;
        *hash<NcursesUi::ChoiceSelection> selected;
        bool custom = False;
        string custom_label = "Custom response";
        NcursesReplUi::InputBuffer custom_input();
        *code<*string(hash<NcursesUi::ChoiceSelection>)> validator;
        *code<nothing(hash<NcursesUi::ChoiceSelection>)> on_submit;
        *code<nothing(*hash<NcursesUi::ChoiceSelection>)> on_change;
        int state = NcursesUi::ActionState::Pending;
        *string error;
        int min_height = 1;
        int max_height = 8;
    }
    /** Creates a selector. @param options uniquely valued options */
    constructor(list<hash<NcursesUi::ChoiceItem>> options = ()) { lines.setWordWrap(True); setContent(lines); setItems(options); }
    /** Atomically replaces options, retaining an available selected value or using the new default.
        @param options definitions @throw CHOICE-DEFINITION-ERROR for duplicate values or invalid defaults
    */
    nothing setItems(list<hash<NcursesUi::ChoiceItem>> options) {
        checkEditable(); hash<string, bool> values = {}; *hash<NcursesUi::ChoiceSelection> next; int default_count = 0; int index = -1;
        for (int i = 0; i < options.size(); ++i) {
            hash<NcursesUi::ChoiceItem> item = options[i];
            if (exists values{item.value}) { throw "CHOICE-DEFINITION-ERROR", "Duplicate choice value"; }
            values{item.value} = True;
            if (item.default_value) {
                if (item.disabled || ++default_count > 1) { throw "CHOICE-DEFINITION-ERROR", "Invalid default choice"; }
                next = <NcursesUi::ChoiceSelection>{"value": item.value}; index = i;
            }
        }
        if (selected) {
            if (selected.is_custom && custom) { next = selected; index = options.size(); }
            else {
                for (int i = 0; i < options.size(); ++i) {
                    if (options[i].value == selected.value && !options[i].disabled) { next = selected; index = i; break; }
                }
            }
        }
        *hash<NcursesUi::ChoiceSelection> before = selected;
        items = options; selected = next; highlight = index >= 0 ? index : firstAvailable();
        state = NcursesUi::ActionState::Pending; error = NOTHING; refreshLines();
        if (on_change && selected != before) { on_change(selected); }
    }
    /** Returns immutable option metadata. @return ordered options */
    list<hash<NcursesUi::ChoiceItem>> getItems() { return items; }
    /** Enables a final custom response row. @param enabled include custom input @param label visible label */
    nothing setCustomAllowed(bool enabled, string label = "Custom response") {
        checkEditable();
        if (label.find("\n") >= 0 || label.find("\r") >= 0) { throw "CHOICE-DEFINITION-ERROR", "Custom input label must be a single line"; }
        *hash<NcursesUi::ChoiceSelection> before = selected;
        custom = enabled; custom_label = label;
        if (selected && selected.is_custom && !enabled) { selected = NOTHING; }
        if (highlight >= items.size() || highlight < 0) { highlight = firstAvailable(); }
        error = NOTHING; refreshLines();
        if (on_change && selected != before) { on_change(selected); }
    }
    /** Returns the stable typed selection. @return NOTHING until explicitly chosen or defaulted */
    *hash<NcursesUi::ChoiceSelection> getSelection() { return selected; }
    /** Selects a predefined value, or clears selection. @param value stable value or NOTHING @throw CHOICE-VALUE-ERROR for unavailable values */
    nothing setValue(*string value) {
        checkEditable();
        if (!exists value) {
            bool changed = exists selected; selected = NOTHING; error = NOTHING; refreshLines();
            if (changed && on_change) { on_change(NOTHING); } return;
        }
        for (int i = 0; i < items.size(); ++i) {
            if (items[i].value == value && !items[i].disabled) { highlight = i; choose(); return; }
        }
        throw "CHOICE-VALUE-ERROR", "Unavailable choice value";
    }
    /** Sets and selects a custom draft. @param text response @throw CHOICE-VALUE-ERROR if custom input is disabled */
    nothing setCustomText(string text) {
        checkEditable(); if (!custom) { throw "CHOICE-VALUE-ERROR", "Custom responses are disabled"; }
        text = NcursesUi::TextEditorWidget::normalizePaste(text); text =~ s/\n/ /g;
        custom_input.setText(text); highlight = items.size(); choose();
    }
    /** Returns the retained custom draft. @return plain text */
    string getCustomText() { return custom_input.getText(); }
    /** Sets validation. @param callback returns an error or NOTHING */
    nothing setValidator(*code<*string(hash<NcursesUi::ChoiceSelection>)> callback) { checkEditable(); validator = callback; }
    /** Sets a one-shot submit handler. @param callback receives a typed snapshot */
    nothing setOnSubmit(*code<nothing(hash<NcursesUi::ChoiceSelection>)> callback) { checkEditable(); on_submit = callback; }
    /** Sets selection notification. @param callback receives the selected value */
    nothing setOnChange(*code<nothing(*hash<NcursesUi::ChoiceSelection>)> callback) { checkEditable(); on_change = callback; }
    /** Returns the current validation/callback error. @return error or NOTHING */
    *string getError() { return error; }
    /** Returns the action lifecycle state. @return ActionState */
    int getState() { return state; }
    /** Reopens a completed or failed selection without discarding its draft. @throw CHOICE-BUSY-ERROR during callbacks */
    nothing resetSubmission() { if (state == NcursesUi::ActionState::Running) { throw "CHOICE-BUSY-ERROR", "Choice is submitting"; } state = NcursesUi::ActionState::Pending; error = NOTHING; refreshLines(); }
    /** Validates and submits a snapshot once. @return True on success; False for missing/invalid/duplicate submission */
    bool submit() {
        if (state == NcursesUi::ActionState::Running || state == NcursesUi::ActionState::Completed || !on_submit) { return False; }
        error = !selected ? "Choose a response" : (selected.is_custom && selected.value =~ /\A\s*\z/ ? "Enter a response" : NOTHING);
        if (error) { refreshLines(); return False; }
        state = NcursesUi::ActionState::Running; refreshLines();
        try {
            if (validator) { error = validator(selected); }
            if (error) { state = NcursesUi::ActionState::Pending; refreshLines(); return False; }
            on_submit(selected); state = NcursesUi::ActionState::Completed;
        } catch (hash<ExceptionInfo> ex) { state = NcursesUi::ActionState::Failed; error = ex.desc; refreshLines(); rethrow; }
        refreshLines(); return True;
    }
    /** Sets preferred-height bounds. @param minimum positive rows @param maximum upper bound @throw CHOICE-SIZE-ERROR for invalid bounds */
    nothing setAutoHeight(int minimum, int maximum) { if (minimum < 1 || maximum < minimum) { throw "CHOICE-SIZE-ERROR", "Invalid choice height"; } min_height = minimum; max_height = maximum; markDirty(); }
    /** Measures wrapped descriptions. @param columns available width @return bounded preferred size */
    hash<NcursesUi::Rect> getPreferredSizeForWidth(int columns) { lines.prepareViewport(max(0, columns)); return NcursesUi::Geometry::makeRect(0, 0, max(min_height, min(max_height, lines.totalRows())), columns); }
    /** Reports a caret only for the custom input row. @return editable custom highlight */
    bool wantsCursor() { return custom && highlight == items.size() && state != NcursesUi::ActionState::Running && state != NcursesUi::ActionState::Completed; }
    /** Reveals the highlighted option before painting. @param window output */
    nothing draw(Ncurses::Window window) {
        if (hasFocus() && wantsCursor()) { setCursorLine(option_lines[highlight], custom_label.length() + 4 + custom_input.getCursor()); }
        else { clearCursorLine(); }
        ScrollableWidget::draw(window);
    }
    /** Releases an editable custom caret on focus loss. */
    nothing onFocusOut() { clearCursorLine(); }
    /** Handles navigation, choosing, custom editing and submission. @param event input @return event result */
    hash<NcursesUi::EventResult> processEvent(hash<Ncurses::InputEvent> event) {
        if (!isAvailable() || state == NcursesUi::ActionState::Running || state == NcursesUi::ActionState::Completed) { return <NcursesUi::EventResult>{}; }
        string key = event.name ?? "";
        if (event.type == Ncurses::InputType::Key && (key == "KEY_UP" || key == "KEY_DOWN" || key == "KEY_HOME" || key == "KEY_END")) {
            int direction = key == "KEY_UP" || key == "KEY_END" ? -1 : 1;
            int next = key == "KEY_HOME" ? 0 : (key == "KEY_END" ? items.size() - (custom ? 0 : 1) : highlight + direction);
            while (next >= 0 && next < items.size() && items[next].disabled) { next += direction; }
            if (available(next)) { highlight = next; refreshLines(); revealHighlight(); }
            return <NcursesUi::EventResult>{"handled": True};
        }
        if (event.type == Ncurses::InputType::Mouse && event.mouse && (event.mouse.button_state & (Ncurses::BUTTON1_CLICKED | Ncurses::BUTTON1_PRESSED))) {
            hash<NcursesUi::Rect> view = getViewportRect();
            if (NcursesUi::Geometry::rectContains(view, event.mouse.y, event.mouse.x)) {
                int row = event.mouse.y - view.y + getScrollY();
                if (row < lines.totalRows()) {
                    hash<Ncurses::Position> source = lines.visualToSource(row, event.mouse.x - view.x);
                    int next = line_owner[source.y];
                    if (available(next)) {
                        highlight = next;
                        if (custom && highlight == items.size()) { custom_input.setCursor(max(0, source.x - custom_label.length() - 4)); }
                        choose(); return <NcursesUi::EventResult>{"handled": True, "action": "select"};
                    }
                }
            }
            return <NcursesUi::EventResult>{"handled": True};
        }
        bool enter = (event.type == Ncurses::InputType::Char && (event.ch == "\n" || event.ch == "\r")) || (event.type == Ncurses::InputType::Key && key == "KEY_ENTER");
        if (enter || (event.type == Ncurses::InputType::Char && event.ch == " " && !(custom && highlight == items.size()))) {
            choose(); bool submitted = enter && submit(); return <NcursesUi::EventResult>{"handled": True, "action": submitted ? "submit" : "select"};
        }
        if (custom && highlight == items.size()) {
            bool handled;
            if (event.type == Ncurses::InputType::Paste) {
                string text = NcursesUi::TextEditorWidget::normalizePaste(event.ch ?? ""); text =~ s/\n/ /g; custom_input.insertChar(text); handled = True;
            } else { handled = custom_input.processEvent(event); }
            if (handled) { choose(); return <NcursesUi::EventResult>{"handled": True}; }
        }
        return ScrollableWidget::processEvent(event);
    }
    private nothing checkEditable() { if (state == NcursesUi::ActionState::Running || state == NcursesUi::ActionState::Completed) { throw "CHOICE-BUSY-ERROR", "Choice is submitting or completed"; } }
    private bool available(int index) { return index >= 0 && ((index < items.size() && !items[index].disabled) || (custom && index == items.size())); }
    private int firstAvailable() { for (int i = 0; i < items.size(); ++i) { if (!items[i].disabled) { return i; } } return custom ? items.size() : -1; }
    private nothing choose() {
        if (!available(highlight)) { return; }
        *hash<NcursesUi::ChoiceSelection> before = selected;
        selected = <NcursesUi::ChoiceSelection>{"value": highlight == items.size() ? custom_input.getText() : items[highlight].value, "is_custom": highlight == items.size()};
        error = NOTHING; state = NcursesUi::ActionState::Pending; refreshLines(); revealHighlight();
        if (on_change && selected != before) { on_change(selected); }
    }
    private nothing revealHighlight() {
        if (highlight < 0 || highlight >= option_lines.size()) { return; }
        hash<NcursesUi::Rect> view = getViewportRect(); int row = lines.sourceToVisual(option_lines[highlight], 0).y;
        if (row < getScrollY()) { setScrollY(row); } else if (row >= getScrollY() + view.rows) { setScrollY(row - max(1, view.rows) + 1); }
    }
    private nothing refreshLines() {
        list<string> text = (); list<int> owners = (); list<int> starts = ();
        for (int i = 0; i < items.size() + (custom ? 1 : 0); ++i) {
            starts += text.size(); bool free = i == items.size();
            bool chosen = selected && (free ? selected.is_custom : (!selected.is_custom && selected.value == items[i].value));
            string label = free ? custom_label + ": " + custom_input.getText() : items[i].label;
            string row = (chosen ? "● " : "○ ") + label;
            if (!free && items[i].disabled) { row = "\e[2m" + row + " (unavailable)\e[0m"; }
            else if (i == highlight) { row = "\e[7m" + row + "\e[0m"; }
            # Labels and descriptions may contain hard newlines; all their rows map to the same stable option.
            list<string> rows = split("\n", row);
            if (!free && items[i].description) { rows += split("\n", "  " + items[i].description); }
            if (!free && items[i].recommendation) { rows += split("\n", "  " + items[i].recommendation); }
            foreach string line in (rows) { text += line; owners += i; }
        }
        if (!text) { text += "No available choices"; owners += -1; }
        if (state == NcursesUi::ActionState::Running) { text += "Submitting…"; owners += -1; }
        else if (state == NcursesUi::ActionState::Completed) { text += "Submitted"; owners += -1; }
        if (error) { foreach string line in (split("\n", "Error: " + error)) { text += line; owners += -1; } }
        lines.setLines(text); option_lines = starts; line_owner = owners; markDirty();
    }
}
} # namespace NcursesUi
