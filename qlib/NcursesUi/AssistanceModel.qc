#! @file AssistanceModel.qc Versioned editor assistance and precise source edits
/* Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT */
public namespace NcursesUi {
#! Half-open source range in Qore character offsets, aligned to grapheme boundaries.
public hashdecl SourceRange { int start; int end; }
#! Ranked completion with an explicit replacement range; labels never determine edits.
public hashdecl CompletionItem {
    string id; string label; string text; hash<NcursesUi::SourceRange> range;
    int rank = 0; string filter_text = ""; string detail = ""; string documentation = "";
}
#! Diagnostic severity independent of its presentation style.
public enum DiagnosticSeverity : int { Error = 0, Warning = 1, Information = 2, Hint = 3 }
#! A diagnostic tied to a particular source range.
public hashdecl DiagnosticItem {
    string id; string message; hash<NcursesUi::SourceRange> range;
    int severity = NcursesUi::DiagnosticSeverity::Error; string documentation = "";
}
#! Signature help; active_parameter is -1 when there is no active parameter.
public hashdecl SignatureHelp {
    string label; list<string> parameters = (); int active_parameter = -1; string documentation = "";
}
#! Application-owned suggested action, with an optional source edit.
public hashdecl AssistanceAction {
    string id; string label; string documentation = ""; *hash<NcursesUi::SourceRange> range; string text = "";
}
#! Immutable provider request; generation and revision reject late responses.
public hashdecl AssistanceRequest { NcursesUi::RequestIdentity owner; int generation; int revision; string text; int cursor; }
#! Generic provider response, independent of network or language protocols.
public hashdecl AssistanceResponse {
    list<hash<NcursesUi::CompletionItem>> completions = ();
    list<hash<NcursesUi::DiagnosticItem>> diagnostics = ();
    list<hash<NcursesUi::AssistanceAction>> actions = ();
    *hash<NcursesUi::SignatureHelp> signature;
}
/** UI-thread-owned assistance model bound to an editor buffer.
    Providers may run synchronously with request(), or use beginRequest() and deliver
    complete()/fail() on the UI thread. Text, caret or selection changes invalidate
    responses. Cancellation and provider failures preserve editing and undo history.
    All source ranges are validated before accepting a response; explicit edits are
    one undo operation and never infer a whitespace-delimited token.
*/
public class AssistanceModel {
    private {
        NcursesUi::RequestIdentity identity();
        NcursesUi::EditorBuffer editor;
        int generation = 0;
        *hash<NcursesUi::AssistanceRequest> pending;
        *hash<NcursesUi::AssistanceResponse> response;
        int response_revision = -1;
        int revision = 0;
        *string error;
        bool activating = False;
        bool requesting = False;
        *code<hash<NcursesUi::AssistanceResponse>(hash<NcursesUi::AssistanceRequest>)> provider;
        *code<nothing(string)> action_handler;
    }
    /** Binds a source buffer. @param buffer UI-thread-owned editor */
    constructor(NcursesUi::EditorBuffer buffer) { editor = buffer; }
    /** Returns the source buffer. @return bound editor */
    NcursesUi::EditorBuffer getEditor() { return editor; }
    /** Sets a synchronous provider. @param callback receives an immutable request snapshot */
    nothing setProvider(*code<hash<NcursesUi::AssistanceResponse>(hash<NcursesUi::AssistanceRequest>)> callback) {
        checkIdle(); cancel(); provider = callback;
    }
    /** Sets application-owned action semantics. @param callback receives a stable action identifier */
    nothing setOnAction(*code<nothing(string)> callback) { checkIdle(); action_handler = callback; }
    /** Begins a new request, superseding previous requests/results. @return request snapshot */
    hash<NcursesUi::AssistanceRequest> beginRequest() {
        checkIdle(); response = NOTHING; error = NOTHING; ++revision;
        pending = <NcursesUi::AssistanceRequest>{"owner": identity, "generation": ++generation, "revision": editor.getRevision(), "text": editor.getText(), "cursor": editor.getCursor()};
        return pending;
    }
    /** Validates and accepts a current response atomically.
        @param token exact request snapshot @param value typed provider result @return False for stale/cancelled results
        @throw ASSISTANCE-DATA-ERROR for invalid identities, ranges or signature metadata
    */
    bool complete(hash<NcursesUi::AssistanceRequest> token, hash<NcursesUi::AssistanceResponse> value) {
        checkIdle(); if (!current(token)) { return False; }
        validateResponse(token.text, value);
        response = value; response_revision = token.revision; pending = NOTHING; error = NOTHING; ++revision; return True;
    }
    /** Records a current provider failure. @param token request @param message plain error @return accepted */
    bool fail(hash<NcursesUi::AssistanceRequest> token, string message) {
        checkIdle(); if (!current(token)) { return False; } pending = NOTHING; response = NOTHING; error = message; ++revision; return True;
    }
    /** Calls the configured provider; exceptions are recorded and propagated without changing the editor.
        @return accepted response, or False without a provider or after cancellation/stale completion
    */
    bool request() {
        checkIdle(); if (requesting) { throw "ASSISTANCE-BUSY-ERROR", "Provider requests cannot recurse"; }
        if (!provider) { return False; } requesting = True; on_exit requesting = False;
        hash<NcursesUi::AssistanceRequest> token = beginRequest();
        try { return complete(token, provider(token)); }
        catch (hash<ExceptionInfo> ex) { fail(token, ex.desc); rethrow; }
    }
    /** Invalidates pending work/results, retaining the editor. */
    nothing cancel() { checkIdle(); ++generation; pending = NOTHING; response = NOTHING; error = NOTHING; ++revision; }
    /** Returns only results for the current editor version. @return accepted response or NOTHING */
    *hash<NcursesUi::AssistanceResponse> getResponse() { return response && response_revision == editor.getRevision() ? response : NOTHING; }
    /** Returns a provider failure. @return message or NOTHING */
    *string getError() { return error; }
    /** Reports pending work for the current editor version. @return pending */
    bool isPending() { return pending && pending.revision == editor.getRevision(); }
    /** Returns a presentation revision including editor changes. @return monotonic revision */
    int getRevision() { return revision + editor.getRevision(); }
    /** Returns ranked, case-insensitively filtered completions; equal ranks retain provider order.
        @param filter literal label/filter-text substring @return ranked completions
    */
    list<hash<NcursesUi::CompletionItem>> getCompletions(string filter = "") {
        *hash<NcursesUi::AssistanceResponse> value = getResponse(); if (!value) { return (); }
        list<hash<NcursesUi::CompletionItem>> result = (); hash<string, int> positions = {}; filter = filter.lwr();
        foreach hash<NcursesUi::CompletionItem> item in (value.completions) {
            if (filter == "" || (item.filter_text != "" ? item.filter_text : item.label).lwr().find(filter) >= 0) { positions{item.id} = result.size(); result += item; }
        }
        return sort(result, int sub (hash<NcursesUi::CompletionItem> a, hash<NcursesUi::CompletionItem> b) { return (b.rank <=> a.rank) ?: (positions{a.id} <=> positions{b.id}); });
    }
    /** Applies an explicit completion edit once. @param id stable identity @return False if the result is stale
        @throw ASSISTANCE-ID-ERROR for an unknown identity
    */
    bool applyCompletion(string id) {
        checkIdle(); *hash<NcursesUi::AssistanceResponse> value = getResponse(); if (!value) { return False; }
        foreach hash<NcursesUi::CompletionItem> item in (value.completions) {
            if (item.id == id) { editor.replace(item.range.start, item.range.end, item.text); cancel(); return True; }
        }
        throw "ASSISTANCE-ID-ERROR", "Unknown completion identity";
    }
    /** Selects a diagnostic range in the editor. @param id stable identity @return False for stale results */
    bool selectDiagnostic(string id) {
        checkIdle(); *hash<NcursesUi::AssistanceResponse> value = getResponse(); if (!value) { return False; }
        foreach hash<NcursesUi::DiagnosticItem> item in (value.diagnostics) {
            if (item.id == id) { editor.select(item.range.start, item.range.end); cancel(); return True; }
        }
        throw "ASSISTANCE-ID-ERROR", "Unknown diagnostic identity";
    }
    /** Applies a suggested edit or invokes application semantics once.
        @param id stable action identity @return False for stale results or absent application handler
        @note A callback-only action cannot also contain a source edit. Callback failures preserve the result for retry.
    */
    bool activateAction(string id) {
        checkIdle(); *hash<NcursesUi::AssistanceResponse> value = getResponse(); if (!value) { return False; }
        foreach hash<NcursesUi::AssistanceAction> item in (value.actions) {
            if (item.id != id) { continue; }
            if (item.range) { editor.replace(item.range.start, item.range.end, item.text); }
            else {
                if (!action_handler) { return False; }
                activating = True;
                try { action_handler(id); } catch (hash<ExceptionInfo> ex) { activating = False; rethrow; }
                activating = False;
            }
            cancel(); return True;
        }
        throw "ASSISTANCE-ID-ERROR", "Unknown action identity";
    }
    private nothing checkIdle() { if (activating) { throw "ASSISTANCE-BUSY-ERROR", "Cannot mutate assistance during action activation"; } }
    private bool current(hash<NcursesUi::AssistanceRequest> token) { return pending && token == pending && token.revision == editor.getRevision(); }
    private static nothing validateRange(string text, hash<NcursesUi::SourceRange> range) {
        if (!exists range.start || !exists range.end || range.start < 0 || range.end < range.start || range.end > text.length()
                || NcursesReplUi::TextPosition::snapOffset(text, range.start) != range.start
                || NcursesReplUi::TextPosition::snapOffset(text, range.end) != range.end) {
            throw "ASSISTANCE-DATA-ERROR", "Source range must be ordered, in bounds and aligned to graphemes";
        }
    }
    private static nothing validateResponse(string text, hash<NcursesUi::AssistanceResponse> value) {
        hash<string, bool> ids = {};
        foreach hash<NcursesUi::CompletionItem> item in (value.completions) {
            if (item.id == "" || exists ids{item.id}) { throw "ASSISTANCE-DATA-ERROR", "Invalid or duplicate completion identity"; }
            if (!exists item.label || !exists item.text || !exists item.range) { throw "ASSISTANCE-DATA-ERROR", "Completion requires a label, text and source range"; }
            ids{item.id} = True; validateRange(text, item.range); validateInsertion(item.text);
        }
        ids = {};
        foreach hash<NcursesUi::DiagnosticItem> item in (value.diagnostics) {
            if (item.id == "" || exists ids{item.id} || item.severity < 0 || item.severity > 3) { throw "ASSISTANCE-DATA-ERROR", "Invalid diagnostic metadata"; }
            if (!exists item.message || !exists item.range) { throw "ASSISTANCE-DATA-ERROR", "Diagnostic requires a message and source range"; }
            ids{item.id} = True; validateRange(text, item.range);
        }
        ids = {};
        foreach hash<NcursesUi::AssistanceAction> item in (value.actions) {
            if (item.id == "" || exists ids{item.id}) { throw "ASSISTANCE-DATA-ERROR", "Invalid or duplicate action identity"; }
            ids{item.id} = True;
            if (!exists item.label) { throw "ASSISTANCE-DATA-ERROR", "Action requires a label"; }
            if (item.range) { validateRange(text, item.range); validateInsertion(item.text); }
            else if (item.text != "") { throw "ASSISTANCE-DATA-ERROR", "An edit requires a source range"; }
        }
        if (value.signature && (!exists value.signature.label || value.signature.active_parameter < -1 || value.signature.active_parameter >= value.signature.parameters.size())) {
            throw "ASSISTANCE-DATA-ERROR", "Invalid active signature parameter";
        }
    }
    private static nothing validateInsertion(string text) {
        if (text != NcursesUi::TextEditorWidget::normalizePaste(text)) { throw "ASSISTANCE-DATA-ERROR", "Insertions must contain normalized editor text"; }
    }
}
} # namespace NcursesUi
