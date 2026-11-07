#! @file BackgroundTask.qc Single-operation worker with UI-owned completion
/* Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT */
public namespace NcursesUi {
#! Worker outcome; exceptions are data until delivered on the UI thread.
public hashdecl TaskResult { auto value; *hash<ExceptionInfo> error; }
/** Runs one worker at a time, delivering completion through Application's wake queue.
    Start and callbacks belong to the UI thread; work must never access widgets.
    A task remains busy until its completion is delivered, preventing overlapping
    evaluator/resource access. close() discards callbacks and joins work; it does
    not cancel the underlying operation. No cancellation control is advertised.
    Call join() only for deterministic testing or shutdown, never in input handlers.
*/
public class BackgroundTask {
    private {
        NcursesUi::ActionModel model;
        NcursesUi::UiEventScope delivery;
        Counter workers(0);
        int ui_thread = gettid();
        bool closed = False;
        bool busy = False;
        *code<nothing(hash<NcursesUi::TaskResult>)> on_finished;
        Mutex failure_mutex();
        *hash<ExceptionInfo> delivery_failure;
    }
    /** Creates a task. @param app UI owner @param id stable action ID @param label operation label */
    constructor(NcursesUi::Application app, string id, string label) {
        model = new NcursesUi::ActionModel(id, label);
        delivery = app.createEventScope(sub (auto payload) {
            hash<NcursesUi::TaskResult> result = payload.result;
            if (result.error) { model.fail(payload.token, result.error.desc); }
            else { model.complete(payload.token, result.value); }
            busy = False;
            *code<nothing(hash<NcursesUi::TaskResult>)> callback = on_finished; on_finished = NOTHING;
            if (callback) { callback(result); }
        });
    }
    /** Returns operation state for progress/status views. @return action model */
    NcursesUi::ActionModel getModel() { checkThread(); return model; }
    /** Reports work awaiting completion delivery. @return busy */
    bool isRunning() { checkThread(); return busy; }
    /** Starts work, rejecting duplicate starts before changing state.
        @param work worker-only callback @param finished UI-thread outcome callback
        @throw UI-TASK-BUSY while running; UI-TASK-CLOSED after close */
    nothing start(code<auto()> work, code<nothing(hash<NcursesUi::TaskResult>)> finished) {
        checkThread();
        if (closed) { throw "UI-TASK-CLOSED", "Task has been closed"; }
        if (busy) { throw "UI-TASK-BUSY", "Task is already running"; }
        model.reset(); hash<NcursesUi::ActionRequest> token = model.begin();
        busy = True; on_finished = finished; workers.inc();
        try { background runWork(work, token); }
        catch (hash<ExceptionInfo> ex) { workers.dec(); busy = False; on_finished = NOTHING; model.fail(token, ex.desc); rethrow; }
    }
    /** Joins the worker without dispatching callbacks. Call Application::processPending() afterward.
        @throw worker delivery error if the application's queue could not accept/wake */
    nothing join() {
        checkThread(); workers.waitForZero(); failure_mutex.lock(); on_exit failure_mutex.unlock();
        if (delivery_failure) { throw delivery_failure.err, delivery_failure.desc, delivery_failure.arg; }
    }
    /** Disposes deliveries, joins work and releases callbacks. Idempotent; does not cancel work. */
    nothing close() {
        checkThread(); closed = True; on_finished = NOTHING; delivery.close();
        on_exit { busy = False; if (model.getState() == NcursesUi::ActionState::Running) { model.cancel(); } }
        join();
    }
    private nothing checkThread() { if (gettid() != ui_thread) { throw "UI-THREAD-ERROR", "Task lifecycle belongs to its UI thread"; } }
    private nothing runWork(code<auto()> work, hash<NcursesUi::ActionRequest> token) {
        on_exit workers.dec(); hash<NcursesUi::TaskResult> result = <NcursesUi::TaskResult>{};
        try { result.value = work(); } catch (hash<ExceptionInfo> ex) { result.error = ex; }
        try { delivery.post({"token": token, "result": result}); }
        catch (hash<ExceptionInfo> ex) { failure_mutex.lock(); on_exit failure_mutex.unlock(); delivery_failure = ex; }
    }
}
}
