# Text layout, editing and transcript rendering

Copyright 2026 Qore Technologies, s.r.o.

All widget/model mutations and callbacks run on the application's UI thread.
Native session operations retain the session/global ncurses lock discipline.
Worker threads enqueue output; they never draw or change widgets.

## Positions and viewports

Document offsets count Qore characters, snapped to Unicode extended grapheme
boundaries. Terminal coordinates count display cells. ANSI SGR sequences consume
no source offsets or display columns. `LineListContent` records each wrapped row's
source start/end and supplies both conversion directions. The editor adds its
noneditable prompt to the first rendered line and subtracts it for model edits.
Exact-width editor lines have a separate insertion row before the next hard line.

`ScrollableWidget` resolves wrapping and scrollbar width before measuring/clamping
scroll limits. Its viewport intersects the content rectangle, ancestor clipping
and actual target window. A new caret request reveals the caret; manual scrolling
releases that policy. Screen position queries use the same reveal and mapping as
painting, so completion can be anchored before the next draw. A frame change
invalidates previous target-window bounds. Cursor claims are released on clipping,
focus loss or replacement, without disturbing newer owners.

Vertical box layout measures width-dependent preferred heights before allocating
rows. Editors bound their preferred height; parents still own the actual allocation.

## Indexed content and invalidation

A segment tree maintains row sums and maximum display width. Each source line has
a stable monotonically assigned identity. Two prepared wrap widths cover the common
full-width/scrollbar-width transition. Appends and replacements wrap only changed
lines and update indexes logarithmically. Bulk assignment builds indexes linearly;
arbitrary middle insertion/removal and new widths rebuild the applicable geometry.
Retention advances a physical prefix, with amortized compaction. Anchors use source
identity and character offset instead of mutable row numbers.

Widgets retain local invalidation; ancestors observe dirty descendants. Parent
repaint forces descendants, and painted overlapping siblings force later siblings.
Geometry, padding, visibility and removal invalidate exposed regions. Changed lower
modal layers force higher overlays to repaint. Providers publish revision numbers;
unchanged frames perform no drawing. Fully clipped subtrees acknowledge descendant
and provider invalidation, and exposure forces repaint. Destroying a native panel
invalidates its presentation. Custom drawing must invalidate state changes.

## Editing and paste

`EditorBuffer` owns text, selection, bounded undo/redo, searchable history and the
unfinished draft snapshot. Replacement validation precedes committing edits.
Submission/clipboard callbacks cannot mutate the locked draft; failures propagate.
The caller clears text only after a successful submit callback returns.

Bracketed paste is a native input operation, with bounded payload accumulation and
strict UTF-8 validation. Timeouts retain an incomplete payload. Oversized or cancelled
payloads drain through the closing delimiter before ordinary key dispatch resumes.
The editor normalizes CR/LF and tabs and removes other C0/DEL controls. A paste is one
undo step and cannot execute embedded Enter/control keys. Synthetic input uses a
bounded module-owned LIFO queue with payload/marker transactions; a failed batch
preserves all previously queued input. Alt events retain complete UTF-8 characters.

## Transcript policy

`TranscriptWidget` groups stable source identities into logical blocks. Collapse
hides body rows without discarding source text. Collapse indicators exist in the
presentation provider; source access, selection, search and link validation use
original headers. Mouse range extension keeps its initial anchor when crossing it. Literal search stores grapheme-expanded
ranges by line identity; selection and link hit testing use the shared row mapping.
Link/copy callbacks delegate integration to the application. Direct mutation of the
exposed content provider is unsupported when block metadata is in use.

Manual navigation, including scrollbar clicks, pauses following. New output preserves the reading anchor and
increments unread count until return-to-latest or downward scrolling reaches the
tail. Retention visits expired prefix identities and the new leading block, with
amortized metadata compaction; it does not rescan all retained blocks per append.
Links are indexed by source identity. Search results are cached by content revision.

## qrepl integration

The draft occupies a separate bounded editor viewport below retained output. Failed
evaluation/history expansion preserves text, selection and undo. Menu commands leave
the draft untouched. Completion uses the editor's visible screen caret. Clipboard
bindings use an application-local string, without a desktop dependency.

