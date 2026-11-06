#! @file FormWidget.qc Typed forms with labels, validation and scroll-aware focus
/* Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT */
public namespace NcursesUi {
/** @internal Multiline field adapter delivering changes through the form model. */
class FormEditorControl inherits NcursesUi::TextEditorWidget {
    private { code<nothing(string)> changed; }
    constructor(code<nothing(string)> callback) { changed = callback; setEnterSubmits(False); setAutoHeight(2, 4); }
    hash<NcursesUi::EventResult> processEvent(hash<Ncurses::InputEvent> event) {
        if (!isAvailable()) { return <NcursesUi::EventResult>{}; }
        string before = getText(); hash<NcursesUi::EventResult> result = TextEditorWidget::processEvent(event);
        if (before != getText()) { changed(getText()); } return result;
    }
}
/** Composable form driven by FormModel, with wrapped labels/help/errors and typed controls.
    Bind the application's focus manager with setFocusManager() to focus the first
    invalid field. Tab order follows schema order; focused controls scroll into view
    even when the whole form is taller than the terminal. Enter in single-line fields
    submits, while multiline fields retain Enter for a newline. Submission exceptions
    propagate after rendering the model's error state; entered drafts remain intact.
    The model and widget belong to the UI thread. Async callers may use beginSubmit(),
    complete() and fail() on the model and let the revision-driven UI repaint.
*/
public class FormWidget inherits NcursesUi::Widget {
    private {
        NcursesUi::FormModel model;
        list<hash<NcursesUi::FormField>> fields = ();
        hash<string, NcursesUi::Widget> controls = {};
        hash<string, NcursesUi::LabelWidget> labels = {};
        hash<string, NcursesUi::LabelWidget> help = {};
        hash<string, NcursesUi::LabelWidget> errors = {};
        NcursesUi::LabelWidget message();
        NcursesUi::ButtonWidget submit_button("Submit", "submit");
        NcursesUi::ButtonWidget cancel_button("Cancel", "cancel");
        *NcursesUi::FocusManager focus;
        *NcursesUi::Widget last_focus;
        *code<auto(hash<auto>)> on_submit;
        *code<nothing()> on_cancel;
        int revision = -1;
        int defaults_revision = -1;
        hash<string, int> observed_value_revisions = {};
        hash<string, bool> imported_invalid_choices = {};
        int scroll_y = 0;
        bool arranging = False;
        bool synchronizing = False;
    }
    /** Creates controls for a model. @param value UI-thread-owned form model */
    constructor(NcursesUi::FormModel value) {
        model = value; buildFields();
        submit_button.setOnActivate(sub (string id) { submit(); });
        cancel_button.setOnActivate(sub (string id) { cancel(); });
    }
    /** Returns the model. @return shared form model */
    NcursesUi::FormModel getModel() { return model; }
    /** Returns a named field control for focus or application customization.
        @param name field identity @return corresponding control @throw FORM-FIELD-ERROR if unknown
    */
    NcursesUi::Widget getControl(string name) {
        if (fields != model.getFields()) { buildFields(); layout(); markDirty(); }
        if (!exists controls{name}) { throw "FORM-FIELD-ERROR", "Unknown form field: " + name; } return controls{name};
    }
    /** Binds focus management for first-error navigation. @param manager application focus manager */
    nothing setFocusManager(*NcursesUi::FocusManager manager) { focus = manager; }
    /** Sets submission behavior. @param callback receives typed values and returns an application result */
    nothing setOnSubmit(*code<auto(hash<auto>)> callback) { on_submit = callback; revision = -1; markDirty(); }
    /** Sets cancellation notification. @param callback optional application handler */
    nothing setOnCancel(*code<nothing()> callback) { on_cancel = callback; }
    /** Returns the form's vertical content offset. @return rows above the viewport */
    int getScrollY() { return scroll_y; }
    /** Synchronizes programmatic input edits, validates and submits once.
        @return True when completed, False for validation failure or unavailable submission
    */
    bool submit() {
        if (!on_submit || model.getState() == NcursesUi::ActionState::Running || model.getState() == NcursesUi::ActionState::Completed) { return False; }
        # Model edits and schema replacements must take effect even before the next paint.
        syncPresentation(); syncValues(); bool result;
        try { result = model.submit(on_submit); }
        catch (hash<ExceptionInfo> ex) { syncPresentation(); layout(); markDirty(); rethrow; }
        syncPresentation();
        *string invalid = model.firstInvalid();
        if (exists invalid && focus) { focus.setFocus(controls{invalid}); }
        layout(); markDirty(); return result;
    }
    /** Cancels submission while retaining values; late model completions are ignored. */
    nothing cancel() { if (model.getState() == NcursesUi::ActionState::Completed) { return; } model.cancel(); syncPresentation(); layout(); markDirty(); if (on_cancel) { on_cancel(); } }
    /** Updates geometry and immediately lays out controls. @param rect screen allocation */
    nothing setFrame(hash<NcursesUi::Rect> rect) { Widget::setFrame(rect); layout(); }
    /** Includes model revision and newly focused controls in repaint decisions. @return local dirty state */
    bool needsOwnDraw() { return Widget::needsOwnDraw() || revision != model.getRevision() || last_focus != findFocused(); }
    /** Reports local/model or child invalidation. @return needs repaint */
    bool isDirty() { return needsOwnDraw() || Widget::isDirty(); }
    /** Reconciles model state and lays out children before clipping decisions.
        @param window output surface @param force repaint an exposed subtree
    */
    nothing drawTree(Ncurses::Window window, bool force = False) {
        if (revision != model.getRevision() || last_focus != findFocused()) { syncPresentation(); layout(); markDirty(); }
        Widget::drawTree(window, force);
    }
    /** Acknowledges model changes while clipped. */
    nothing onDrawClipped() { syncPresentation(); layout(); Widget::onDrawClipped(); revision = model.getRevision(); last_focus = findFocused(); }
    /** Lays out wrapped field metadata and keeps the current control visible. */
    nothing layout() {
        if (arranging) { return; } arranging = True; on_exit arranging = False;
        hash<NcursesUi::Rect> view = contentRect(); list<NcursesUi::Widget> ordered = (); list<int> heights = (); int total = 0;
        foreach hash<NcursesUi::FormField> field in (fields) {
            foreach NcursesUi::Widget widget in ((labels{field.name}, controls{field.name}, help{field.name}, errors{field.name})) {
                if (!widget.isVisible()) { continue; }
                int rows = max(1, widget.getPreferredSizeForWidth(view.cols).rows);
                ordered += widget; heights += rows; total += rows;
            }
        }
        if (message.isVisible()) { ordered += message; int rows = message.getPreferredSizeForWidth(view.cols).rows; heights += rows; total += rows; }
        ordered += submit_button; heights += 1; ++total; ordered += cancel_button; heights += 1; ++total;
        *NcursesUi::Widget current = findFocused(); int offset = 0;
        for (int i = 0; i < ordered.size(); ++i) {
            if (ordered[i] == current) {
                if (offset < scroll_y) { scroll_y = offset; }
                else if (offset + heights[i] > scroll_y + view.rows) { scroll_y = offset + min(heights[i], max(1, view.rows)) - max(1, view.rows); }
            }
            offset += heights[i];
        }
        scroll_y = max(0, min(scroll_y, max(0, total - view.rows))); offset = 0;
        for (int i = 0; i < ordered.size(); ++i) {
            ordered[i].setFrameValues(view.y + offset - scroll_y, view.x, heights[i], view.cols); offset += heights[i];
        }
        last_focus = current;
    }
    /** Escape cancels; Ctrl-Enter-style application bindings can call submit().
        @param event bubbled input @return handled/action result
    */
    hash<NcursesUi::EventResult> processEvent(hash<Ncurses::InputEvent> event) {
        if (event.type == Ncurses::InputType::Char && event.ch == "\x1b") { cancel(); return <NcursesUi::EventResult>{"handled": True, "action": "cancel"}; }
        return <NcursesUi::EventResult>{};
    }
    private nothing buildFields() {
        # Construct a complete replacement before changing the live child tree.
        list<hash<NcursesUi::FormField>> next = model.getFields();
        hash<string, NcursesUi::Widget> next_controls = {};
        hash<string, NcursesUi::LabelWidget> next_labels = {}; hash<string, NcursesUi::LabelWidget> next_help = {};
        hash<string, NcursesUi::LabelWidget> next_errors = {}; hash<string, bool> next_invalid = {};
        foreach hash<NcursesUi::FormField> field in (next) {
            next_labels{field.name} = new NcursesUi::LabelWidget(field.label + (field.required ? " *" : ""));
            next_help{field.name} = new NcursesUi::LabelWidget(field.help); next_help{field.name}.setVisible(!!field.help);
            next_errors{field.name} = new NcursesUi::LabelWidget(); next_errors{field.name}.setVisible(False);
            next_controls{field.name} = createControl(field);
            if (field.type == NcursesUi::FieldType::Choice && exists model.getValue(field.name) && !choiceAvailable(field, string(model.getValue(field.name)))) { next_invalid{field.name} = True; }
        }
        foreach NcursesUi::Widget child in (getChildren()) { removeChild(child); }
        fields = next; controls = next_controls; labels = next_labels; help = next_help; errors = next_errors;
        foreach hash<NcursesUi::FormField> field in (fields) {
            addChild(labels{field.name}); addChild(controls{field.name}); addChild(help{field.name}); addChild(errors{field.name});
        }
        addChild(message); addChild(submit_button); addChild(cancel_button);
        observed_value_revisions = {};
        foreach hash<NcursesUi::FormField> f in (fields) { observed_value_revisions{f.name} = model.getValueRevision(f.name); }
        imported_invalid_choices = next_invalid; defaults_revision = model.getDefaultsRevision(); syncPresentation();
    }
    private NcursesUi::Widget createControl(hash<NcursesUi::FormField> field) {
        string name = field.name; auto value = model.getValue(name);
        if (field.type == NcursesUi::FieldType::Boolean) {
            NcursesUi::CheckboxWidget control("", !!value);
            control.setOnToggle(sub (bool checked) { storeValue(name, checked); markDirty(); }); return control;
        }
        if (field.type == NcursesUi::FieldType::Choice) {
            NcursesUi::DescribedChoiceWidget control(field.choices); control.setAutoHeight(1, 4);
            if (exists value && choiceAvailable(field, string(value))) { control.setValue(string(value)); }
            else { control.setValue(NOTHING); }
            control.setOnChange(sub (*hash<NcursesUi::ChoiceSelection> selection) { if (!synchronizing) { storeValue(name, selection ? selection.value : NOTHING); markDirty(); } }); return control;
        }
        if (field.type == NcursesUi::FieldType::Multiline) {
            NcursesUi::FormEditorControl control(sub (string text) { changed(field, text); }); control.setText(exists value ? string(value) : ""); return control;
        }
        NcursesUi::TextInputWidget control(); control.setText(exists value ? string(value) : ""); control.setClearOnSubmit(False);
        control.setPassword(field.type == NcursesUi::FieldType::Password); control.setPreferredSize(1, 20);
        control.setOnChange(sub (string text) { changed(field, text); }); control.setOnSubmit(sub (string text) { submit(); }); return control;
    }
    private nothing changed(hash<NcursesUi::FormField> field, string text) {
        auto value = text;
        if (field.type == NcursesUi::FieldType::Integer || field.type == NcursesUi::FieldType::Number) {
            if (text == "") { value = NOTHING; }
            else if (field.type == NcursesUi::FieldType::Integer) {
                if (!(text =~ /\A[+-]?\d+\z/) || number(text) < -9223372036854775808n || number(text) > 9223372036854775807n) {
                    model.setFieldError(field.name, "Enter an integer between -9223372036854775808 and 9223372036854775807"); markDirty(); return;
                }
                value = int(text);
            } else {
                if (!(text =~ /\A[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?\z/)) {
                    model.setFieldError(field.name, "Enter a number"); markDirty(); return;
                }
                value = number(text);
                if (value.nanp() || value.infp()) { model.setFieldError(field.name, "Enter a finite number"); markDirty(); return; }
            }
        }
        if (model.getValue(field.name) != value || exists model.getErrors(){field.name}) { storeValue(field.name, value); }
        markDirty();
    }
    private nothing syncValues() {
        foreach hash<NcursesUi::FormField> field in (fields) {
            if (field.read_only) { continue; }
            NcursesUi::Widget control = controls{field.name};
            if (field.type == NcursesUi::FieldType::Boolean) { storeValue(field.name, cast<NcursesUi::CheckboxWidget>(control).isChecked()); }
            else if (field.type == NcursesUi::FieldType::Choice) {
                if (imported_invalid_choices{field.name}) { continue; }
                *hash<NcursesUi::ChoiceSelection> selection = cast<NcursesUi::DescribedChoiceWidget>(control).getSelection(); storeValue(field.name, selection ? selection.value : NOTHING);
            } else { changed(field, field.type == NcursesUi::FieldType::Multiline ? cast<NcursesUi::TextEditorWidget>(control).getText() : cast<NcursesUi::TextInputWidget>(control).getText()); }
        }
    }
    private static bool choiceAvailable(hash<NcursesUi::FormField> field, string value) {
        foreach hash<NcursesUi::ChoiceItem> item in (field.choices) { if (item.value == value && !item.disabled) { return True; } } return False;
    }
    private nothing storeValue(string name, auto value) { model.setValue(name, value); observed_value_revisions{name} = model.getValueRevision(name); remove imported_invalid_choices{name}; }
    private nothing syncPresentation() {
        if (fields != model.getFields()) { buildFields(); return; }
        if (synchronizing) { return; } synchronizing = True; on_exit synchronizing = False;
        hash<auto> values = model.getValues(); bool restore_defaults = defaults_revision != model.getDefaultsRevision();
        foreach hash<NcursesUi::FormField> field in (fields) {
            if (!restore_defaults && observed_value_revisions{field.name} == model.getValueRevision(field.name)) { continue; }
            NcursesUi::Widget control = controls{field.name}; auto value = values{field.name};
            if (field.type == NcursesUi::FieldType::Boolean) { cast<NcursesUi::CheckboxWidget>(control).setChecked(!!value); }
            else if (field.type == NcursesUi::FieldType::Choice) {
                bool valid = !exists value || choiceAvailable(field, string(value));
                cast<NcursesUi::DescribedChoiceWidget>(control).setValue(valid && exists value ? string(value) : NOTHING);
                if (!valid) { imported_invalid_choices{field.name} = True; } else { remove imported_invalid_choices{field.name}; }
            }
            else if (field.type == NcursesUi::FieldType::Multiline) { cast<NcursesUi::TextEditorWidget>(control).setText(exists value ? string(value) : ""); }
            else { cast<NcursesUi::TextInputWidget>(control).setText(exists value ? string(value) : ""); }
        }
        foreach hash<NcursesUi::FormField> f in (fields) { observed_value_revisions{f.name} = model.getValueRevision(f.name); }
        defaults_revision = model.getDefaultsRevision();
        hash<string, string> messages = model.getErrors(); int state = model.getState();
        bool editable = state != NcursesUi::ActionState::Running && state != NcursesUi::ActionState::Completed;
        foreach hash<NcursesUi::FormField> field in (fields) {
            NcursesUi::Widget control = controls{field.name};
            if (control.isEnabled() != (editable && !field.read_only)) { control.setEnabled(editable && !field.read_only); }
            string text = messages{field.name} ?? (imported_invalid_choices{field.name} ? "Choose an available value" : ""); errors{field.name}.setText(text ? "Error: " + text : ""); errors{field.name}.setVisible(!!text);
        }
        string status = messages{""} ?? model.getFailure() ?? "";
        if (state == NcursesUi::ActionState::Running) { status = "Submitting…"; }
        else if (state == NcursesUi::ActionState::Completed) { status = "Submitted"; }
        else if (state == NcursesUi::ActionState::Cancelled) { status = "Cancelled"; }
        message.setText(status); message.setVisible(!!status); submit_button.setEnabled(editable && !!on_submit);
        cancel_button.setEnabled(state != NcursesUi::ActionState::Completed); revision = model.getRevision();
    }
}
} # namespace NcursesUi
