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
at 4×12, 24×80 and 32×120. Constrained stories start at a usable compact 8×40,
shrink to the 4×12 stress size, recover, perform a meaningful interaction and restore
the original geometry while preserving the result. Stress sizes are not a recommended
minimum: a useful visible prefix or editing caret, bounded rendering and recovery
are required; simultaneous display of all content is not possible there.

The checked-in [baseline manifest](../review/baselines/manifest.json) identifies the
exact artifact set, geometry/configuration, browser/font versions, hashes and this
review's acceptance digest. Each PNG has a neighboring `.json.gz` artifact with the
full native cell/attribute/cursor/focus/scroll state. The
[review instructions](../review/README.md) reproduce baseline/current/diff reports.
The current capture contains 1,388 checkpoints from 213 stories. It retains all
1,358 keys from the preceding widget follow-up and adds 30 checkpoints for the
actual qrepl application. Fourteen existing popup checkpoints change to keep the
source/caret visible and show the shared Qore completion metadata; the other 1,344
match exactly. All 2,776 current artifact hashes were verified before acceptance.
The prior Forms/Progress/Table/TextChart follow-up added 14 checkpoints and changed
209 existing checkpoints; the observations below retain that review evidence.
Native state assertions and rendered-image inspection precede explicit acceptance.

## Findings and disposition

