#! @file ActionModel.qc Generation-checked operation state and progress
/* Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT */
public namespace NcursesUi {
#! Immutable identity of one operation attempt; retries have a new generation.
public hashdecl ActionRequest { string id; int generation; NcursesUi::RequestIdentity owner; }
/** UI-thread-owned lifecycle for long operations and review actions.
    Start, progress, completion and failure use explicit generations; cancellation
    invalidates outstanding results. Completed operations remain completed until
    explicitly reset. Workers deliver updates through the application's UI queue;
    they never mutate this model or a widget directly.
*/
public class ActionModel {
    private {
        NcursesUi::RequestIdentity identity();
        string id;
        string label;
        int state = NcursesUi::ActionState::Pending;
        int generation = 0;
        int revision = 0;
        *float completed;
        *float total;
        string message = "";
        *string error;
        auto result;
        *date started;
        *date finished;
        bool dispatching = False;
    }
    /** Defines an operation. @param identity nonempty stable action ID @param title visible label @throw ACTION-ID-ERROR if empty */
    constructor(string identity, string title) { if (identity == "") { throw "ACTION-ID-ERROR", "Action identity cannot be empty"; } id = identity; label = title; }
    /** Returns the stable action identifier. @return ID */
    string getId() { return id; }
    /** Returns the display label. @return label */
    string getLabel() { return label; }
    /** Returns the lifecycle state. @return ActionState */
    int getState() { return state; }
    /** Returns the presentation revision. @return monotonic revision */
    int getRevision() { return revision; }
    /** Returns completed units or NOTHING for indeterminate progress. @return units */
    *float getCompleted() { return completed; }
    /** Returns total units, or NOTHING for indeterminate progress. @return total */
    *float getTotal() { return total; }
    /** Returns the latest status message. @return plain message */
    string getMessage() { return message; }
    /** Returns a failure message. @return error or NOTHING */
    *string getError() { return error; }
    /** Returns the successful result. @return application-owned receipt data */
    auto getResult() { return result; }
    /** Returns the start time. @return timestamp or NOTHING */
    *date getStarted() { return started; }
    /** Returns the final transition time. @return timestamp or NOTHING */
    *date getFinished() { return finished; }
    /** Starts a pending, failed or cancelled operation; successful actions require explicit reset.
        @return immutable attempt token @throw ACTION-STATE-ERROR while running/completed or reentrant dispatch
    */
    hash<NcursesUi::ActionRequest> begin() {
        if (dispatching || state == NcursesUi::ActionState::Running || state == NcursesUi::ActionState::Completed) { throw "ACTION-STATE-ERROR", "Action is running or completed"; }
        state = NcursesUi::ActionState::Running; error = NOTHING; result = NOTHING; message = ""; completed = NOTHING; total = NOTHING;
        started = now(); finished = NOTHING; ++revision;
        return <NcursesUi::ActionRequest>{"id": id, "generation": ++generation, "owner": identity};
    }
    /** Dispatches an operation through an application-owned starter.
        @param callback starts work with the immutable token; deliver results on the UI thread
        @return token @note Starter exceptions fail the matching attempt and propagate. Reentrant dispatch is rejected.
    */
    hash<NcursesUi::ActionRequest> dispatch(code<nothing(hash<NcursesUi::ActionRequest>)> callback) {
        hash<NcursesUi::ActionRequest> token = begin(); dispatching = True; on_exit dispatching = False;
        try { callback(token); } catch (hash<ExceptionInfo> ex) { fail(token, ex.desc); rethrow; }
        return token;
    }
    /** Updates current progress; unknown totals are represented explicitly.
        @param token attempt identity @param done completed units, or NOTHING for indeterminate status
        @param maximum total units, or NOTHING @param text status message @return accepted, False for stale results
        @throw ACTION-PROGRESS-ERROR for nonfinite, negative, inconsistent or over-total progress
    */
    bool progress(hash<NcursesUi::ActionRequest> token, *float done, *float maximum, string text = "") {
        if (!current(token)) { return False; }
        if ((exists done && (done.nanp() || done.infp() || done < 0.0))
                || (exists maximum && (maximum.nanp() || maximum.infp() || maximum <= 0.0 || !exists done || done > maximum))) {
            throw "ACTION-PROGRESS-ERROR", "Progress must be finite, nonnegative and within its positive total";
        }
        completed = done; total = maximum; message = text; ++revision; return True;
    }
    /** Completes the current attempt once. @param token identity @param value receipt data @return accepted */
    bool complete(hash<NcursesUi::ActionRequest> token, auto value = NOTHING) {
        if (!current(token)) { return False; } state = NcursesUi::ActionState::Completed; result = value;
        if (exists total) { completed = total; } finished = now(); ++revision; return True;
    }
    /** Fails the current attempt, preserving progress for diagnosis. @param token identity @param text failure @return accepted */
    bool fail(hash<NcursesUi::ActionRequest> token, string text) {
        if (!current(token)) { return False; } state = NcursesUi::ActionState::Failed; error = text; finished = now(); ++revision; return True;
    }
    /** Cancels pending/running work, returning its old identity for an optional application cancellation hook.
        @return old token, or NOTHING when already cancelled/failed/completed
    */
    *hash<NcursesUi::ActionRequest> cancel() {
        if (state != NcursesUi::ActionState::Pending && state != NcursesUi::ActionState::Running) { return NOTHING; }
        hash<NcursesUi::ActionRequest> token = <NcursesUi::ActionRequest>{"id": id, "generation": generation, "owner": identity};
        ++generation; state = NcursesUi::ActionState::Cancelled; finished = now(); ++revision; return token;
    }
    /** Explicitly reopens a finished operation. @throw ACTION-STATE-ERROR while running/dispatching */
    nothing reset() {
        if (dispatching || state == NcursesUi::ActionState::Running) { throw "ACTION-STATE-ERROR", "Cannot reset an active action"; }
        ++generation; state = NcursesUi::ActionState::Pending; result = NOTHING; error = NOTHING; completed = NOTHING; total = NOTHING;
        started = NOTHING; finished = NOTHING; message = ""; ++revision;
    }
    private bool current(hash<NcursesUi::ActionRequest> token) { return state == NcursesUi::ActionState::Running && token.owner == identity && token.id == id && token.generation == generation; }
}
} # namespace NcursesUi