The capture worker blocks on pipe readiness and an explicit notifier. A flush request
is snapshotted before `Session::pendingOutputBytes()` takes a nonblocking FIONREAD
byte-count snapshot. The worker reads only that finite prefix before publishing
lines and servicing control requests. A continuously readable pipe cannot extend
the current drain or starve flush/shutdown. Only the worker reads this unbuffered
pipe, whose descriptor remains owned until it exits. Acknowledgement follows
publication of complete lines and the unterminated tail. Producer stdio is flushed before
requesting the barrier. Byte accumulation preserves UTF-8 split across reads and
blank lines; malformed complete text is represented with its hexadecimal bytes.
Shutdown notifies and joins the worker before releasing pipe resources.
Notification failures are reported without stopping pipe drainage; fatal reads
close the reader so a producer cannot block on an abandoned pipe. Inherited output
descriptors are duplicated with `File::redirect()` rather than reopened, preserving
access after privilege changes and the original open-file description on restore.

Ordinary Enter CR is normalized to LF by native event decoding. Paste payloads and
Alt input preserve literal CR, so enabling nonl() for paste does not change widget
activation bindings.

## Forms, choices and inspectors

FormModel owns typed values independently of controls. Validation locks reentrant
mutation; a submission snapshot includes its generation. Cancellation invalidates
that generation, so delayed completion cannot replace a newer state. Control parse
errors are separate from derived validation errors. Per-field value-write revisions
let explicit writes replace an invalid draft even when the typed value is unchanged,
without discarding drafts on unrelated validation/status changes. FormWidget preserves invalid
numeric drafts, observes external model changes and rebuilds schema controls only
after constructing the replacement tree. Focus determines the form scroll offset.
Password inputs render one mask cell per grapheme and disable history use. Submission
captures the original masking mode before callbacks, so switching to a non-secret
prompt cannot record a submitted secret; failed submissions restore the original mode.
Form layout uses the visible ancestor/target intersection and observes viewport changes
independently of model revisions, keeping focused controls visible under clipping.

Form fields use label → help → validation error → control order and a blank row
between groups. Headings are bold cyan, errors retain an explicit `Error:` prefix,
and `>` identifies the focused field in color and monochrome. Text-value brackets
and multiline side rails are painted outside each control's frame, preserving its
native caret, password masking and mouse-to-text coordinate mapping. Metadata labels
delegate `mouseFocusTarget()` to the associated control through the existing scoped
dispatcher; they never forward an activation or mutate a value. Pending model/schema
changes are reconciled before delegation, and a detached or unavailable control is
not returned. Successful metadata refresh also lays out and invalidates the owning
form, even when focus is unchanged or the clicked label was replaced. A failed
synchronization propagates without changing focus. Bound controls combine the
application's enabled flag with a separate form availability gate, preserving
application disabling across refresh, submission, cancellation and retry.
Effective control availability also participates in layout invalidation, so changing
an unfocused control repaints its heading and boundaries without a model revision.

Focus reveals the entire field group. If a field exceeds the viewport height, layout
allocates a control row, a label row, an error row and a help row in that priority,
then expands metadata and multiline content within the remaining space. Clipped
metadata shows an ellipsis; the full source text is retained for resize recovery.
Zero-area layouts remain inert, and a one-row stress viewport prioritizes editing.

Described choices separate stable values from labels and distinguish custom text in
a typed result. Descriptions wrap through the shared content provider. Successful
submission is one-shot; validation/callback failures retain selection and custom text.

Tree inspection indexes source data iteratively with bounded node/depth counts.
Paths use JSON Pointer escaping. Filtering propagates matches to ancestors in one
reverse pass, independent of expansion state. Visible path indexes make keyboard
selection lookup constant time; only old/new selected rows are reformatted. Previews
escape control characters, while export callbacks receive original typed values.

Code views keep original source separately from normalized display text. Syntax
callbacks must preserve plain display content, and complete segment styles restart
at hard newlines. Replacement validates styling before changing the document. Full
copy/export retain original bytes; visible selection follows normalized positions.

Native ANSI parameter accumulation checks integer bounds before multiplication.
Unsupported oversized parameters are ignored; subsequent valid parameters still
apply. Segment and parameter scans check cancellation and callers propagate errors.
Fallible parse/width methods use RET_VALUE_ONLY, and width accumulation uses 64 bits.

