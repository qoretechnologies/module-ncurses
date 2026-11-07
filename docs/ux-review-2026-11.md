# Widget interaction and visual review — November 2026

Copyright 2026 Qore Technologies, s.r.o.

Reviewer: Codex, using native PTY interaction, browser keyboard/paste/mouse input,
composed-frame inspection and rendered-image inspection. This is an agent review,
not a human participant study. Automated state assertions support the observations;
they do not establish subjective usability by themselves.

Scope: all 27 concrete public widgets and their shared Widget, PanelWidget and
ScrollableWidget behavior. The executable catalog covers default, empty, focused,
selected, disabled, invalid, loading, Unicode/long-content and constrained states
where applicable. Its explicit N/A reasons remain the source of truth. All 25
interactive widgets have mouse scenarios; Label and StatusBar are read-only. Every
registered checkpoint runs in color and monochrome; each default additionally runs
at 4×12, 24×80 and 32×120. Tiny views are intentionally clipped: keyboard navigation,
scrolling and resizing expose content that cannot fit simultaneously.

The checked-in [baseline manifest](../review/baselines/manifest.json) identifies the
exact artifact set, geometry/configuration, browser/font versions, hashes and this
review's acceptance digest. Each PNG has a neighboring `.json.gz` artifact with the
full native cell/attribute/cursor/focus/scroll state. The
[review instructions](../review/README.md) reproduce baseline/current/diff reports.

## Findings and disposition

