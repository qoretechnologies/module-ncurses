# Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT
namespace NcursesGallery {
class Catalog {
    static list<hash<NcursesGallery::Story>> mouseScenarios(list<hash<NcursesGallery::Story>> definitions) {
        list<hash<NcursesGallery::Story>> result = ();
        foreach hash<NcursesGallery::Story> original in (definitions) {
            if (original.state != "default" || Variants::includes(("LabelWidget", "StatusBarWidget"), original.widget)) { continue; }
            hash<NcursesGallery::Story> story = original; story.state = "mouse";
            hash<auto> fixture = {}; fixture += original.fixture; story.fixture = fixture;
            story.id = original.id.split(".")[0] + ".mouse";
            story.purpose = "Exercise the visible mouse target for " + original.widget + ". " + original.mouse;
            int y = 0; int x = 3; int buttons = Ncurses::BUTTON1_CLICKED; hash<auto> expected;
            switch (original.widget) {
                case "TextEditorWidget": x = 1; expected = {"cursor_x": 1, "focus": "TextEditorWidget"}; break;
                case "TextInputWidget": x = 6; expected = {"cursor_x": 6, "focus": "TextInputWidget"}; break;
                case "TranscriptWidget": buttons = Ncurses::BUTTON4_PRESSED; expected = {"following": False, "scroll": 0}; break;
                case "CodeViewWidget":
                    story.fixture.text = strmul("int answer = 42;\n", 30); buttons = Ncurses::BUTTON5_PRESSED;
                    story.steps[0].expected = {"scroll": 0}; expected = {"scroll_min": 1}; break;
                case "ButtonWidget": expected = {"activations": 1}; break;
                case "CheckboxWidget": expected = {"checked": True}; break;
                case "RadioGroupWidget": y = 1; expected = {"selected": 1, "highlight": 1}; break;
                case "ComboBoxWidget":
                    story.fixture.text = "Execute"; story.steps[0].expected = {"text": "Execute"}; x = 1;
                    expected = {"cursor_x": 1, "text": "Execute"}; break;
                case "DescribedChoiceWidget": y = 4; expected = {"choice": "execute"}; break;
                case "FormWidget": y = 9; x = 3; expected = {"include_details": False}; break;
                case "ListWidget": y = 1; expected = {"selected": 1}; break;
                case "TableWidget": y = 2; expected = {"selected": 1}; break;
                case "TreeWidget":
                case "KeyValueWidget": y = 1; expected = {"has_selection": True}; break;
                case "TextChartWidget":
                    story.geometry = <Ncurses::Size>{"rows": 2, "cols": 30}; story.steps[0].expected = {"scroll": 0};
                    buttons = Ncurses::BUTTON5_PRESSED; expected = {"scroll_min": 1}; break;
                case "MenuBarWidget": expected = {"active_menu": 0, "modal": True}; break;
                case "DropdownMenuWidget": y = 5; x = 4; expected = {"activations": 1, "modal": False}; break;
                case "DialogWidget": y = 9; x = 24; expected = {"activations": 1, "modal": False}; break;
                case "CompletionPopupWidget": y = 4; x = 4; expected = {"selected": 1, "modal": True}; break;
                case "AssistancePopupWidget": y = 3; x = 10; expected = {"selected_kind": "signature"}; break;
                case "ProgressWidget": y = 2; expected = {"operation_state": NcursesUi::ActionState::Running, "contains": "25%"}; break;
                case "TimelineWidget": y = 2; expected = {"event": "completed"}; break;
                case "FileBrowserWidget": y = 2; expected = {"has_selection": True}; break;
                case "FileSelectionWidget": x = 1; expected = {"file_count": 1}; break;
                case "AttachmentWidget": y = 7; expected = {"activations": 1, "operation_state": NcursesUi::ActionState::Completed}; break;
                default: throw "GALLERY-STORY-ERROR", "Missing mouse review for " + original.widget;
            }
            story.steps = (story.steps[0], <NcursesGallery::Step>{"checkpoint": "mouse", "instruction": original.mouse,
                "event": <Ncurses::InputEvent>{"type": Ncurses::InputType::Mouse,
                    "mouse": <Ncurses::MouseEvent>{"y": y, "x": x, "button_state": buttons}}, "expected": expected});
            if (original.widget == "FormWidget") {
                story.steps = (story.steps[0],
                    <NcursesGallery::Step>{"checkpoint": "label", "instruction": "Click Attempts to focus its value without changing it.",
                        "event": <Ncurses::InputEvent>{"type": Ncurses::InputType::Mouse, "mouse": <Ncurses::MouseEvent>{"y": 4, "x": 4, "button_state": Ncurses::BUTTON1_CLICKED}}, "expected": {"focus": "FormTextInputControl", "cursor_x": 4}},
                    <NcursesGallery::Step>{"checkpoint": "help", "instruction": "Click the request description to return to its value.",
                        "event": <Ncurses::InputEvent>{"type": Ncurses::InputType::Mouse, "mouse": <Ncurses::MouseEvent>{"y": 1, "x": 4, "button_state": Ncurses::BUTTON1_CLICKED}}, "expected": {"focus": "FormTextInputControl", "cursor_x": 10}},
                    <NcursesGallery::Step>{"checkpoint": "checkbox-label", "instruction": "Click Include details to focus the checkbox without toggling it.",
                        "event": <Ncurses::InputEvent>{"type": Ncurses::InputType::Mouse, "mouse": <Ncurses::MouseEvent>{"y": 8, "x": 4, "button_state": Ncurses::BUTTON1_CLICKED}}, "expected": {"focus": "FormCheckboxControl", "include_details": True}},
                    story.steps[1]);
            }
            result += story;
        }
        return result;
    }
    static list<hash<NcursesGallery::Story>> scenarios(list<hash<NcursesGallery::Story>> definitions) {
        list<hash<NcursesGallery::Story>> result = ();
        foreach hash<NcursesGallery::Story> original in (definitions) {
            if (original.state != "default" || !Variants::includes(("TranscriptWidget", "ProgressWidget", "AssistancePopupWidget", "DescribedChoiceWidget"), original.widget)) { continue; }
            hash<NcursesGallery::Story> story = original; story.state = "scenario";
            if (story.widget == "DescribedChoiceWidget") {
                story.id = "described-choice.submit"; hash<auto> submit_fixture = {}; submit_fixture += story.fixture;
                submit_fixture.submit = True; story.fixture = submit_fixture;
                story.purpose = "Submit one reviewed choice. Enter completes this one-shot form; Reset story opens a fresh form.";
                story.keyboard = "Up/Down highlights; Space chooses; Enter submits once. Reset story starts again.";
                story.steps = (
                    <NcursesGallery::Step>{"checkpoint": "ready", "instruction": "Inspect the explained default choice.", "expected": {"choice": "preview", "operation_state": NcursesUi::ActionState::Pending}},
                    <NcursesGallery::Step>{"checkpoint": "highlight", "instruction": "Highlight Execute without submitting.", "event": Registry::key("KEY_DOWN"), "expected": {"highlight": 1, "choice": "preview"}},
                    <NcursesGallery::Step>{"checkpoint": "submitted", "instruction": "Submit Execute once; the live feedback explains how to restart.", "event": Registry::key("KEY_ENTER"), "expected": {"choice": "execute", "activations": 1, "operation_state": NcursesUi::ActionState::Completed}},
                    <NcursesGallery::Step>{"checkpoint": "duplicate", "instruction": "A repeated Enter does not submit again.", "event": Registry::key("KEY_ENTER"), "expected": {"activations": 1}}
                );
            } else if (story.widget == "TranscriptWidget") {
                story.id = "transcript.background-reading";
                story.purpose = "Preserve the reading anchor while background output arrives; resume explicitly.";
                story.geometry = <Ncurses::Size>{"rows": 4, "cols": 32};
                story.fixture.lines = ("History 01", "History 02", "History 03", "History 04", "History 05", "History 06", "History 07", "History 08");
                story.steps = (
                    <NcursesGallery::Step>{"checkpoint": "following", "instruction": "Start at the latest output.", "expected": {"following": True, "unread": 0, "scroll_min": 1}},
                    <NcursesGallery::Step>{"checkpoint": "reading", "instruction": "Home pauses following at the first line.", "event": Registry::key("KEY_HOME"), "expected": {"following": False, "scroll": 0}},
                    <NcursesGallery::Step>{"checkpoint": "background", "instruction": "Deliver two background lines without moving the reading anchor.", "action": "append-output", "expected": {"following": False, "scroll": 0, "unread": 2, "contains": "History 01"}},
                    <NcursesGallery::Step>{"checkpoint": "latest", "instruction": "End resumes following and clears unread feedback.", "event": Registry::key("KEY_END"), "expected": {"following": True, "unread": 0, "scroll_min": 1, "contains": "Background 10"}}
                );
            } else if (story.widget == "ProgressWidget") {
                story.id = "progress.cancel-stale";
                story.purpose = "Cancel an operation, retry, and reject a late result from the old attempt.";
                story.steps = (
                    <NcursesGallery::Step>{"checkpoint": "pending", "instruction": "Start from an idle operation.", "expected": {"operation_state": NcursesUi::ActionState::Pending}},
                    <NcursesGallery::Step>{"checkpoint": "running", "instruction": "Enter begins deterministic progress.", "event": Registry::key("KEY_ENTER"), "action": "remember-attempt", "expected": {"operation_state": NcursesUi::ActionState::Running, "contains": "25%"}},
                    <NcursesGallery::Step>{"checkpoint": "cancelled", "instruction": "C cancels with visible feedback.", "event": <Ncurses::InputEvent>{"type": Ncurses::InputType::Char, "ch": "c"}, "expected": {"operation_state": NcursesUi::ActionState::Cancelled, "contains": "Cancelled"}},
                    <NcursesGallery::Step>{"checkpoint": "retry", "instruction": "Enter starts a new attempt.", "event": Registry::key("KEY_ENTER"), "expected": {"operation_state": NcursesUi::ActionState::Running}},
                    <NcursesGallery::Step>{"checkpoint": "stale", "instruction": "Deliver the cancelled attempt's completion; current progress remains unchanged.", "action": "stale-progress", "expected": {"operation_state": NcursesUi::ActionState::Running, "stale_attempted": True, "stale_accepted": False, "contains": "25%"}}
                );
            } else {
                story.id = "assistance-popup.cancel-stale";
                story.purpose = "Dismiss pending assistance and reject a late provider result without changing the draft or focus.";
                story.steps = (
                    <NcursesGallery::Step>{"checkpoint": "pending", "instruction": "Begin a pending provider request.", "action": "request-assistance", "expected": {"loading": True, "modal": True}},
                    <NcursesGallery::Step>{"checkpoint": "dismiss", "instruction": "Escape cancels and restores the editor caret.", "event": <Ncurses::InputEvent>{"type": Ncurses::InputType::Char, "ch": "\e"}, "expected": {"loading": False, "modal": False, "focus": "TextEditorWidget", "cursor": 1}},
                    <NcursesGallery::Step>{"checkpoint": "stale", "instruction": "Deliver obsolete assistance; keep the unchanged draft and restored focus.", "action": "stale-assistance", "expected": {"stale_attempted": True, "stale_accepted": False, "text": "greet(na)", "focus": "TextEditorWidget", "modal": False, "cursor": 1}}
                );
            }
            result += story;
        }
        return result;
    }
    static hash<NcursesGallery::Story> entry(string id, string widget, string purpose, hash<auto> fixture,
            string keyboard, string mouse, hash<auto> expected, *hash<Ncurses::InputEvent> event, *hash<auto> after) {
        list<hash<NcursesGallery::Step>> steps = (<NcursesGallery::Step>{"checkpoint": "initial", "instruction": purpose, "expected": expected},);
        if (event) { steps += <NcursesGallery::Step>{"checkpoint": "interaction", "instruction": keyboard, "event": event, "expected": after ?? {}}; }
        return <NcursesGallery::Story>{"id": id + ".default", "widget": widget, "api": "NcursesUi::" + widget,
            "purpose": purpose, "catalog": True, "fixture": fixture, "geometry": <Ncurses::Size>{"rows": 16, "cols": 64},
            "keyboard": keyboard, "mouse": mouse, "states": {"default": "initial"}, "steps": steps};
    }
    static list<hash<NcursesGallery::Story>> stories() {
        hash<Ncurses::InputEvent> down = Registry::key("KEY_DOWN");
        hash<Ncurses::InputEvent> enter = Registry::key("KEY_ENTER");
        hash<Ncurses::InputEvent> space = <Ncurses::InputEvent>{"type": Ncurses::InputType::Char, "ch": " "};
        hash<Ncurses::InputEvent> escape = <Ncurses::InputEvent>{"type": Ncurses::InputType::Char, "ch": "\e"};
        list<hash<auto>> items = ({"label": "First", "id": "first"}, {"label": "Second", "id": "second"}, {"label": "Long " + strmul("content ", 10), "id": "long"});
        list<string> options = ("Preview", "Execute", "Inspect " + strmul("details ", 10));
        list<hash<NcursesUi::ChoiceItem>> choices = (
            <NcursesUi::ChoiceItem>{"value": "preview", "label": "Preview", "description": "Show the changes before applying them.", "recommendation": "Recommended first", "default_value": True},
            <NcursesUi::ChoiceItem>{"value": "execute", "label": "Execute", "description": "Apply the reviewed changes."},
            <NcursesUi::ChoiceItem>{"value": "unavailable", "label": "Unavailable", "description": "Requires a connected service.", "disabled": True});
        list<hash<auto>> menus = ({"label": "Open", "command": "open"}, {"label": "Unavailable", "command": "disabled", "enabled": False}, {"label": "Close", "command": "close"});
        list<string> transcript = ("First output", "Second output", "Last output");
        return (
            entry("label", "LabelWidget", "Read a wrapped label with adjacent explanatory text.", {"text": "Name\nChoose a short, recognizable name."},
                "Nonfocusable; Tab moves to an interactive control.", "Read-only; no activation target.", {"focus": "", "contains": "Choose a short"}),
            entry("text-input", "TextInputWidget", "Edit a labeled single-line value without losing Unicode characters.", {"text": "draft", "prompt": "Name: "},
                "Home/End and arrows move; Backspace deletes a grapheme; Enter submits.", "Click places the caret.", {"focus": "TextInputWidget", "text": "draft", "cursor": 1},
                <Ncurses::InputEvent>{"type": Ncurses::InputType::Paste, "ch": "Z"}, {"text": "draftZ"}),
            entry("transcript", "TranscriptWidget", "Read output with stable scroll position and search highlights.", {"lines": transcript},
                "Arrows/page keys scroll; Home/End reach history boundaries.", "Wheel scrolls without stealing focus.", {"contains": "First output", "scroll": 0}, Registry::key("KEY_HOME"), {"scroll": 0}),
            entry("code-view", "CodeViewWidget", "Inspect syntax-styled source and its plain-text representation.", {"text": "# Preview a calculation\nint answer = 42;\nprintf(\"%d\\n\", answer);", "language": "qore"},
                "Arrow/page keys scroll; source remains read-only.", "Wheel scrolls; drag selects text.", {"contains": "int answer", "scroll": 0}, Registry::key("KEY_HOME"), {"scroll": 0}),
            entry("button", "ButtonWidget", "Activate a clearly labeled action once per input.", {"label": "Run preview"},
                "Enter or Space activates; Tab moves focus.", "Primary click activates inside the button.", {"focus": "ButtonWidget", "activations": 0}, enter, {"activations": 1, "contains": "Preview complete"}),
            entry("checkbox", "CheckboxWidget", "Toggle an option with a mark that does not depend on color.", {"label": "Include details"},
                "Space toggles; Tab moves focus.", "Click the label or box to toggle.", {"checked": False}, space, {"checked": True}),
            entry("radio-group", "RadioGroupWidget", "Move highlight independently of the committed radio selection.", {"options": options},
                "Up/Down move highlight; Space commits; Home/End reach choices.", "Click chooses; wheel moves highlight.", {"selected": 0}, down, {"highlight": 1, "selected": 0}),
            entry("combo-box", "ComboBoxWidget", "Filter choices while retaining a visible editing caret.", {"options": options},
                "Type to filter; Down opens choices; Enter accepts; Escape closes.", "Click edits and selects a visible choice.", {"text": "", "cursor": 1},
                <Ncurses::InputEvent>{"type": Ncurses::InputType::Char, "ch": "P"}, {"text": "P"}),
            entry("described-choice", "DescribedChoiceWidget", "Choose an option: the filled circle marks selection; the highlighted title follows keyboard focus.", {"choices": choices},
                "Up/Down moves focus; Space, Enter or a click selects. Unavailable choices are skipped.", "Click chooses a described row.", {"choice": "preview", "contains": "Recommended first"}, down, {"choice": "preview"}),
            entry("form", "FormWidget", "Each field groups a bold label, help and a bounded value. Click the label or help to focus its value.", {"name": "Preview"},
                "Tab moves between fields and actions; Enter submits; Escape cancels.", "Click a label or description to focus its value; click a value to edit or an action to submit.", {"contains": "Request name"}),
            entry("list", "ListWidget", "Navigate labeled rows with an unambiguous current selection.", {"items": items},
                "Arrows, Home/End and page keys move selection; Enter activates.", "Click selects; double-click activates; wheel scrolls.", {"selected": 0, "scroll": 0}, down, {"selected": 1}),
            entry("tree", "TreeWidget", "Expand structured values using familiar directional navigation.", {"data": {"name": "Preview", "nested": {"enabled": True, "count": 3}}},
                "Right expands, Left collapses, Up/Down select, Enter activates.", "Click selects; wheel scrolls.", {"contains": "Root"}, Registry::key("KEY_RIGHT"), {"scroll": 0}),
            entry("key-value", "KeyValueWidget", "Inspect labeled scalar values and nested details.", {"data": {"name": "Preview", "count": 3}},
                "Tree navigation: arrows expand, collapse and select.", "Click selects; wheel scrolls.", {"contains": "Values"}),
            entry("text-chart", "TextChartWidget", "Read exact numeric summary alongside a bounded sparkline.", {"samples": (1.0, 4.0, NOTHING, 2.0, 8.0)},
                "Arrows and page keys scroll the summary.", "Wheel scrolls.", {"contains": "samples; min", "scroll": 0}),
            entry("menu-bar", "MenuBarWidget", "Discover menu commands and disabled choices.", {"menus": menus},
                "Alt+F opens File; arrows navigate; Escape closes.", "Click a menu label, then a command.", {"active_menu": -1},
                <Ncurses::InputEvent>{"type": Ncurses::InputType::Alt, "ch": "f"}, {"active_menu": 0, "modal": True}),
            entry("dropdown-menu", "DropdownMenuWidget", "Navigate an overlapping command menu while skipping disabled entries.", {"menus": menus},
                "Up/Down select enabled commands; Enter activates; Escape dismisses.", "Click a command; outside click dismisses.", {"modal": True, "contains": "Open"}, down, {"highlight": 2}),
            entry("dialog", "DialogWidget", "Read an explanation and deliberately choose an action.", {"message": "Apply the reviewed changes?\nThe current draft will be preserved.", "buttons": ("Apply", "Cancel")},
                "Tab selects actions; Enter activates; Escape dismisses. Up/Down or Page keys scroll a long message.", "Click a visible action or close control.", {"modal": True, "contains": "Apply"}, escape, {"modal": False}),
            entry("assistance-popup", "AssistancePopupWidget", "Read ranked completion help anchored to the editor caret.", {"text": "greet(na)", "completion": "name"},
                "Type filters; Tab reaches documentation; Enter applies; Escape cancels.", "Click a result; wheel scrolls documentation.", {"modal": True, "contains": "name"}, escape, {"modal": False, "text": "greet(na)"}),
            entry("status-bar", "StatusBarWidget", "Read compact key help and state without requiring color.", {"segments": ({"text": "F1 Help"}, {"text": "Ready"}, {"text": "UTF-8"})},
                "Read-only; the application handles displayed shortcuts.", "Read-only status segments.", {"focus": "", "contains": "F1 Help"}),
            entry("progress", "ProgressWidget", "Start a controlled operation and display truthful progress with cancellation.", {"label": "Preview operation"},
                "Enter starts/retries; C or Escape cancels an active operation.", "Click the displayed start/cancel action.", {"operation_state": NcursesUi::ActionState::Pending}, enter, {"operation_state": NcursesUi::ActionState::Running, "contains": "25%"}),
            entry("timeline", "TimelineWidget", "Review timestamped operation history and expand event details.", {"timestamp": "2026-01-02T03:04:05Z"},
                "Up/Down select events; Enter/Space toggles details.", "Wheel scrolls history; click selects.", {"event": "started", "contains": "2026-01-02"}, down, {"event": "completed"}),
            entry("file-browser", "FileBrowserWidget", "Browse repository-owned sample files and a bounded text preview.", {"directory": "examples/gallery/fixtures"},
                "Arrows select; Enter/Tab opens a directory; Shift+Tab goes back; F7 switches panes; Escape dismisses.", "Click files or preview entries; wheel scrolls the active pane.", {"modal": True, "contains": "sample.txt"}, Registry::key("KEY_F(7)"), {"focus": "ScrollableWidget", "contains": "Select a file"}),
            entry("file-selection", "FileSelectionWidget", "Select fixture metadata without modifying files.", {"files": (
                <NcursesUi::FileSelectionEntry>{"id": "sample", "name": "sample.txt", "path": "fixture/sample.txt", "size": 64, "type": "text/plain"},
                <NcursesUi::FileSelectionEntry>{"id": "missing", "name": "missing.txt", "path": "fixture/missing.txt", "error": "File was removed"})},
                "Arrows highlight; Space selects; Enter opens through the fixture handler.", "Click selects; wheel scrolls.", {"contains": "sample"}, space, {"file_count": 1}),
            entry("attachment", "AttachmentWidget", "Read attachment metadata, text preview and explicit operation feedback.", {"attachment": <NcursesUi::AttachmentInfo>{"id": "sample", "name": "sample.txt", "path": "fixture/sample.txt", "size": 64, "type": "text/plain", "text_preview": "A readable preview.\nNo user files are changed."}},
                "Enter opens; E exports through a callback; arrows/page keys scroll.", "Click a displayed action; wheel scrolls.", {"contains": "readable preview", "operation_state": NcursesUi::ActionState::Pending})
        );
    }
}
} # namespace NcursesGallery