- [#5631](https://github.com/qoretechnologies/qore/issues/5631): qrepl now consumes
  reusable `EditorAssistance`, `BackgroundTask`, `Dialogs`, centered-panel sizing,
  adaptive status segments and the optional `NcursesQore::CodeSupport` adapter.
  General editor/workflow APIs do not depend on the Qore evaluator.
  - The real application is embedded in five executable stories: evaluation,
    completion, error recovery, a constrained viewport and file workflows. These
    run the same `bin/qrepl` implementation through a PTY with its continuous event
    loop, including output arriving between browser commands.
  - Tab opens live-session completion with signatures and exact replacement ranges;
    Escape removes the popup and restores the draft/caret. Source coloring remains
    readable in monochrome. F1 explains keys, F6 switches editor/output, and Alt+F
    opens the File menu without conflicting with word movement.
  - Evaluation runs off the UI thread with one outstanding request. A FIFO-gated
    native-browser test observes streamed output, edits the draft, resizes and
    cancels a quit confirmation while evaluation is still blocked. Releasing the
    gate and joining explicitly proves completion preserves the newer draft.
    Status says Evaluating, Ready, Error or Paused with an unread count; narrow
    layouts prioritize state over secondary hints. There is no cancellation claim:
    “Finish and quit” waits for the running evaluator before exit.
  - Save uses a labeled, validated filename form and overwrite confirmation. Load
    uses the shared file browser. Mouse/keyboard field behavior, cancel/focus
    restoration, ordinary-file activation, Unicode paths and actual save/load
    are covered by the controller and application tests. The upstream backend's
    missing-terminator export defect was separately authorized for correction in
    Qore; module tests also exercise complete source on the existing backend.
  - All 30 new captures (24 distinct images) and all 14 changed existing captures
    (eight distinct images) were inspected in color and monochrome. The 4×12
    stress story keeps the editing line or Paused state visible; it does not claim
    simultaneous access to every menu/status label at that size. The filename
    prompt keeps its label/help/value/actions grouped and restores the draft on
    cancel. A browser keyboard review of the actual completion story confirmed
    opening, legible selection/documentation and a visible source line.

- [#5629](https://github.com/qoretechnologies/qore/issues/5629): user review found
  weak progress emphasis, table headers resembling selection, and an unexplained
  ASCII chart ramp. The compact chart also needed an explicitly larger view.
  - Progress now uses semantic state colors, bold filled bar segments and exact
    counts, dim remaining segments/timestamps, and a distinct focused action.
    Explicit state words and bar characters preserve meaning in monochrome.
    Native tests cover all lifecycle states, focus/availability invalidation and
    ANSI-free `getStatusLines()`; browser input starts, cancels and retries work.
  - Tables use bold underlined cyan headers, separate from reverse-video selection.
    Focus adds emphasis to selection and disabled rows are dim. Keyboard End,
    mouse selection, shrink and recovery preserve the selected row.
  - Charts default to Unicode bars with explicit min/max and missing-sample legends;
    the ASCII story explains its complete intensity ramp. The Expanded story uses
    `setChartHeight(6)` and wider bars. Height supports 1–64 rows, with eight vertical
    sublevels per Unicode row and whole-row ASCII bars. Heights normalize the
    snapshot minimum to maximum, with constant samples at mid-height; this is not
    a zero-baseline chart. Missing values keep gaps, narrow views retain endpoints
    when possible, and wider bars never interpolate additional samples.
  - All 166 Progress/Table/TextChart captures (69 distinct images) were inspected,
    including color/monochrome, disabled, empty, Unicode, mouse and constrained
    states. Expanded bars and the gap marker are legible; narrow views scroll the
    summary/legend and recover on resize. The complete capture changes 151 existing
    checkpoints and adds eight chart checkpoints relative to the accepted form
    set; all 64 form captures and the other 1,135 checkpoints still match exactly.
    Native boundary tests cover zero/tiny widths, 64-row scrolling, invalid heights,
    finite extremes, constant data and gaps. Browser input reviews compact, ASCII
    and expanded charts in both color modes, including scroll and resize recovery.
  - PR review found that chart restyling replaced stable line identities and reset
    a scrolled viewport. Same-size updates now preserve those identities. A failing
    regression was reproduced, then passed for compact/64-row charts, direct and
    inherited availability changes, expanded glyph-mode switches and both color
    modes. Explicit snapshot replacement still returns to the summary.
- [#5628](https://github.com/qoretechnologies/qore/issues/5628): user review found
  that the form's label/value/help sequence looked like unrelated plain lines, and
  clicking a label or description did not focus its value. The earlier Form
  acceptance checked adjacency and reachability without establishing clear grouping.
  - Fields now show bold cyan headings, short help, any explicit red `Error:` text,
    then the value, with a blank row between fields. Text values have brackets even
    when empty; multiline values have side rails. A leading `>` identifies the
    focused field, and read-only fields have an explicit label. Color is supported
    by order, spacing, weight, boundaries and text cues in monochrome.
  - Clicking a label, description or error focuses the associated control through
    the existing scoped dispatcher without modifying the value, moving its retained
    caret or toggling a checkbox. Tests cover wrapped/scrolled targets, invalid
    drafts, unavailable controls, pending schema replacement and synchronization
    failure. The mouse story includes heading/help focus and checkbox focus before
    the actual toggle, replayed through browser mouse input.
  - PR review found three synchronization boundaries missed by the initial tests.
    Metadata refresh now lays out and invalidates the owning form even when focus
    is unchanged or a schema replacement detaches the clicked label. Application
    disabling is tracked independently of the form's read-only/submission gate,
    including changes while submission is running. Regressions cover pending errors,
    replacement without focus and all four control adapter classes across cancellation.
    Disabling or re-enabling an unfocused control also invalidates its heading and
    value boundaries; availability-cache regressions verify both transitions in
    color and monochrome without moving focus.
  - Compact scrolling reveals the whole field group. Oversized groups prioritize a
    control row and label, then error/help; clipped metadata shows an ellipsis and
    returns after resizing. A one-row stress viewport prioritizes editing and cannot
    show a separate heading. The compact form still reaches Submit through Tab and
    preserves the typed values. Native geometry tests include zero area, 1/2/4/8/16
    rows, narrow columns, password masking, Unicode, multiline and choice controls.
  - All 64 form captures were inspected across default/empty/focused/disabled/invalid/
    loading/Unicode/constrained/mouse states, including color and monochrome. Browser
    review confirmed metadata clicks, retained drafts, checkbox focus versus toggle,
    validation correction, compact submission and resize recovery. The normal-size
    heading/help/value groups remain distinguishable without color; stress views
    retain a bounded input and identify truncated metadata.
  - References: [Charm Huh](https://github.com/charmbracelet/huh) and its
    [title/description/input rendering](https://github.com/charmbracelet/huh/blob/main/field_input.go),
    [GOV.UK label/hint/input guidance](https://design-system.service.gov.uk/components/text-input/),
    and [proximity](https://lawsofux.com/law-of-proximity/). These inform the concrete
    grouping and mouse-focus criteria; they do not establish usability by themselves.
- [#5625](https://github.com/qoretechnologies/qore/issues/5625): user review exposed
  gaps in the earlier acceptance. The disconnected DOM borders, button's invisible
  activation result, submit-locked choice demo and enabled-only compact checks were
  insufficient. All 27 families were reviewed again in color and monochrome at
  default and compact sizes. Actual browser input now exercises every default,
  mouse and constrained story, including restored state after resize.
  - Choice titles are bold cyan, descriptions indented on separate lines, and
    recommendations bold green. Spacing, selection marks and title-only reverse
    emphasis retain this hierarchy without color. The default permits repeated
    selection; the separate Submit story explains its one-shot operation and reset.
  - Buttons show their held press and cancel on outside release, loss of capture or
    availability. Keyboard activation is immediate. The preview fixture displays a
    persistent completion count. Ordinary defaults use readable labels; Unicode
    stress data is confined to explicitly named stress scenarios and variants.
  - Continuous terminal box glyphs are rendered with the pinned xterm WebGL addon.
    Full-width docked examples omit outer side edges; floating overlays retain full
    frames. Explicit edge masks separate border insets from caller padding. The
    browser regression checks adjacent vertical border pixels as well as native cells.
  - Compact file browsing shows one active pane below 48 content columns; F7 switches
    files/preview and widening restores the split without losing selection. Dialogs
    remove decorative message padding when needed, preserving wrapped text and
    actions. Form Tab navigation reveals Submit and completes the compact workflow.
    File previews explain the unselected and empty-file states; the compact story
    switches back to Files, chooses the sample and then displays its actual preview.
  - CodeView and the code-editor story use real AstParser syntax spans. F8 offers
    QoreRepl symbol completion, documentation and call hints; acceptance and undo
    preserve the draft. This is provider-based language assistance, not a project-wide
    language server. Read-only code remains navigable without color.
  - Story controls expose live selection, activation and operation results, focus,
    usable size presets and recovery from stress sizes. Manual input invalidates the
    scripted next checkpoint as soon as input is accepted, before its rendered
    frame arrives. Direct replay requests are rejected until reset too; held-render
    regressions cover both input/reset orderings to prevent a misleading mixed replay.
  - Fast native mouse input could lose a release when ncurses queued several mouse
    reports behind one KEY_MOUSE notification. Reading the remaining native queue
    before the next key fixes the root cause. Raw PTY tests cover following ASCII,
    Unicode, function and Escape keys, outside release, flush and session isolation.
    Capture/provider/popup failure paths also have exception-cleanup regressions.
  - PR review tightened the compact assertion to the reviewed control's clipped
    content rectangle and its own editing caret. Borders/titles and a background
    editor's caret cannot satisfy it. Mid-token completion replaces the complete
    identifier and preserves an existing call parenthesis. Outside primary clicks
    cancel assistance, destroy its panel and continue to the underlying control.
    File previews identify emptiness from a bounded read, including readable
    zero-size-metadata virtual files, and reject unsupported special files.
    Losing an assistance caret anchor during resize now invokes full dismissal,
    removing the panel and modal scope. Native and browser tests open assistance
    before shrinking to 1×1, verify continued editing, and reopen/dismiss after
    recovery; unit tests cover clipped/hidden anchors, cancellation and owner errors.
    The nested variant opens gallery Help over assistance before shrinking. Owned
    modal removal preserves Help and its focus, reconnects the restoration chain,
    and restores editing after Help closes. Both code and standalone assistance
    fixtures cover this path; scope tests also cover active capture, unavailable
    prior focus, ownership cleanup, cursor restoration and callback failures.
    Top-scope removal also completes before a capture-loss callback runs, and
    attempts focus restoration if that callback throws. A held-button regression
    covers both removal APIs and simultaneous restoration failure, preserving the
    original error while keeping the modal stack and subsequent editing usable.
  - Ubuntu's first follow-up capture matched every native state but exposed LCD
    color fringes in the opaque WebGL glyph atlas. Local grayscale/RGB fontconfig
    profiles reproduced the mismatch. An alpha glyph atlas selects grayscale
    coverage while the terminal background remains opaque; a regression compares
    both profiles exactly. Pixel thresholds and semantic assertions are unchanged.
  - The subsequent capture exposed stale outline cursors on empty read-only frames.
    Preserving the WebGL framebuffer retained cursor pixels when blank cells required
    no background-model update. The normal discard-after-presentation mode clears
    them; browser screenshots capture the compositor and require no preserved buffer.
    A cursor-only show/hide regression reproduces the 50-pixel failure and checks
    completely blank hidden-cursor output in color and monochrome.
    The complete recapture changes only 28 empty-state images across eight families
    to remove those outlines; all 1,344 native states and the other 1,316 images
    are unchanged. Every corrected image is entirely the expected background.
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
  with the composed frame. The follow-up WebGL renderer fixes the small vertical
  joins previously accepted as a DOM renderer characteristic.
- Disabled/loading image review found the gallery applied nonmodal cursor policy
  before state transitions reconciled focus. The runner now sets cursor visibility
  after final focus state and event-loop transitions; disabled controls, non-editing
  focus targets and a submitting form no longer display a stale editing caret.
  Shared checkpoints and a native event-loop regression cover this policy.
- Development integration found missing WebSocket upgrades in Storybook's Vite
  middleware mode. Supplying the owning HTTP server fixes the proxy. Generated
  artifact directories are excluded from HMR so review output cannot reload an
  active story. Adapter-code edits require a document reload because browsers cannot
  replace a registered custom-element constructor. The development regression now
  exercises that reload and input in the new story without
  duplicate-registration errors. The documented development command is tested end to end.
- Cross-platform CI found fractional terminal placement from surrounding system-font
  line boxes. Integer line heights and block placement now keep captures on device
  pixels; varying surrounding fonts and wrapping leaves terminal images identical.
  The manifest records browser and native locales separately and fingerprints styles.
  That earlier correction preserved all 1,098 semantic artifacts; 644 PNGs lost
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
| TextEditor | Exact-width/bottom-right editing keeps an insertion row; wide/combining paste is one undo unit. Shrink retains focus/caret. The code story adds syntax spans, F8 completion, call hints and undo without executing the draft. | Accepted after #5625; [code story](../review/baselines/text-editor.code.color.registered.mounted.png). |
| Transcript | Home pauses following; two delivered background lines preserve the reading anchor and increment unread state. End resumes and clears unread feedback. Wheel navigation works through the PTY. | Accepted; [background checkpoint](../review/baselines/transcript.background-reading.mono.registered.background.png). |
| CodeView | Source stays read-only with real syntax highlighting. Keyboard and wheel scrolling expose long content; token weight and readable source retain meaning without color. | Accepted after #5625; [highlighted source](../review/baselines/code-view.default.color.registered.mounted.png). |
| Button | A held mouse press changes emphasis; outside release cancels. Activation updates the visible completion count once, including rapid native press/release. Blank layout space and disabled controls are inert. | Accepted after #5622 and #5625; [mouse action](../review/baselines/button.mouse.mono.registered.mouse.png). |
| Checkbox | The box mark communicates state without color, and the label is clickable. Padding/outside clicks are inert; disabled state is visibly dim. | Accepted after #5622; [disabled](../review/baselines/checkbox.disabled.mono.registered.mounted.png). |
| RadioGroup | Arrow highlight and committed selection remain distinct. Clicking a row selects it; the `(o)` marker and bold emphasis work in monochrome. Long labels clip to the available row. | Accepted; [mouse selection](../review/baselines/radio-group.mouse.mono.registered.mouse.png). |
| ComboBox | Typing filters options; the caret and dropdown marker remain visible. Mouse placement edits the intended position without corrupting Unicode or selection. | Accepted; [mouse caret](../review/baselines/combo-box.mouse.mono.registered.mouse.png). |
| DescribedChoice | Bold titles, indented descriptions and separated groups distinguish choices. Recommendation, focus and committed selection have separate color and non-color cues. The default allows reselection; Submit is explicitly separate. | Accepted after #5625; [choice hierarchy](../review/baselines/described-choice.default.mono.registered.mounted.png). |
| Form | Bold headings, help and explicit errors precede bounded values, with a blank row between fields and a focused-field marker. Clicking labels/help/errors focuses without editing. Compact layouts retain field identity and restore truncated metadata on resize; Tab reaches Submit. Password, readonly, multiline and choice adapters preserve their behavior. | Accepted after #5628; [grouping](../review/baselines/form.default.color.registered.mounted.png), [help focus](../review/baselines/form.mouse.mono.registered.help.png), [field error](../review/baselines/form.invalid.mono.registered.mounted.png). |
| List | Arrows and mouse select the same row. Reverse selection remains clear in monochrome; long rows clip and scrolling preserves selection. | Accepted; [mouse selection](../review/baselines/list.mouse.mono.registered.mouse.png). |
| Table | Bold underlined cyan headers differ from reverse-video selection in color and monochrome. Focus adds selection emphasis; disabled rows are dim. End reveals the last row, shrinking keeps it visible, and Home returns to the start. | Accepted after #5629; [last row after shrink](../review/baselines/table.scrolling.mono.registered.shrink.png). |
| Tree | Directional expansion and row selection expose nested values; disclosure marks communicate hierarchy without color. A mouse row click updates the selected path. | Accepted; [mouse selection](../review/baselines/tree.mouse.mono.registered.mouse.png). |
| KeyValue | Labels and scalar values align under a visible root; keyboard/tree behavior and row selection remain consistent with Tree. | Accepted; [mouse selection](../review/baselines/key-value.mouse.mono.registered.mouse.png). |
| TextChart | Unicode bars and an explicit min/max/gap legend explain the compact view. Expanded bars offer greater height and width without inventing samples; the ASCII fallback documents its ramp. Numeric summaries and scrolling remain available in narrow views. | Accepted after #5629; [expanded bars](../review/baselines/text-chart.expanded.color.registered.expanded.png), [monochrome](../review/baselines/text-chart.expanded.mono.registered.expanded.png). |
| MenuBar | The underlined mnemonic and File label remain discoverable without color. Alt+F and clicking the title open the same menu; Escape restores the underlying focus. | Accepted; [mouse opening](../review/baselines/menu-bar.mouse.mono.registered.mouse.png). |
| DropdownMenu | Disabled entries are dim and skipped by arrows. Clicking a visible enabled command invokes it and dismisses the overlay. Borders and background restoration match native composition. | Accepted; [command result](../review/baselines/dropdown-menu.mouse.mono.registered.mouse.png). |
| Dialog | The question and distinct Apply/Cancel labels explain the decision. Compact layout prioritizes wrapped message and actions over padding. Scrolling reveals longer messages; Tab/Enter/Escape retain deliberate action semantics. | Accepted after #5625; [compact message](../review/baselines/dialog.constrained.mono.registered.mounted.png). |
| CompletionPopup | Single click changes highlight; double-click/Enter accept. Wheel and keyboard navigation agree. Escape/outside dismissal restore the draft's focus/cursor and remove overlay pixels. | Accepted after #5622; [dismissal](../review/baselines/completion-popup.overlap.mono.registered.dismiss.png). |
| AssistancePopup | Ranked results and nearby documentation explain the offered completion. Empty/error/loading text is explicit. Dismissing a pending request restores editing and rejects a late result. | Accepted; [stale result rejected](../review/baselines/assistance-popup.cancel-stale.mono.registered.stale.png). |
| StatusBar | Short key help, state and encoding remain readable as text without color. It does not steal focus or imply an activation target. Tiny views clip the trailing segments. | Accepted; [monochrome](../review/baselines/status-bar.default.mono.standard.mounted.png). |
| Progress | Semantic state colors, bold filled bars/counts, dim remaining segments/timestamps and focused actions establish emphasis. Explicit state words retain meaning in monochrome. The 25% display corresponds to one of four units; cancellation/retry rejects stale completion. | Accepted after #5629; [stale completion](../review/baselines/progress.cancel-stale.mono.registered.stale.png). |
| Timeline | Fixed timestamps and state words distinguish events. Keyboard and actual press/release mouse selection agree; details remain attached to their event. | Accepted after #5622; [mouse selection](../review/baselines/timeline.mouse.mono.registered.mouse.png). |
| FileBrowser | Selecting the fixture file shows its bounded preview. F7 switches files/preview in a single pane below 48 content columns and between panes when wider. Compact help exposes the action; widening preserves selection. | Accepted after #5623 and #5625; [compact files](../review/baselines/file-browser.constrained.mono.registered.mounted.png). |
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
and mouse story. Actual browser keyboard, paste, mouse and resize events additionally
exercise every default, mouse and constrained story, plus code completion and
one-shot choice submission. All 27 default/compact pairs were inspected as rendered
images in color and monochrome; changed press/result, popup and recovery checkpoints
were inspected alongside their semantic assertions.
Native gallery smoke checks retain the standalone workflow and overlay/resize
behavior. The semantic composition agrees across these paths. Browser rasterization
is specifically pinned Linux Chromium with xterm WebGL and software rendering;
another terminal
may use different glyphs, emoji widths, palette approximations or attribute support.
ACS codes/attributes and wide-cell continuations remain in the semantic artifact,
so those differences are visible rather than normalized away. Browser-reserved
shortcuts must be reviewed in the native gallery.

The source and compiled-mode QUnit gates, tooling tests, catalog drift checks,
documentation checks and platform CI evidence are linked in the delivery PR and
central roadmap issues. Acceptance is performed only after reviewing the complete
capture set and the fixes above; the acceptance command itself cannot establish
usability or authorize a merge.

PR review additionally identified four delivery/teardown paths requiring coverage.
The native gallery now enables capture with a dedicated terminal handle; its
integration test verifies evaluated output enters the transcript through reset and
story switching. A bounded worker recovery slot reports queue-full/wake failures
on the UI thread and permits retry; both paths run through the real Application
loop, including shutdown without callbacks. Intentional browser quit acknowledges
pending input and drains terminal bytes before normal exit; a browser test verifies
its final frame, close code 1000 and Reset starting a fresh session. The streaming
marker has a failure deadline, and a negative test proves a missing marker reaches
FIFO/process cleanup. These fixes preserve the registered visual checkpoints.

## qrepl follow-up implementation audit

The audit follows the local `audit-changes` checklist. Evidence below applies to
this follow-up; earlier native implementation checks remain recorded above.

| Check | Status | Evidence |
| --- | --- | --- |
| Core module index and language release notes | N/A | External module; no Qore core registration. |
| Module release notes | Pass | `NcursesQore.qm` initial release and module release notes describe the shared APIs. |
| CMake and QMOD registration | Pass | NcursesQore participates in installation, AOT compilation and two-phase docs. |
| Module structure | Pass | Lowercase intro, `%modern`, separated classes, one module entrypoint, no deprecated includes, 2026 copyrights. |
| Tests | Pass | Local module paths, executable modern tests, debugging and warnings-as-errors; source and AOT gates below. |
| Sandboxing | Pass | General controllers perform no filesystem/network I/O; the file-browser adapter delegates existing authorized file operations. Review bridge uses local PTY/control pipes with explicit bounds and cleanup. |
| Cooperative cancellation | N/A | No C++ changes. BackgroundTask explicitly joins rather than claiming worker cancellation; scopes reject stale delivery. |
| DataProvider action registration | N/A | No provider actions. |
| DataProvider types and allowed values | N/A | No provider schemas. |
| DataProvider descriptions and scheme actions | N/A | No provider/app registration. |
| FactoryMap and JNI/JAR registration | N/A | No provider factories or JVM dependencies. |
| Workarounds and stubs | Pass | Shared APIs replace duplicated application/gallery logic; the upstream save defect is fixed in its owner repository. |
| Exception safety | Pass | Worker failures are typed results; delivery failures surface at join; modal cleanup clears callbacks and destroys panels even on errors. Failure-path tests cover callbacks/providers and disposal. |
| Thread safety | Pass | Widget ownership stays on the UI thread; one worker owns the evaluator, with scoped wake-driven completion and synchronized capture queues. |
| Type safety | Pass | Typed callbacks, TaskResult and existing assistance/form schemas; explicit casts pass AOT compilation without warnings. |
| Performance | Pass | Wake-driven idle loop, serialized background work, bounded control messages, sorted status priorities, no input-handler joins. |
| Error handling | Pass | Invalid dimensions/spacing, invalid completion cursor, duplicate/closed task start, field validation, worker failure and stale results are tested. |
| Documentation | Pass | API contracts, runnable embedding example, tool guide, man page, gallery instructions and implemented architecture updated. |
| QPP namespace/flags and native ownership | N/A | No QPP/C++ changes. |
| Security | Pass | No arbitrary bridge command endpoint, no credentials, local-only review service; fixture teardown and native-protocol bounds retained. |
| Correctness | Pass | Exact completion ranges and suffix retention, Unicode, tiny/resize layouts, save/overwrite/cancel/load, draft revision preservation, focus restoration and actual streaming tested. |

Final local gates: 45 QUnit suites, 957 cases / 22,069 assertions; 26 compiled-module
suites, 629 cases / 7,974 assertions. Documentation/API checks, executable examples,
widget-catalog drift checks and CI tree-reuse tests pass. Browser/native tooling
and platform CI results are linked in the delivery PR. No C++ changed, so this
follow-up does not require a new Valgrind run.
