#! @file BackgroundTask.qc Single-operation worker with UI-owned completion
/* Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT */
public namespace NcursesUi {
#! Worker outcome; exceptions are data until delivered on the UI thread.
public hashdecl TaskResult { auto value; *hash<ExceptionInfo> error; }
hashdecl TaskDeliveryFailure { hash<NcursesUi::ActionRequest> token; hash<ExceptionInfo> error; }
/** Runs one worker at a time, delivering completion through Application's wake queue.
    Start and callbacks belong to the UI thread; work must never access widgets.
    A task remains busy until its completion is delivered, preventing overlapping
    evaluator/resource access. close() discards callbacks and joins work; it does
    not cancel the underlying operation. cancel() explicitly requests cooperative cancellation.
    Call join() only for deterministic testing or shutdown, never in input handlers.
*/
public class BackgroundTask {
    private {
        NcursesUi::ActionModel model;
        NcursesUi::Application app;
        Ncurses::Session session;
        int recovery_tick;
        NcursesUi::UiEventScope delivery;
        Counter workers(0);
        int ui_thread = gettid();
        bool closed = False;
        bool busy = False;
        *code<nothing(hash<NcursesUi::TaskResult>)> on_finished;
        Mutex failure_mutex();
        *hash<NcursesUi::TaskDeliveryFailure> delivery_failure;
        Mutex worker_mutex();
        int worker_tid = 0;
        bool worker_done = True;
        *string cancellation;
    }
    /** Creates a task. @param app UI owner @param id stable action ID @param label operation label */
    constructor(NcursesUi::Application app, string id, string label) {
        self.app = app; session = app.getSession();
        model = new NcursesUi::ActionModel(id, label);
        delivery = app.createEventScope(sub (auto payload) { finish(payload.token, payload.result); });
        on_error delivery.close();
        recovery_tick = app.addOwnedTickCallback(sub () { processPending(); });
    }
    private nothing finish(hash<NcursesUi::ActionRequest> token, hash<NcursesUi::TaskResult> result) {
        if (closed) { return; }
        bool accepted = result.error ? model.fail(token, result.error.desc) : model.complete(token, result.value);
        if (!accepted) { return; }
        busy = False;
        *code<nothing(hash<NcursesUi::TaskResult>)> callback = on_finished; on_finished = NOTHING;
        if (callback) { callback(result); }
    }
    /** Recovers a failed queue delivery on the UI thread, invoking the outcome callback once.
        Application's event loop calls this automatically each turn; embedders without
        that loop can call it after Application::processPending(). No worker join is needed.
        @return whether a delivery failure was consumed @throw callback errors propagate */
    bool processPending() {
        checkThread(); *hash<NcursesUi::TaskDeliveryFailure> failure;
        { failure_mutex.lock(); on_exit failure_mutex.unlock(); failure = delivery_failure; delivery_failure = NOTHING; }
        if (!failure) { return False; }
        finish(failure.token, <NcursesUi::TaskResult>{"error": failure.error}); return True;
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
        { worker_mutex.lock(); on_exit worker_mutex.unlock(); cancellation = NOTHING; worker_done = False; }
        try { background runWork(work, token); }
        catch (hash<ExceptionInfo> ex) { workers.dec(); busy = False; on_finished = NOTHING; model.fail(token, ex.desc); rethrow; }
    }
    /** Requests cancellation without blocking the UI. Work may catch or defer cancellation.
        @param reason explanation delivered to work @return whether unfinished work accepted the request
        @note Completion is still delivered normally as TaskResult; close() retains its explicit join semantics.
    */
    bool cancel(string reason = "Task cancelled") {
        checkThread(); if (closed || !busy) { return False; }
        worker_mutex.lock(); on_exit worker_mutex.unlock();
        if (worker_done) { return False; }
        cancellation = reason;
        return worker_tid ? cancel_thread(worker_tid, reason) : True;
    }
    /** Joins the worker without dispatching callbacks. Call Application::processPending() afterward.
        @throw worker delivery error if the application's queue could not accept/wake */
    nothing join() {
        checkThread(); workers.waitForZero(); failure_mutex.lock(); on_exit failure_mutex.unlock();
        if (delivery_failure) { throw delivery_failure.error.err, delivery_failure.error.desc, delivery_failure.error.arg; }
    }
    /** Disposes deliveries, joins work and releases callbacks. Idempotent; does not cancel work. */
    nothing close() {
        checkThread(); closed = True; on_finished = NOTHING; app.removeTickCallback(recovery_tick); delivery.close();
        on_exit { busy = False; if (model.getState() == NcursesUi::ActionState::Running) { model.cancel(); } }
        join();
    }
    private nothing checkThread() { if (gettid() != ui_thread) { throw "UI-THREAD-ERROR", "Task lifecycle belongs to its UI thread"; } }
    private nothing runWork(code<auto()> work, hash<NcursesUi::ActionRequest> token) {
        on_exit workers.dec(); hash<NcursesUi::TaskResult> result = <NcursesUi::TaskResult>{};
        try {
            # Publish ownership only inside the catch/cleanup scope. The same mutex protects
            # cancellation and retirement, so a recycled thread ID can never be targeted.
            on_exit defer_thread_cancel(sub () {
                worker_mutex.lock(); on_exit worker_mutex.unlock(); worker_tid = 0; worker_done = True; clear_thread_cancel();
            });
            { worker_mutex.lock(); on_exit worker_mutex.unlock();
                if (exists cancellation) { throw "THREAD-CANCELLED", cancellation; }
                worker_tid = gettid(); }
            result.value = work();
        } catch (hash<ExceptionInfo> ex) { result.error = ex; }
        try { delivery.post({"token": token, "result": result}); }
        catch (hash<ExceptionInfo> ex) {
            { failure_mutex.lock(); on_exit failure_mutex.unlock();
                delivery_failure = <NcursesUi::TaskDeliveryFailure>{"token": token, "error": ex}; }
            # Recovery has its own bounded slot. Wake once after publishing it, even
            # when the ordinary queue was full; a failed terminal wake is surfaced by join().
            try { session.wakeup(); } catch (hash<ExceptionInfo> wake_error) {}
        }
    }
}
}
