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