Shared-window modals invalidate lower layers when dirty, because they have no native
panel compositor to restore previously covered cells. Forced-paint exceptions keep
widgets/panels dirty for retry. Specialized child painters acknowledge skipped panes.
Hidden source anchors resolve through the indexed preceding visible line (or the
first visible line), and adopt that source identity for subsequent expansion/resize.
Transcript tail following establishes target-window bounds before scrolling; search
navigation reveals the selected match on both axes. Preferred editor columns persist
only across consecutive vertical moves, identified by the model revision.

Form Boolean controls preserve unset values until a toggle or explicit `setChecked()` edit; an explicit `False` satisfies required Boolean validation. Completed forms reveal the submission receipt even when submission originates in an early field. Tree indentation and branch hit testing use the effective ancestor/target-clipped viewport width.

Form text controls import changed model values before the input captures its submit/rollback snapshot; typed zero remains distinct from an unset value. Transcript clearing resets both scroll axes. Custom-choice caret revelation follows editing, focus and geometry changes, preserving manual reading positions between paints. Tree filtering, collapse and replacement notify observers after a changed selection or selected value is committed, including the empty root path and no selection.

Validation uses presence rather than truth conversion for error strings: only `NOTHING` clears an error or indicates validation success. Numeric text identifiers/help are valid strings. Field and choice labels/values are validated before committing schema or option replacements.

All bound form control adapters import pending model revisions before processing input, including multiline editors, checkboxes and described choices. A schema replacement detaches stale controls before dispatch; input to those controls is ignored. This prevents an input event between a model update and repaint from overwriting the newer value.


## Assistance and asynchronous operation surfaces

`AssistanceModel` owns provider metadata for one `EditorBuffer`. Request tokens include
an opaque model identity, monotonic generation, editor revision, exact text and caret.
Responses validate completely before publication; replacement ranges use character
offsets and must align with shared grapheme geometry. Editing and cancellation reject
stale responses. Completion/action edits form one undo step. `AssistancePopupWidget`
uses the editor's screen caret, maintains a stable result identity through filtering,
and separates list navigation from scrollable documentation. The application owns
modal push/pop and panel destruction. Hiding the editor/popup cancels pending help.
If resize, clipping or editor visibility removes a visible popup's caret anchor,
positioning invokes its dismissal hook once so ownership can release the modal
scope and panel; it does not leave an invisible scope trapping keyboard input.
Owners remove their exact widget with `Application.removeModal()`. When a scope is
covered, `EventDispatcher` splices that entry out and transfers its saved scope/focus
to its immediate successor. Active focus and mouse capture stay with the top overlay;
later dismissal restores the surviving predecessor, not the destroyed popup.
Top removal detaches the scope before capture-loss callbacks and attempts focus
restoration even when cancellation throws. If both callbacks fail, the cancellation
error remains primary and focus-manager cleanup leaves no stale owner.

`ActionModel` similarly identifies each operation attempt and explicitly represents
pending, running, cancelled, failed and completed states. Cancellation invalidates the
attempt; a successful receipt requires explicit reset before another start. Unknown
totals are represented by NOTHING, and determinate progress rejects nonfinite or
out-of-range values. `ProgressWidget` resolves content/scrollbar width before painting
its bar. State words have semantic color, filled segments/counts and active actions
have emphasis, and timestamps/remaining segments are dim. Plain status inspection
strips styling; availability and focus participate in the presentation cache.
Table headers use bold cyan underlining without reverse video; reverse data selection
adds bold cyan emphasis only while focused. Disabled tables retain selection with dim cues.
`TimelineWidget` appends immutable timestamped snapshots into transcript
blocks; it indexes event/block/source identities, trims expired metadata with bounded
history, and preserves only retained details. Described choices compose with actions
for application-owned approval/review semantics.

`UiEventQueue` provides a bounded FIFO with UI-thread receivers and worker-safe posts.
A mutex protects publication and lifetime; callbacks and final payload/receiver releases
run outside that mutex. Each drain processes a finite initial batch, and native ready
input precedes work wakeups to prevent input starvation. Scope closure disposes queued
work; availability predicates permanently retire hidden/disabled/detached owners on UI
reconciliation. Root owners remain valid behind nested modals. Tick subscriptions use
stable removable IDs and recheck existence after earlier callbacks remove later ones.

