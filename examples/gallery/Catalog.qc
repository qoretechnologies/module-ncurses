# Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT
namespace NcursesGallery {
class Catalog {
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
        list<hash<auto>> items = ({"label": "First 界é", "id": "first"}, {"label": "Second", "id": "second"}, {"label": "Long " + strmul("content ", 10), "id": "long"});
        list<string> options = ("Preview 界é", "Execute", "Inspect " + strmul("details ", 10));
        list<hash<NcursesUi::ChoiceItem>> choices = (
            <NcursesUi::ChoiceItem>{"value": "preview", "label": "Preview 界é", "description": "Show the changes before applying them.", "recommendation": "Recommended first", "default_value": True},
            <NcursesUi::ChoiceItem>{"value": "execute", "label": "Execute", "description": "Apply the reviewed changes."},
            <NcursesUi::ChoiceItem>{"value": "unavailable", "label": "Unavailable", "description": "Requires a connected service.", "disabled": True});
        list<hash<auto>> menus = ({"label": "Open", "command": "open"}, {"label": "Unavailable", "command": "disabled", "enabled": False}, {"label": "Close", "command": "close"});
        list<string> transcript = ("First output 界é", "Second output", "Last output");
        return (
            entry("label", "LabelWidget", "Read a wrapped label with adjacent explanatory text.", {"text": "Name 界é\nChoose a short, recognizable name."},
                "Nonfocusable; Tab moves to an interactive control.", "Read-only; no activation target.", {"focus": "", "contains": "Choose a short"}),
            entry("text-input", "TextInputWidget", "Edit a labeled single-line value without losing Unicode characters.", {"text": "draft 界é", "prompt": "Name: "},
                "Home/End and arrows move; Backspace deletes a grapheme; Enter submits.", "Click places the caret.", {"focus": "TextInputWidget", "text": "draft 界é", "cursor": 1},
                <Ncurses::InputEvent>{"type": Ncurses::InputType::Paste, "ch": "Z"}, {"text": "draft 界éZ"}),
            entry("transcript", "TranscriptWidget", "Read output with stable scroll position and search highlights.", {"lines": transcript},
                "Arrows/page keys scroll; Home/End reach history boundaries.", "Wheel scrolls without stealing focus.", {"contains": "First output", "scroll": 0}, Registry::key("KEY_HOME"), {"scroll": 0}),
            entry("code-view", "CodeViewWidget", "Inspect syntax-styled source and its plain-text representation.", {"text": "# Unicode 界é\nint answer = 42;\nprintf(\"%d\\n\", answer);", "language": "qore"},
                "Arrow/page keys scroll; source remains read-only.", "Wheel scrolls; drag selects text.", {"contains": "int answer", "scroll": 0}, Registry::key("KEY_HOME"), {"scroll": 0}),
            entry("button", "ButtonWidget", "Activate a clearly labeled action once per input.", {"label": "Run preview 界é"},
                "Enter or Space activates; Tab moves focus.", "Primary click activates inside the button.", {"focus": "ButtonWidget", "activations": 0}, enter, {"activations": 1}),
            entry("checkbox", "CheckboxWidget", "Toggle an option with a mark that does not depend on color.", {"label": "Include details 界é"},
                "Space toggles; Tab moves focus.", "Click the label or box to toggle.", {"checked": False}, space, {"checked": True}),
            entry("radio-group", "RadioGroupWidget", "Move highlight independently of the committed radio selection.", {"options": options},
                "Up/Down move highlight; Space commits; Home/End reach choices.", "Click chooses; wheel moves highlight.", {"selected": 0}, down, {"highlight": 1, "selected": 0}),
            entry("combo-box", "ComboBoxWidget", "Filter choices while retaining a visible editing caret.", {"options": options},
                "Type to filter; Down opens choices; Enter accepts; Escape closes.", "Click edits and selects a visible choice.", {"text": "", "cursor": 1},
                <Ncurses::InputEvent>{"type": Ncurses::InputType::Char, "ch": "P"}, {"text": "P"}),
            entry("described-choice", "DescribedChoiceWidget", "Read the reason for the default and compare described alternatives.", {"choices": choices},
                "Up/Down highlight; Space chooses; Enter submits; disabled choices are skipped.", "Click chooses a described row.", {"choice": "preview", "contains": "Recommended first"}, down, {"choice": "preview"}),
            entry("form", "FormWidget", "Keep labels, defaults, help and validation next to editable fields.", {"name": "Preview 界é"},
                "Tab moves between fields and actions; Enter submits; Escape cancels.", "Click a field to edit or an action to submit.", {"contains": "Request name"}),
            entry("list", "ListWidget", "Navigate labeled rows with an unambiguous current selection.", {"items": items},
                "Arrows, Home/End and page keys move selection; Enter activates.", "Click selects; double-click activates; wheel scrolls.", {"selected": 0, "scroll": 0}, down, {"selected": 1}),
            entry("tree", "TreeWidget", "Expand structured values using familiar directional navigation.", {"data": {"name": "Preview 界é", "nested": {"enabled": True, "count": 3}}},
                "Right expands, Left collapses, Up/Down select, Enter activates.", "Click selects; wheel scrolls.", {"contains": "Root"}, Registry::key("KEY_RIGHT"), {"scroll": 0}),
            entry("key-value", "KeyValueWidget", "Inspect labeled scalar values and nested details.", {"data": {"name": "Preview 界é", "count": 3}},
                "Tree navigation: arrows expand, collapse and select.", "Click selects; wheel scrolls.", {"contains": "Values"}),
            entry("text-chart", "TextChartWidget", "Read exact numeric summary alongside a bounded sparkline.", {"samples": (1.0, 4.0, NOTHING, 2.0, 8.0)},
                "Arrows and page keys scroll the summary.", "Wheel scrolls.", {"contains": "samples; min", "scroll": 0}),
            entry("menu-bar", "MenuBarWidget", "Discover menu commands and disabled choices.", {"menus": menus},
                "Alt+F opens File; arrows navigate; Escape closes.", "Click a menu label, then a command.", {"active_menu": -1},
                <Ncurses::InputEvent>{"type": Ncurses::InputType::Alt, "ch": "f"}, {"active_menu": 0, "modal": True}),
            entry("dropdown-menu", "DropdownMenuWidget", "Navigate an overlapping command menu while skipping disabled entries.", {"menus": menus},
                "Up/Down select enabled commands; Enter activates; Escape dismisses.", "Click a command; outside click dismisses.", {"modal": True, "contains": "Open"}, down, {"highlight": 2}),
            entry("dialog", "DialogWidget", "Read an explanation and deliberately choose an action.", {"message": "Apply the reviewed changes?\nThe current draft 界é will be preserved.", "buttons": ("Apply", "Cancel")},
                "Tab selects actions; Enter activates; Escape dismisses.", "Click a visible action or close control.", {"modal": True, "contains": "Apply"}, escape, {"modal": False}),
            entry("assistance-popup", "AssistancePopupWidget", "Read ranked completion help anchored to the editor caret.", {"text": "greet(na)", "completion": "name"},
                "Type filters; Tab reaches documentation; Enter applies; Escape cancels.", "Click a result; wheel scrolls documentation.", {"modal": True, "contains": "name"}, escape, {"modal": False, "text": "greet(na)"}),
            entry("status-bar", "StatusBarWidget", "Read compact key help and state without requiring color.", {"segments": ({"text": "F1 Help"}, {"text": "Ready 界é"}, {"text": "UTF-8"})},
                "Read-only; the application handles displayed shortcuts.", "Read-only status segments.", {"focus": "", "contains": "F1 Help"}),
            entry("progress", "ProgressWidget", "Start a controlled operation and display truthful progress with cancellation.", {"label": "Preview operation 界é"},
                "Enter starts/retries; C or Escape cancels an active operation.", "Click the displayed start/cancel action.", {"operation_state": NcursesUi::ActionState::Pending}, enter, {"operation_state": NcursesUi::ActionState::Running, "contains": "25%"}),
            entry("timeline", "TimelineWidget", "Review timestamped operation history and expand event details.", {"timestamp": "2026-01-02T03:04:05Z"},
                "Up/Down select events; Enter/Space toggles details.", "Wheel scrolls history; click selects.", {"event": "started", "contains": "2026-01-02"}, down, {"event": "completed"}),
            entry("file-browser", "FileBrowserWidget", "Browse repository-owned sample files and a bounded text preview.", {"directory": "examples/gallery/fixtures"},
                "Arrows select; Enter opens a directory; Tab switches preview; Escape dismisses.", "Click files or preview entries; wheel scrolls the active pane.", {"modal": True, "contains": "sample.txt"}),
            entry("file-selection", "FileSelectionWidget", "Select fixture metadata without modifying files.", {"files": (
                <NcursesUi::FileSelectionEntry>{"id": "sample", "name": "sample 界é.txt", "path": "fixture/sample.txt", "size": 64, "type": "text/plain"},
                <NcursesUi::FileSelectionEntry>{"id": "missing", "name": "missing.txt", "path": "fixture/missing.txt", "error": "File was removed"})},
                "Arrows highlight; Space selects; Enter opens through the fixture handler.", "Click selects; wheel scrolls.", {"contains": "sample"}, space, {"file_count": 1}),
            entry("attachment", "AttachmentWidget", "Read attachment metadata, text preview and explicit operation feedback.", {"attachment": <NcursesUi::AttachmentInfo>{"id": "sample", "name": "sample 界é.txt", "path": "fixture/sample.txt", "size": 64, "type": "text/plain", "text_preview": "A readable preview.\nNo user files are changed."}},
                "Enter opens; E exports through a callback; arrows/page keys scroll.", "Click a displayed action; wheel scrolls.", {"contains": "readable preview", "operation_state": NcursesUi::ActionState::Pending})
        );
    }
}
} # namespace NcursesGallery
