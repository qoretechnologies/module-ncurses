# Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT
namespace NcursesGallery {
# The fixture model keeps recorded timestamps stable while retaining real action transitions.
class FixtureAction inherits NcursesUi::ActionModel {
    constructor(string label) : ActionModel("gallery-operation", label) {}
    *date getStarted() { return ActionModel::getStarted() ? date("2026-01-02T03:04:05Z") : NOTHING; }
    *date getFinished() { return ActionModel::getFinished() ? date("2026-01-02T03:04:06Z") : NOTHING; }
}
class Fixture {
    private {
        NcursesUi::Application app;
        hash<NcursesGallery::Story> story;
        *NcursesUi::Widget widget;
        *NcursesUi::PanelWidget panel;
        *NcursesUi::TextEditorWidget owner;
        *NcursesUi::ActionModel action;
        *NcursesUi::FormModel form;
        *NcursesUi::FileSelectionModel files;
        *NcursesUi::AssistanceModel assistance;
        int activations = 0;
        bool closed = False;
    }
    constructor(NcursesUi::Application application, hash<NcursesGallery::Story> definition) {
        app = application; story = definition;
        try { build(); } catch (hash<ExceptionInfo> ex) { close(); rethrow; }
    }
    NcursesUi::Widget control() { return widget; }
    private nothing build() {
        hash<auto> data = {}; data += story.fixture;
        if (story.state == "empty") {
            foreach string field in (("text", "name", "message")) { if (exists data{field}) { data{field} = ""; } }
            foreach string field in (("lines", "options", "choices", "items", "samples", "menus", "segments", "files")) { if (exists data{field}) { data{field} = (); } }
            if (exists data.data) { data.data = {}; }
        } else if (story.state == "unicode") {
            foreach string field in (("text", "name", "message", "label")) {
                if (exists data{field} && story.widget != "AssistancePopupWidget") { data{field} = "Unicode 界é " + strmul("long content ", 12) + "界é"; }
            }
            if (story.widget == "TranscriptWidget") { data.lines = ("Unicode 界é " + strmul("long content ", 12),); }
            if (exists data.menus) { data.menus[0].label = "Open 界é " + strmul("long ", 10); }
            if (exists data.completion) { data.completion = "name 界é " + strmul("documentation ", 6); }
        }
        switch (story.widget) {
            case "LabelWidget": widget = new NcursesUi::LabelWidget(data.text); break;
            case "TextInputWidget":
                NcursesUi::TextInputWidget input(data.prompt); input.setText(data.text); input.setClearOnSubmit(False); widget = input; break;
            case "TranscriptWidget":
                NcursesUi::TranscriptWidget transcript(); transcript.appendLines(data.lines); widget = transcript; break;
            case "CodeViewWidget": widget = new NcursesUi::CodeViewWidget(data.text, data.language); break;
            case "ButtonWidget":
                NcursesUi::ButtonWidget button(data.label); button.setOnActivate(sub (string id) { ++activations; }); widget = button; break;
            case "CheckboxWidget": widget = new NcursesUi::CheckboxWidget(data.label); break;
            case "RadioGroupWidget": widget = new NcursesUi::RadioGroupWidget(data.options); break;
            case "ComboBoxWidget":
                NcursesUi::ComboBoxWidget combo(data.options); if (story.state == "unicode") { combo.setText("Unicode 界é " + strmul("long ", 20) + "界é"); } widget = combo; break;
            case "DescribedChoiceWidget":
                NcursesUi::DescribedChoiceWidget described(data.choices); described.setOnSubmit(sub (hash<NcursesUi::ChoiceSelection> selection) { ++activations; }); widget = described; break;
            case "FormWidget":
                form = new NcursesUi::FormModel((
                    <NcursesUi::FormField>{"name": "name", "label": "Request name", "required": True, "default_value": data.name, "help": "A recognizable name for this request."},
                    <NcursesUi::FormField>{"name": "count", "label": "Attempts", "type": NcursesUi::FieldType::Integer, "default_value": 3, "help": "Default: three attempts."},
                    <NcursesUi::FormField>{"name": "enabled", "label": "Include details", "type": NcursesUi::FieldType::Boolean, "default_value": True}));
                NcursesUi::FormWidget form_widget(form); form_widget.setFocusManager(app.getFocusManager());
                form_widget.setOnSubmit(auto sub (hash<auto> values) { ++activations; return values; }); widget = form_widget; break;
            case "ListWidget":
                NcursesUi::ListWidget list_widget(); list_widget.setItems(data.items); widget = list_widget; break;
            case "TreeWidget": widget = new NcursesUi::TreeWidget(data.data); break;
            case "KeyValueWidget": widget = new NcursesUi::KeyValueWidget(data.data); break;
            case "TextChartWidget": widget = new NcursesUi::TextChartWidget(new NcursesUi::TextChart(data.samples, story.state == "unicode" ? "Values 界é" : "Values", "ms")); break;
            case "MenuBarWidget":
                NcursesUi::MenuBarWidget menu(); menu.setApplication(app);
                if (story.state != "empty") { menu.addMenu(story.state == "unicode" ? "File 界é" : "File", data.menus); }
                menu.setOnCommand(sub (string command) { ++activations; }); widget = menu; break;
            case "DropdownMenuWidget":
                NcursesUi::DropdownMenuWidget dropdown(app.getSession(), data.menus);
                dropdown.setOnClose(sub () { dismiss(); }); dropdown.setOnSelect(sub (hash<auto> item) { ++activations; dismiss(); });
                widget = dropdown; panel = dropdown; break;
            case "DialogWidget":
                NcursesUi::DialogWidget dialog(app.getSession(), "Review changes", data.message, data.buttons);
                dialog.setOnButton(sub (int index, string label) { ++activations; dismiss(); }); dialog.setOnDismiss(sub () { dismiss(); });
                widget = dialog; panel = dialog; break;
            case "AssistancePopupWidget":
                owner = new NcursesUi::TextEditorWidget(); owner.setText(data.text); owner.getBuffer().setCursor(8);
                assistance = new NcursesUi::AssistanceModel(owner.getBuffer());
                hash<NcursesUi::AssistanceRequest> request = assistance.beginRequest();
                assistance.complete(request, <NcursesUi::AssistanceResponse>{"completions": story.state == "empty" ? () : (
                    <NcursesUi::CompletionItem>{"id": "name", "label": data.completion, "text": data.completion,
                        "range": <NcursesUi::SourceRange>{"start": 6, "end": 8}, "documentation": "The name to greet.\nEnter applies; Escape cancels.", "rank": 10},),
                    "signature": <NcursesUi::SignatureHelp>{"label": "greet(name)", "parameters": ("name",), "active_parameter": 0}});
                NcursesUi::AssistancePopupWidget assist(app.getSession(), owner, assistance); assist.setOnDismiss(sub () { dismiss(); });
                widget = assist; panel = assist; break;
            case "StatusBarWidget":
                NcursesUi::StatusBarWidget status(); status.setSegments(data.segments); widget = status; break;
            case "ProgressWidget":
                action = new NcursesGallery::FixtureAction(data.label); NcursesUi::ProgressWidget progress(action);
                progress.setOnStart(sub (hash<NcursesUi::ActionRequest> token) { action.progress(token, 1.0, 4.0, "One of four items reviewed"); }); widget = progress; break;
            case "TimelineWidget":
                NcursesUi::TimelineWidget timeline();
                if (story.state != "empty") {
                    timeline.appendEvent(<NcursesUi::TimelineEvent>{"id": "started", "timestamp": date(data.timestamp), "title": "Preview started 界é", "details": ("Inspecting four items",), "state": NcursesUi::ActionState::Running});
                    timeline.appendEvent(<NcursesUi::TimelineEvent>{"id": "completed", "timestamp": date(data.timestamp), "title": "Preview complete", "details": ("No files modified",)});
                }
                widget = timeline; break;
            case "FileBrowserWidget":
                NcursesUi::FileBrowserWidget browser(app.getSession(), data.directory);
                browser.setFileInfoProvider(*hash<auto> sub (string path) { return {"description": "Gallery fixture", "mime_type": "text/plain", "is_text": True}; });
                browser.setOnDismiss(sub () { dismiss(); }); widget = browser; panel = browser; break;
            case "FileSelectionWidget":
                files = new NcursesUi::FileSelectionModel(data.files, True);
                files.setHandler(NcursesUi::FileOperation::Open, bool sub (list<hash<NcursesUi::FileSelectionEntry>> selection) { ++activations; return True; });
                widget = new NcursesUi::FileSelectionWidget(files); break;
            case "AttachmentWidget":
                NcursesUi::AttachmentWidget attachment(data.attachment);
                attachment.setHandler(NcursesUi::FileOperation::Open, bool sub (hash<NcursesUi::AttachmentInfo> value) { ++activations; return True; });
                attachment.setHandler(NcursesUi::FileOperation::Export, bool sub (hash<NcursesUi::AttachmentInfo> value) { return False; });
                widget = attachment; break;
            default: throw "GALLERY-STORY-ERROR", "Unknown catalog factory: " + story.widget;
        }
        @assert(widget);
        if (panel) {
            if (!owner) { owner = new NcursesUi::TextEditorWidget(); owner.setText("Background draft 界é"); }
            app.setRoot(owner); app.getFocusManager().setFocus(owner); app.getSession().setCursor(1); app.drawAll();
            hash<Ncurses::Size> size = app.getSession().screen().size();
            if (widget instanceof NcursesUi::DropdownMenuWidget) {
                cast<NcursesUi::DropdownMenuWidget>(widget).positionAt(1, 2, size.rows, size.cols);
            } else if (widget instanceof NcursesUi::AssistancePopupWidget) {
                cast<NcursesUi::AssistancePopupWidget>(widget).positionAtCaret(size.rows, size.cols);
            } else if (widget instanceof NcursesUi::FileBrowserWidget) {
                panel.setFrameValues(0, 0, size.rows, size.cols);
            } else { panel.fitToScreen(size.rows, size.cols); }
            panel.createPanel(); app.pushPopup(panel);
        } else {
            app.setRoot(widget); app.getFocusManager().setFocus(widget);
            if (widget instanceof NcursesUi::FormWidget) { app.getFocusManager().setFocus(cast<NcursesUi::FormWidget>(widget).getControl("name")); }
            *NcursesUi::Widget focus = app.getFocusManager().getCurrentFocus(); app.getSession().setCursor(focus && focus.wantsCursor() ? 1 : 0);
        }
        app.drawAll(); applyState(); app.drawAll();
    }
    private nothing applyState() {
        if (story.state == "disabled") { widget.setEnabled(False); return; }
        if (story.state == "unicode" && widget instanceof NcursesUi::FileBrowserWidget) { panel.setTitle("Files 界é — long descriptive directory name"); }
        if (story.state == "selected") {
            if (widget instanceof NcursesUi::CheckboxWidget) { cast<NcursesUi::CheckboxWidget>(widget).setChecked(True); }
            else if (widget instanceof NcursesUi::RadioGroupWidget) { cast<NcursesUi::RadioGroupWidget>(widget).setSelectedIndex(1); }
            else if (widget instanceof NcursesUi::ComboBoxWidget) { cast<NcursesUi::ComboBoxWidget>(widget).setText("Execute"); }
            else if (widget instanceof NcursesUi::DescribedChoiceWidget) { cast<NcursesUi::DescribedChoiceWidget>(widget).setValue("execute"); }
            else if (widget instanceof NcursesUi::ListWidget) { cast<NcursesUi::ListWidget>(widget).setSelectedIndex(1); }
            else if (widget instanceof NcursesUi::MenuBarWidget) { cast<NcursesUi::MenuBarWidget>(widget).openMenu(0); }
            else if (widget instanceof NcursesUi::TimelineWidget) { cast<NcursesUi::TimelineWidget>(widget).selectEvent("completed"); }
            else if (widget instanceof NcursesUi::DialogWidget) { app.processEvent(<Ncurses::InputEvent>{"type": Ncurses::InputType::Char, "ch": "\t"}); }
            else if (widget instanceof NcursesUi::TranscriptWidget) {
                NcursesUi::TranscriptWidget transcript = cast<NcursesUi::TranscriptWidget>(widget);
                int id = transcript.getBlocks()[0].line_ids[0];
                transcript.select(<NcursesUi::TextAnchor>{"line_id": id, "offset": 0}, <NcursesUi::TextAnchor>{"line_id": id, "offset": 5});
            } else if (files) { files.toggle("sample"); }
            else { app.processEvent(Registry::key("KEY_DOWN")); }
        } else if (story.state == "invalid") {
            if (form) { form.setFieldError("name", "Use a unique request name."); }
            else if (action) { hash<NcursesUi::ActionRequest> request = action.begin(); action.fail(request, "Preview failed; draft retained."); }
            else if (assistance) { hash<NcursesUi::AssistanceRequest> request = assistance.beginRequest(); assistance.fail(request, "Provider unavailable; keep editing."); }
            else if (files) {
                files.toggle("sample"); files.setValidator(*string sub (list<hash<NcursesUi::FileSelectionEntry>> selected) { return "Choose an available destination."; });
                files.dispatch(NcursesUi::FileOperation::Open);
            } else if (widget instanceof NcursesUi::DescribedChoiceWidget) {
                NcursesUi::DescribedChoiceWidget choice = cast<NcursesUi::DescribedChoiceWidget>(widget);
                choice.setValidator(*string sub (hash<NcursesUi::ChoiceSelection> selection) { return "Explain the requested change."; }); choice.submit();
            } else if (widget instanceof NcursesUi::AttachmentWidget) {
                NcursesUi::AttachmentWidget attachment = cast<NcursesUi::AttachmentWidget>(widget);
                attachment.setHandler(NcursesUi::FileOperation::Open, bool sub (hash<NcursesUi::AttachmentInfo> value) { throw "GALLERY-FILE-ERROR", "Fixture is unavailable"; });
                try { attachment.activate(NcursesUi::FileOperation::Open); } catch (hash<ExceptionInfo> ex) { if (ex.err != "GALLERY-FILE-ERROR") { rethrow; } }
            }
        } else if (story.state == "loading") {
            if (form) { form.beginSubmit(); }
            else if (action) { action.begin(); }
            else if (assistance) { assistance.beginRequest(); }
        }
    }
    private nothing dismiss() { app.popModal(); if (panel) { panel.destroyPanel(); } }
    hash<auto> inspect() {
        hash<auto> state = {}; state.activations = activations;
        state.empty = False; state.has_selection = False; state.has_error = False; state.loading = False;
        if (owner) { state.text = owner.getText(); }
        if (widget instanceof NcursesUi::ScrollableWidget) { state.scroll = cast<NcursesUi::ScrollableWidget>(widget).getScrollY(); }
        if (widget instanceof NcursesUi::TextInputWidget) { state.text = cast<NcursesUi::TextInputWidget>(widget).getText(); }
        if (widget instanceof NcursesUi::CheckboxWidget) { state.checked = cast<NcursesUi::CheckboxWidget>(widget).isChecked(); }
        if (widget instanceof NcursesUi::RadioGroupWidget) {
            state.selected = cast<NcursesUi::RadioGroupWidget>(widget).getSelectedIndex(); state.highlight = cast<NcursesUi::RadioGroupWidget>(widget).getHighlightIndex();
        }
        if (widget instanceof NcursesUi::ComboBoxWidget) { state.text = cast<NcursesUi::ComboBoxWidget>(widget).getText(); }
        if (widget instanceof NcursesUi::DescribedChoiceWidget) { state.choice = cast<NcursesUi::DescribedChoiceWidget>(widget).getSelection().value; }
        if (widget instanceof NcursesUi::ListWidget) { state.selected = cast<NcursesUi::ListWidget>(widget).getSelectedIndex(); state.scroll = cast<NcursesUi::ListWidget>(widget).getScrollOffset(); }
        if (widget instanceof NcursesUi::MenuBarWidget) { state.active_menu = cast<NcursesUi::MenuBarWidget>(widget).getActiveMenu(); }
        if (widget instanceof NcursesUi::DropdownMenuWidget) { state.highlight = cast<NcursesUi::DropdownMenuWidget>(widget).getHighlightIndex(); }
        if (action) { state.operation_state = action.getState(); }
        if (widget instanceof NcursesUi::AttachmentWidget) { state.operation_state = cast<NcursesUi::AttachmentWidget>(widget).getState(); }
        if (widget instanceof NcursesUi::TimelineWidget) { state.event = cast<NcursesUi::TimelineWidget>(widget).getSelectedEventId(); }
        if (files) { state.file_count = files.getSelected().size(); }
        if (widget instanceof NcursesUi::LabelWidget) { state.empty = cast<NcursesUi::LabelWidget>(widget).getText() == ""; }
        if (widget instanceof NcursesUi::TextInputWidget) { state.empty = state.text == ""; }
        if (widget instanceof NcursesUi::TranscriptWidget) {
            NcursesUi::TranscriptWidget transcript = cast<NcursesUi::TranscriptWidget>(widget);
            state.empty = !transcript.getBlocks(); state.has_selection = transcript.getSelectedText() != "";
        }
        if (widget instanceof NcursesUi::CodeViewWidget) { state.empty = cast<NcursesUi::CodeViewWidget>(widget).getText() == ""; }
        if (widget instanceof NcursesUi::CheckboxWidget) { state.has_selection = state.checked; }
        if (widget instanceof NcursesUi::RadioGroupWidget) { state.empty = !cast<NcursesUi::RadioGroupWidget>(widget).getOptions(); state.has_selection = state.selected == 1; }
        if (widget instanceof NcursesUi::ComboBoxWidget) { state.empty = !cast<NcursesUi::ComboBoxWidget>(widget).getOptions(); state.has_selection = state.text == "Execute"; }
        if (widget instanceof NcursesUi::DescribedChoiceWidget) {
            NcursesUi::DescribedChoiceWidget choice = cast<NcursesUi::DescribedChoiceWidget>(widget);
            state.empty = !choice.getItems(); state.has_selection = state.choice == "execute"; state.has_error = !!(choice.getError());
        }
        if (widget instanceof NcursesUi::ListWidget) { state.empty = !cast<NcursesUi::ListWidget>(widget).getItems(); state.has_selection = state.selected == 1; }
        if (widget instanceof NcursesUi::TreeWidget) {
            NcursesUi::TreeWidget tree = cast<NcursesUi::TreeWidget>(widget);
            state.empty = tree.getVisiblePaths().size() == 1; state.has_selection = tree.getSelectedPath() != tree.getVisiblePaths()[0];
        }
        if (widget instanceof NcursesUi::TextChartWidget) { state.empty = !cast<NcursesUi::TextChartWidget>(widget).getChart().getSamples(); }
        if (widget instanceof NcursesUi::MenuBarWidget) { state.empty = !cast<NcursesUi::MenuBarWidget>(widget).getMenus(); state.has_selection = state.active_menu == 0; }
        if (widget instanceof NcursesUi::DropdownMenuWidget) { state.empty = !cast<NcursesUi::DropdownMenuWidget>(widget).getMenuItems(); state.has_selection = state.highlight == 2; }
        if (widget instanceof NcursesUi::DialogWidget) {
            NcursesUi::DialogWidget dialog = cast<NcursesUi::DialogWidget>(widget);
            state.empty = join("", dialog.getMessageLines()) == ""; state.has_selection = dialog.getFocusedButton() == 1;
        }
        if (widget instanceof NcursesUi::StatusBarWidget) { state.empty = !cast<NcursesUi::StatusBarWidget>(widget).getSegments(); }
        if (widget instanceof NcursesUi::TimelineWidget) { state.empty = !cast<NcursesUi::TimelineWidget>(widget).getEventIds(); state.has_selection = state.event == "completed"; }
        if (widget instanceof NcursesUi::FileBrowserWidget) { state.has_selection = cast<NcursesUi::FileBrowserWidget>(widget).getSelectedFile().label == "sample.txt"; }
        if (widget instanceof NcursesUi::AttachmentWidget) { state.has_error = !!(cast<NcursesUi::AttachmentWidget>(widget).getError()); }
        if (form) { state.empty = form.getValue("name") == ""; state.has_error = !!(form.getErrors()); state.loading = form.getState() == NcursesUi::ActionState::Running; }
        if (action) { state.has_error = !!(action.getError()); state.loading = action.getState() == NcursesUi::ActionState::Running; }
        if (assistance) {
            state.empty = !assistance.getCompletions(); state.has_error = !!(assistance.getError()); state.loading = assistance.isPending();
            *hash<auto> selected = cast<NcursesUi::AssistancePopupWidget>(widget).getSelectedResult();
            state.selected_kind = selected ? selected.kind : "";
            state.has_selection = state.selected_kind == "signature";
        }
        if (files) { state.empty = !files.getFiles(); state.has_selection = files.getFiles() && files.isSelected("sample"); state.has_error = !!(files.getError()); }
        return state;
    }
    nothing close() {
        if (closed) { return; } closed = True;
        if (action && action.getState() == NcursesUi::ActionState::Running) { action.cancel(); }
        if (form && form.getState() == NcursesUi::ActionState::Running) { form.cancel(); }
        if (assistance) { assistance.cancel(); }
        if (widget instanceof NcursesUi::MenuBarWidget) { cast<NcursesUi::MenuBarWidget>(widget).closeMenu(); }
        if (panel) { panel.destroyPanel(); }
        if (widget instanceof NcursesUi::ButtonWidget) { cast<NcursesUi::ButtonWidget>(widget).setOnActivate(NOTHING); }
        if (widget instanceof NcursesUi::DescribedChoiceWidget) {
            cast<NcursesUi::DescribedChoiceWidget>(widget).resetSubmission(); cast<NcursesUi::DescribedChoiceWidget>(widget).setOnSubmit(NOTHING);
        }
        if (widget instanceof NcursesUi::FormWidget) { cast<NcursesUi::FormWidget>(widget).setOnSubmit(NOTHING); }
        if (widget instanceof NcursesUi::MenuBarWidget) { cast<NcursesUi::MenuBarWidget>(widget).setOnCommand(NOTHING); }
        if (widget instanceof NcursesUi::DropdownMenuWidget) {
            cast<NcursesUi::DropdownMenuWidget>(widget).setOnClose(NOTHING); cast<NcursesUi::DropdownMenuWidget>(widget).setOnSelect(NOTHING);
        }
        if (widget instanceof NcursesUi::DialogWidget) {
            cast<NcursesUi::DialogWidget>(widget).setOnButton(NOTHING); cast<NcursesUi::DialogWidget>(widget).setOnDismiss(NOTHING);
        }
        if (widget instanceof NcursesUi::AssistancePopupWidget) { cast<NcursesUi::AssistancePopupWidget>(widget).setOnDismiss(NOTHING); }
        if (widget instanceof NcursesUi::FileBrowserWidget) { cast<NcursesUi::FileBrowserWidget>(widget).setOnDismiss(NOTHING); }
        if (widget instanceof NcursesUi::ProgressWidget) { cast<NcursesUi::ProgressWidget>(widget).setOnStart(NOTHING); }
        if (files) { files.reset(); files.setHandler(NcursesUi::FileOperation::Open, NOTHING); }
        if (widget instanceof NcursesUi::AttachmentWidget) {
            NcursesUi::AttachmentWidget attachment = cast<NcursesUi::AttachmentWidget>(widget);
            attachment.reset(); attachment.setHandler(NcursesUi::FileOperation::Open, NOTHING); attachment.setHandler(NcursesUi::FileOperation::Export, NOTHING);
        }
        if (widget) { widget.setEnabled(False); }
    }
}
} # namespace NcursesGallery