Native sessions use a nonblocking close-on-exec self-pipe for wake notifications.
`readEvent()` checks input under the ncurses lock and releases it before cancellable
polling of the terminal and wake descriptors. A duplicated terminal descriptor prevents
close/reuse races. A session allows one reader; close wakes it, and RAII releases reader
ownership on errors/cancellation. Explicit wakeups coalesce without synthesizing keys;
injected input only signals readiness. Fork generations recreate child wake channels
without consuming/signalling the parent's notifications. Escape/multibyte decoding
retains bounded library/continuation delays. Blocking waits inside `withLock()` fail
instead of retaining the global lock indefinitely. Older Qore polling is bounded by
its cooperative I/O cancellation interval.

## File selection and accessible media

`FileSelectionModel` separates stable checked identities from the filtered view and
highlighted row. Metadata/filter changes validate before replacement. Hidden selections
remain selected and are counted; unavailable entries cannot be newly selected, and
metadata refresh can invalidate an existing selection before dispatch. Operations are
application callbacks with explicit completion, cancellation and exception states.
Optional local inspection reuses sandbox-checked Qore filesystem APIs and never opens
contents implicitly. Applications remain responsible for I/O races after validation.

`AttachmentWidget` uses the same operation lifecycle for names, paths, sizes/types,
errors, optional text and chart previews, and configured open/save/export fallbacks.
Presentation normalizes control characters without altering source metadata. `TextChart`
is an immutable finite-data snapshot with gaps, an all-data numeric summary and bounded
ASCII/optional Unicode sparklines. It uses arbitrary-precision normalization to avoid
float overflow across opposite-sign extreme values. Downsampling includes endpoints
when at least two cells fit; one cell shows the latest source position. No decoder,
network operation or external application is invoked implicitly.
The widget defaults to Unicode bars with an explicit min/max scale and highlighted
gaps; its ASCII fallback lists the full symbol ramp. Expanded charts use 1–64 rows,
eight vertical sublevels per Unicode cell and up to eight columns per source sample.
Heights are normalized from the snapshot minimum to maximum; constant samples use
the midpoint. Wider rendering repeats each sampled bar horizontally rather than
inventing intermediate data. A gap has a question mark at the baseline and no bar.

The shared list uses the effective ancestor/target viewport for paging, selection
reveal, scrollbars and mouse bounds, preserving manual scrolling until selection or
geometry changes. Horizontal ancestor clipping retains the original text suffix.
Double-click activation takes precedence when a mouse mask contains multiple primary
click flags. Single-column lists reserve their only cell for content.

## Composed capture and executable widget stories

`Session::capture()` observes ncurses' completed physical-screen image (`curscr`).
It duplicates that window under the session call guard and reads wide cells from
that private copy. Live window cursors, pending virtual output, panel stacking and
application state are untouched. The versioned typed hash records row-major cells,
leading widths/continuations, attributes, palette indices, capabilities and physical
cursor coordinates. Successful visibility requests are tracked; unsupported initial
visibility remains unknown. This is the emitted terminal model, not emulator pixels.
The caller must finish its draw/refresh checkpoint and associate focus/scroll
assertions on the UI thread. `snapshot()` remains the legacy base-window text API.

`Session::resize()` synchronously applies known ncurses geometry. Headless drivers
resize the PTY, apply this method, deliver a Resize event and complete drawing.
Native gallery presets deliberately change the logical viewport only. Capture
comparison must use the same locale, terminal capabilities and geometry.

`Session::updatePanels()` stages base output directly when no native panel is
visible, including before libpanel initializes its screen hook. When panels exist,
it leaves the base window touched lines intact for libpanel overlap propagation.
Staging the base prematurely would consume those flags and erase already staged
panels. Composed tests cover root, descendant, modal and nested panel surfaces.
`Session::terminalSize()` observes device geometry independently of ncurses logical
presets. Gallery selection/reset use registered geometry bounded by that device;
navigation/help overlays temporarily use the available device and restore the story.

The development-only `examples/gallery/` registry supplies stable story IDs, public
API links, fixture data, geometry, input/resize steps, semantic expectations and
capture checkpoints. `Runner` creates actual NcursesUi widgets, verifies completed
frames, and owns teardown/reset. `Gallery` adds searchable native navigation,
contextual help, reset, logical size presets and focus/scroll/cursor inspection.
No alternate widget implementation is used. Fixed fixture values and timestamps
make repeated headless runs comparable; file actions never write user files.

