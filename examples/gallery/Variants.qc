# Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT
namespace NcursesGallery {
class Variants {
    static bool includes(list<string> names, string name) { foreach string item in (names) { if (item == name) { return True; } } return False; }
    static hash<string, string> applicability(string widget) {
        hash<string, string> result = {"default": "", "unicode": "", "constrained": ""};
        result.focused = includes(("LabelWidget", "StatusBarWidget"), widget) ? "N/A: read-only display does not accept focus" : "";
        result.disabled = includes(("LabelWidget", "StatusBarWidget", "DialogWidget", "DropdownMenuWidget", "CompletionPopupWidget", "AssistancePopupWidget", "FileBrowserWidget"), widget)
            ? "N/A: read-only display or transient overlay; availability is controlled by showing/dismissing it" : "";
        result.empty = includes(("ButtonWidget", "CheckboxWidget", "ProgressWidget", "FileBrowserWidget", "AttachmentWidget"), widget)
            ? "N/A: requires a labeled action, file metadata, or an existing directory; empty content is not a distinct usable state" : "";
        result.selected = includes(("LabelWidget", "TextInputWidget", "ButtonWidget", "FormWidget", "TextChartWidget", "StatusBarWidget", "ProgressWidget", "AttachmentWidget"), widget)
            ? "N/A: no independent selection model" : "";
        result.invalid = includes(("DescribedChoiceWidget", "FormWidget", "ProgressWidget", "FileSelectionWidget", "AttachmentWidget", "AssistancePopupWidget"), widget)
            ? "" : "N/A: no user validation state; malformed API arguments are covered by negative tests";
        result.loading = includes(("FormWidget", "ProgressWidget", "AssistancePopupWidget"), widget)
            ? "" : "N/A: synchronous presentation; loading belongs to the containing application";
        return result;
    }
    static list<hash<NcursesGallery::Story>> expand(list<hash<NcursesGallery::Story>> base) {
        list<hash<NcursesGallery::Story>> result = ();
        foreach hash<NcursesGallery::Story> original in (base) {
            hash<string, string> states = applicability(original.widget);
            string prefix = original.id.split(".")[0];
            foreach string state in (keys states) {
                if (states{state} == "") { states{state} = state == "default" ? original.id : prefix + "." + state; }
            }
            original.states = states;
            original.review_size = <Ncurses::Size>{"rows": 8, "cols": 40};
            result += original;
            foreach string state in (("empty", "focused", "selected", "disabled", "invalid", "loading", "unicode", "constrained")) {
                if (states{state}.find("N/A:") == 0) { continue; }
                hash<NcursesGallery::Story> story = original; story.id = states{state}; story.state = state;
                story.purpose = original.purpose + " State: " + state + ".";
                hash<auto> expected = {};
                switch (state) {
                    case "empty": expected.empty = True; break;
                    case "focused": expected.focus_nonempty = True; break;
                    case "selected": expected.has_selection = True; break;
                    case "disabled": expected.enabled = False; expected.focus = ""; expected.cursor = 0; break;
                    case "invalid": expected.has_error = True; break;
                    case "loading": expected.loading = True; if (story.widget == "FormWidget") { expected.cursor = 0; } break;
                    case "unicode": expected.contains = "界"; break;
                    case "constrained": story.geometry = original.review_size; expected.visible_content = True; break;
                }
                story.steps = (<NcursesGallery::Step>{"checkpoint": state, "instruction": story.purpose, "expected": expected},);
                if (state == "constrained") {
                    story.purpose = original.purpose + " Compact layout, extreme clipping, recovery and live interaction.";
                    story.steps += <NcursesGallery::Step>{"checkpoint": "stress", "instruction": "Shrink to 4 rows by 12 columns: an explicit clipping stress test, not a recommended working size.",
                        "size": <Ncurses::Size>{"rows": 4, "cols": 12}, "expected": {"visible_content": True}};
                    story.steps += <NcursesGallery::Step>{"checkpoint": "recover", "instruction": "Expand to the compact working layout; content and focus survive.",
                        "size": story.geometry, "expected": {"visible_content": True}};
                    if (original.steps.size() > 1) {
                        hash<NcursesGallery::Step> interaction = original.steps[1]; interaction.checkpoint = "interact";
                        story.steps += interaction;
                    }
                    hash<auto> restored = original.steps.size() > 1 ? original.steps[1].expected : original.steps[0].expected;
                    if (story.widget == "FormWidget") {
                        foreach hash<auto> target in (({"id": "count", "focus": "FormTextInputControl"}, {"id": "details", "focus": "FormCheckboxControl"}, {"id": "submit", "focus": "ButtonWidget"})) {
                            story.steps += <NcursesGallery::Step>{"checkpoint": target.id, "instruction": "Tab reveals the next field or action, scrolling the form as needed.",
                                "event": <Ncurses::InputEvent>{"type": Ncurses::InputType::Char, "ch": "\t"}, "expected": {"focus": target.focus, "visible_content": True}};
                        }
                        restored = {"activations": 1, "operation_state": NcursesUi::ActionState::Completed};
                        story.steps += <NcursesGallery::Step>{"checkpoint": "submitted", "instruction": "Activate the now-visible Submit action.", "event": Registry::key("KEY_ENTER"), "expected": restored + {"contains": "Submitted"}};
                    } else if (story.widget == "AttachmentWidget") {
                        restored = {"activations": 1, "operation_state": NcursesUi::ActionState::Completed};
                        story.steps += <NcursesGallery::Step>{"checkpoint": "opened", "instruction": "Open the fixture through its visible callback action.", "event": Registry::key("KEY_ENTER"), "expected": restored};
                    } else if (story.widget == "KeyValueWidget") {
                        restored = {"has_selection": True};
                        story.steps += <NcursesGallery::Step>{"checkpoint": "selected", "instruction": "Move from the root to its first property.", "event": Registry::key("KEY_DOWN"), "expected": restored};
                    } else if (story.widget == "FileBrowserWidget") {
                        story.steps += <NcursesGallery::Step>{"checkpoint": "files", "instruction": "Return to Files to choose the sample.", "event": Registry::key("KEY_F(7)"), "expected": {"focus": "ListWidget", "contains": "sample.txt"}};
                        story.steps += <NcursesGallery::Step>{"checkpoint": "selected", "instruction": "Select sample.txt to load its text preview.", "event": Registry::key("KEY_DOWN"), "expected": {"has_selection": True}};
                        restored = {"focus": "ScrollableWidget", "contains": "Gallery fixture"};
                        story.steps += <NcursesGallery::Step>{"checkpoint": "preview", "instruction": "Read the selected file in the full-width preview pane.", "event": Registry::key("KEY_F(7)"), "expected": restored};
                    } else if (story.widget == "DescribedChoiceWidget") {
                        restored = {"choice": "execute"};
                        story.steps += <NcursesGallery::Step>{"checkpoint": "chosen", "instruction": "Space commits the highlighted second choice.", "event": <Ncurses::InputEvent>{"type": Ncurses::InputType::Char, "ch": " "}, "expected": restored};
                    }
                    story.steps += <NcursesGallery::Step>{"checkpoint": "restore", "instruction": "Restore the original example size without resetting its state.",
                        "size": original.geometry, "expected": restored};
                }
                result += story;
            }
        }
        return result;
    }
}
} # namespace NcursesGallery