- [#5622](https://github.com/qoretechnologies/qore/issues/5622): visible mouse action
  targets were inconsistent. Button/checkbox hit tests now exclude unrelated blank
  rows, padding and clipped areas; disabled/ancestor-disabled actions render dim.
  Checkbox activation accepts Enter key, newline and carriage-return reports.
  Attachment labels dispatch through normalized source spans after wrap/scroll.
  Completion popups now select by click, navigate by wheel, accept by double-click,
  and recognize Enter as either a key or carriage return. Timeline/file-selection
  controls accept real press/release reports, with no repeat on release. Dedicated
  native regressions and all-widget PTY replay cover these fixes.
- [#5623](https://github.com/qoretechnologies/qore/issues/5623): the file preview was
  mouse-reachable but lacked a keyboard focus transition. F7 now switches panes and
  is displayed in the status/help text. Existing Tab/Shift+Tab directory navigation
  is preserved. Managed focus and unavailable-pane regressions pass.
- Browser font review found oversized box-drawing fallback glyphs. Complete pinned
  Noto Sans Mono fonts replace incomplete web subsets; a glyph-advance regression
  checks border/selection symbols against one terminal cell. Panel bounds now agree
  with the composed frame. DOM font rendering can leave small vertical border joins;
  this is an explicit renderer characteristic, not missing cells or misplaced panels.
- Disabled/loading image review found the gallery applied nonmodal cursor policy
  before state transitions reconciled focus. The runner now sets cursor visibility
  after final focus state and event-loop transitions; disabled controls, non-editing
  focus targets and a submitting form no longer display a stale editing caret.
  Shared checkpoints and a native event-loop regression cover this policy.
- Development integration found missing WebSocket upgrades in Storybook's Vite
  middleware mode. Supplying the owning HTTP server fixes the proxy. Generated
  artifact directories are excluded from HMR so review output cannot reload an
  active story. The documented development command is tested end to end.
- Cross-platform CI found fractional terminal placement from surrounding system-font
  line boxes. Integer line heights and block placement now keep captures on device
  pixels; varying surrounding fonts and wrapping leaves terminal images identical.
  The manifest records browser and native locales separately and fingerprints styles.
  The reviewed correction preserves all 1,098 semantic artifacts; 644 PNGs lose
  one fractional-placement row, with unchanged widths. Representative corrected
  images from all 16 affected widget groups were inspected before acceptance.
- Protocol review added browser serialization through actual render completion,
  fatal input-error teardown, and bounded incoming/outgoing WebSocket queues.
  Held-render, queued-disposal, throwing-callback and resource-bound regressions
  cover these failure and overlap paths.
- Foundation issue [#5621](https://github.com/qoretechnologies/qore/issues/5621) was
  fixed and merged before this review: base-only scenes are staged when no visible
  native panel exists, preserving libpanel overlap propagation otherwise.

No widget finding is deferred. The separately tracked upstream unknown-terminal
ncurses leak [#5612](https://github.com/qoretechnologies/qore/issues/5612) remains
outside this roadmap; no suppression or workaround is included.

## Per-widget observations

The evidence links show a representative monochrome frame or interaction result.
The manifest and generated catalog identify the other states and size variants.
“Accepted” means the reviewed fixture meets the criteria below after the linked
fixes; it is not a claim about every possible application composition.

| Widget | Observed interaction and presentation | Disposition / representative evidence |
| --- | --- | --- |
| Label | Wrapped explanatory text stays inside the viewport. It takes no focus; tiny views show a bounded prefix and resizing reveals the rest. | Accepted; [monochrome](../review/baselines/label.default.mono.standard.mounted.png). |
| TextInput | The prompt remains adjacent to the value; Unicode paste and mouse caret placement preserve text. Narrow views keep the editing caret visible. | Accepted; [mouse caret](../review/baselines/text-input.mouse.mono.registered.mouse.png). |
| TextEditor | Exact-width/bottom-right editing keeps an insertion row; wide/combining paste is one undo unit. Shrink retains focus/caret and reveals the active line. | Accepted; [shrink checkpoint](../review/baselines/text-editor.boundaries.mono.registered.shrink.png). |
| Transcript | Home pauses following; two delivered background lines preserve the reading anchor and increment unread state. End resumes and clears unread feedback. Wheel navigation works through the PTY. | Accepted; [background checkpoint](../review/baselines/transcript.background-reading.mono.registered.background.png). |
| CodeView | Source stays read-only. Keyboard and wheel scrolling expose long content; Unicode source remains legible without relying on syntax color. | Accepted; [mouse scroll](../review/baselines/code-view.mouse.mono.registered.mouse.png). |
| Button | The labeled action activates once. Clicks on blank layout space no longer activate it; disabled/ancestor-disabled actions are dim and inert. | Accepted after #5622; [mouse action](../review/baselines/button.mouse.mono.registered.mouse.png). |
| Checkbox | The box mark communicates state without color, and the label is clickable. Padding/outside clicks are inert; disabled state is visibly dim. | Accepted after #5622; [disabled](../review/baselines/checkbox.disabled.mono.registered.mounted.png). |
| RadioGroup | Arrow highlight and committed selection remain distinct. Clicking a row selects it; the `(o)` marker and bold emphasis work in monochrome. Long labels clip to the available row. | Accepted; [mouse selection](../review/baselines/radio-group.mouse.mono.registered.mouse.png). |
| ComboBox | Typing filters options; the caret and dropdown marker remain visible. Mouse placement edits the intended position without corrupting Unicode or selection. | Accepted; [mouse caret](../review/baselines/combo-box.mouse.mono.registered.mouse.png). |
| DescribedChoice | The recommended default explains its reason beside the choice. Disabled alternatives explain availability. Error text is adjacent and selection survives validation. | Accepted; [invalid](../review/baselines/described-choice.invalid.mono.registered.mounted.png). |
| Form | Labels, required mark, defaults, help and field errors stay together. Tab navigation and mouse checkbox edits reach the same controls; submission shows explicit progress and a cancellation action. | Accepted; [field error](../review/baselines/form.invalid.mono.registered.mounted.png). |
| List | Arrows and mouse select the same row. Reverse selection remains clear in monochrome; long rows clip and scrolling preserves selection. | Accepted; [mouse selection](../review/baselines/list.mouse.mono.registered.mouse.png). |
| Table | End reveals the last row; shrinking keeps it on screen, and Home returns to the start. Headers remain distinguishable from the selected row through weight and content. | Accepted; [last row after shrink](../review/baselines/table.scrolling.mono.registered.shrink.png). |
| Tree | Directional expansion and row selection expose nested values; disclosure marks communicate hierarchy without color. A mouse row click updates the selected path. | Accepted; [mouse selection](../review/baselines/tree.mouse.mono.registered.mouse.png). |
| KeyValue | Labels and scalar values align under a visible root; keyboard/tree behavior and row selection remain consistent with Tree. | Accepted; [mouse selection](../review/baselines/key-value.mouse.mono.registered.mouse.png). |
| TextChart | The numeric summary states sample count, extrema, latest value and gaps; `?` is explained. Narrow views scroll the summary rather than inventing a graphical scale. | Accepted; [narrow scroll](../review/baselines/text-chart.mouse.mono.registered.mouse.png). |
| MenuBar | The underlined mnemonic and File label remain discoverable without color. Alt+F and clicking the title open the same menu; Escape restores the underlying focus. | Accepted; [mouse opening](../review/baselines/menu-bar.mouse.mono.registered.mouse.png). |
| DropdownMenu | Disabled entries are dim and skipped by arrows. Clicking a visible enabled command invokes it and dismisses the overlay. Borders and background restoration match native composition. | Accepted; [command result](../review/baselines/dropdown-menu.mouse.mono.registered.mouse.png). |
| Dialog | The question and distinct Apply/Cancel labels explain the decision. Tab/Enter/Escape and mouse activation retain deliberate action semantics; tiny views keep actions keyboard reachable. | Accepted; [monochrome](../review/baselines/dialog.default.mono.standard.mounted.png). |
| CompletionPopup | Single click changes highlight; double-click/Enter accept. Wheel and keyboard navigation agree. Escape/outside dismissal restore the draft's focus/cursor and remove overlay pixels. | Accepted after #5622; [dismissal](../review/baselines/completion-popup.overlap.mono.registered.dismiss.png). |
| AssistancePopup | Ranked results and nearby documentation explain the offered completion. Empty/error/loading text is explicit. Dismissing a pending request restores editing and rejects a late result. | Accepted; [stale result rejected](../review/baselines/assistance-popup.cancel-stale.mono.registered.stale.png). |
| StatusBar | Short key help, state and encoding remain readable as text without color. It does not steal focus or imply an activation target. Tiny views clip the trailing segments. | Accepted; [monochrome](../review/baselines/status-bar.default.mono.standard.mounted.png). |
| Progress | Pending, Running, Cancelled and Failed states use explicit words. The 25% display corresponds to one of four units; cancellation/retry rejects an old completion without replacing current progress. | Accepted; [stale completion](../review/baselines/progress.cancel-stale.mono.registered.stale.png). |
| Timeline | Fixed timestamps and state words distinguish events. Keyboard and actual press/release mouse selection agree; details remain attached to their event. | Accepted after #5622; [mouse selection](../review/baselines/timeline.mouse.mono.registered.mouse.png). |
| FileBrowser | Selecting the fixture file shows its bounded preview. F7 now reaches the preview by keyboard and returns to the list; Tab/back retain directory semantics. Status text exposes the binding. | Accepted after #5623; [pane focus](../review/baselines/file-browser.default.mono.registered.interaction.png). |
| FileSelection | Selection marks, count and unavailable-file explanation remain visible. Real mouse press/release toggles once; failed validation keeps selection and shows a specific error. | Accepted after #5622; [validation](../review/baselines/file-selection.invalid.mono.registered.mounted.png). |
| Attachment | Name/path/type/size and text preview explain the item. Displayed Open/Export labels now support mouse dispatch after wrapping and scrolling; cancellation/failure retains metadata. | Accepted after #5622; [mouse action](../review/baselines/attachment.mouse.mono.registered.mouse.png). |

## Criteria and practical limits

The review applies familiar navigation and focus restoration, searchable/manageable
choices, explained defaults, adjacent help/errors, usable visible mouse targets,
non-color emphasis, and truthful progress. These observations implement the
[documented UX criteria](../review/README.md#review-criteria), informed by Laws of
UX. There is no seven-choice cap or intentional typing delay; the 400 ms threshold
is not used as an acceptable typing latency target.

Actual native PTY input was compared with headless/injected events for every default
and mouse story. The editor/table/popup pilots also used browser keyboard events,
paste, mouse coordinates and resize, with direct inspection of terminal images.
Native gallery smoke checks retain the standalone workflow and overlay/resize
behavior. The semantic composition agrees across these paths. Browser rasterization
is specifically the pinned Linux Chromium/DOM-font presentation; another terminal
may use different glyphs, emoji widths, palette approximations or attribute support.
ACS codes/attributes and wide-cell continuations remain in the semantic artifact,
so those differences are visible rather than normalized away. Browser-reserved
shortcuts must be reviewed in the native gallery.

The source and compiled-mode QUnit gates, tooling tests, catalog drift checks,
documentation checks and platform CI evidence are linked in the delivery PR and
central roadmap issues. Acceptance is performed only after reviewing the complete
capture set and the fixes above; the acceptance command itself cannot establish
usability or authorize a merge.