`Variants` records the nine review-state dispositions for each widget and creates
applicable executable scenarios. `tools/widget_catalog.py` derives the Doxygen
catalog from that same registry and rejects unregistered public widgets, duplicate
IDs and missing state links. Native tests cover every scenario, repeated captures
and reset equivalence; CLI tests execute every widget in color and monochrome.

## Borders, emphasis and activation feedback

PanelWidget owns a BorderEdges bit mask. Border insets and caller padding are
independent: contentRect adds them, and setHasBorder changes only the mask. The
application chooses edges explicitly. Root/docked panels spanning the viewport use
horizontal edges or no frame; floating dialogs/popups use a complete frame. Adjacent
panes share a single separator, owned by the container. No terminal-size heuristic
silently changes a caller's floating-panel geometry. The gallery's docked file browser
explicitly refits to the full viewport; ordinary panels retain requested dimensions.

Selection and focus use independent signals. DescribedChoice headings carry bold
cyan text, reverse focus, and a filled/empty selection circle. Descriptions are
indented, recommendations are bold green, and unavailable options are dim with an
explicit label. Spacing, marks and weight retain meaning without color.

Button primary press acquires dispatcher mouse capture and paints bold/underlined
pressed brackets. Release inside activates once; outside release cancels. Captures
belong to one root/modal scope and are released on resize, removal, unavailability,
scope changes and exceptions. Keyboard/synthesized activation is immediate; applications
show a persistent result rather than adding a timer solely to simulate animation.

TextEditorWidget accepts a plain-to-ANSI highlighter. Output must preserve source
exactly. Formatting locks direct model mutations and rejects editor reentrancy.
Styles are cached by source text, while caret/selection geometry uses plain offsets.
Replacement providers and setText format before committing. Interactive edits remain
in the model if formatting fails, allowing recovery by replacing/disabling the provider.
The gallery uses astparser highlights and QoreRepl completion/hints without evaluating
drafts or persisting history. General widgets do not require either provider.


### Shared workflow controllers

`EditorAssistance` owns a buffer-bound `AssistanceModel` and its popup, including
placement around the caret, empty-result feedback, dismissal, error cleanup and
focus restoration. `NcursesQore::CodeSupport` is a separate optional language
adapter accepting the application's existing `QoreRepl` instance. Source styling
uses an independent optional astparser; completions never evaluate draft source.
The application serializes assistance and evaluation against that live backend.

`BackgroundTask` owns one worker and a UI-event scope. It remains busy through
completion delivery, catches worker exceptions as typed result data, and releases
callbacks before joining during disposal. A single protected recovery slot retains
queue/wake failures; a wake and owned UI tick deliver that failure once, allowing
retry without an interactive join. Headless embedders can dispatch recovery explicitly
through `processPending()`. It exposes the existing `ActionModel`
for state/progress views. Joining is for tests and shutdown; worker execution is
not cancellable unless the underlying operation supplies a separate mechanism.
qrepl retains the submitted buffer revision and only clears an unchanged draft on
success. Capture workers wake the event loop when complete output lines arrive.
`EditorBuffer::setHistory(entries, True)` preserves active history navigation and
the original draft/selection while retaining the newest history update separately.
Returning to the draft or editing ends the browsing snapshot and applies that
update. Completion can therefore append history without discarding a draft the
user saved by navigating backward while evaluation was still running.

`Dialogs` composes existing forms, dialogs and file browsers, owning dismissal and
focus restoration. Validation remains in `FormModel`; acceptance semantics remain
application callbacks. `PanelWidget::setCenteredSize()` clamps floating panels and
restores preferred size on regrowth. Status segments can declare priority and a
compact label; allocation favors important state while retaining display order.

Full-application gallery entries load `bin/qrepl` itself with a supplied Application
and disabled persistent history. The browser bridge uses the actual event loop and
posts control commands from a reader worker; explicit input fences and worker joins
are completion barriers. Program output has a separate capture pipe from bridge
protocol output. Regular widget stories keep their existing deterministic bridge.
Application reset, replay and story replacement reject busy work before changing
state or geometry. Native gallery controls use Alt-1 through Alt-6 to preserve
application function keys. Session exit publishes a separate final capture with a
terminal fence; the browser renders it before closing, even when no input command
is pending when evaluation completes.
