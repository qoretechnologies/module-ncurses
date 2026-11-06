#! @file UiEventQueue.qc Owned delivery from workers to the UI thread
/* Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT */
public namespace NcursesUi {
hashdecl UiDelivery {
    int scope;
    auto payload;
}
hashdecl UiReceiver {
    code<nothing(auto)> callback;
    *code<bool()> available;
}
/** A worker-safe, bounded FIFO of data for UI-thread callbacks.
    Construct and drain on the UI thread. Each scope owns its receiver; closing a
    scope releases its receiver and pending payloads. Workers only call post().
    A finite initial batch is drained, so callbacks posting work cannot starve input.
    Callback failures propagate after consuming that delivery; later deliveries remain queued.
*/
public class UiEventQueue {
    private {
        Mutex mutex();
        int ui_thread = gettid();
        int capacity;
        *code<nothing()> notify;
        hash<string, hash<NcursesUi::UiReceiver>> receivers = {};
        hash<string, hash<NcursesUi::UiDelivery>> pending = {};
        int next_scope = 0;
        int head = 0;
        int tail = 0;
        bool closed = False;
        bool draining = False;
    }
    /** Creates a queue. @param wake called outside the queue lock after publication
        @param limit maximum pending deliveries @throw UI-QUEUE-LIMIT for a nonpositive limit */
    constructor(*code<nothing()> wake, int limit = 4096) {
        if (limit < 1) { throw "UI-QUEUE-LIMIT", "Queue capacity must be positive"; } capacity = limit; notify = wake;
    }
    /** Creates an owned receiver on the UI thread. @param callback receives posted data
        @param available optional UI-thread predicate; False permanently disposes this scope
        @return receiver handle @throw UI-QUEUE-CLOSED after close; UI-THREAD-ERROR off the UI thread */
    NcursesUi::UiEventScope createScope(code<nothing(auto)> callback, *code<bool()> available) {
        checkThread(); mutex.lock(); on_exit mutex.unlock();
        if (closed) { throw "UI-QUEUE-CLOSED", "The UI queue is closed"; }
        int id = ++next_scope; receivers{id} = <NcursesUi::UiReceiver>{"callback": callback, "available": available};
        on_error remove receivers{id};
        return new NcursesUi::UiEventScope(self, id);
    }
    /** Posts data from any thread. @param scope receiver ID @param payload application data (treat as immutable)
        @return False if the scope/queue is closed; True when accepted
        @throw UI-QUEUE-FULL at capacity; wake failures roll back undelivered work and propagate */
    bool post(int scope, auto payload) {
        int sequence; *code<nothing()> wake;
        {
            mutex.lock(); on_exit mutex.unlock();
            if (closed || !exists receivers{scope}) { return False; }
            if (pending.size() >= capacity) { throw "UI-QUEUE-FULL", "UI delivery queue is full"; }
            sequence = tail++; pending{sequence} = <NcursesUi::UiDelivery>{"scope": scope, "payload": payload}; wake = notify;
        }
        if (wake) {
            try { wake(); }
            catch (hash<ExceptionInfo> ex) {
                mutex.lock(); on_exit mutex.unlock();
                # Already consumed means publication succeeded. Otherwise rollback
                # this exact sequence, never a newer delivery or another scope.
                if (!exists pending{sequence}) { return !closed && exists receivers{scope}; }
                remove pending{sequence}; if (!pending) { head = tail; } rethrow;
            }
        }
        return True;
    }
    /** Disposes a receiver and all pending data; safe from any thread.
        A callback already selected for delivery may finish; UI-thread disposal prevents later callbacks.
        @param scope receiver ID @return True if the scope existed */
    bool dispose(int scope) {
        *hash<NcursesUi::UiReceiver> discarded_receiver; list<hash<NcursesUi::UiDelivery>> discarded = ();
        {
            mutex.lock(); on_exit mutex.unlock();
            if (!exists receivers{scope}) { return False; }
            discarded_receiver = remove receivers{scope};
            foreach string sequence in (keys pending) {
                if (pending{sequence}.scope == scope) { discarded += remove pending{sequence}; }
            }
            if (!pending) { head = tail; }
        }
        # Releasing arbitrary payloads/callback captures can run user destructors;
        # their final references must be released outside the queue lock.
        return True;
    }
    /** Delivers a finite initial batch on the UI thread. @return number of callbacks invoked
        @throw UI-THREAD-ERROR off the UI thread; UI-QUEUE-REENTRANT for nested drain; callback errors propagate */
    int drain() {
        checkThread(); if (draining) { throw "UI-QUEUE-REENTRANT", "UI delivery cannot be nested"; }
        draining = True; on_exit draining = False; int count = 0; int end;
        { mutex.lock(); on_exit mutex.unlock(); end = tail; }
        while (True) {
            *hash<NcursesUi::UiDelivery> item; *hash<NcursesUi::UiReceiver> receiver;
            {
                mutex.lock(); on_exit mutex.unlock();
                if (closed || head >= end) { return count; }
                item = remove pending{head++};
                if (item) { receiver = receivers{item.scope}; }
            }
            if (!item || !receiver) { continue; }
            if (receiver.available && !receiver.available()) { dispose(item.scope); continue; }
            { mutex.lock(); on_exit mutex.unlock(); if (!exists receivers{item.scope}) { continue; } }
            receiver.callback(item.payload); ++count;
        }
    }
    /** Disposes unavailable owners on the UI thread, even if no result was posted.
        @return number of scopes disposed; predicate exceptions propagate */
    int prune() {
        checkThread(); hash<string, hash<NcursesUi::UiReceiver>> snapshot;
        { mutex.lock(); on_exit mutex.unlock(); snapshot = receivers; }
        int count = 0;
        foreach hash<string, auto> pair in (snapshot.pairIterator()) {
            hash<NcursesUi::UiReceiver> receiver = pair.value;
            if (receiver.available && !receiver.available() && dispose(int(pair.key))) { ++count; }
        }
        return count;
    }
    /** Cancels pending deliveries and releases all receiver callbacks. Idempotent and worker-safe. */
    nothing close() {
        hash<string, hash<NcursesUi::UiReceiver>> discarded_receivers;
        hash<string, hash<NcursesUi::UiDelivery>> discarded_pending;
        *code<nothing()> discarded_notify;
        {
            mutex.lock(); on_exit mutex.unlock(); closed = True;
            discarded_receivers = receivers; discarded_pending = pending; discarded_notify = notify;
            receivers = {}; pending = {}; notify = NOTHING; head = tail;
        }
    }
    /** Returns pending delivery count, including work for unavailable owners until drained. @return count */
    int getPendingCount() { mutex.lock(); on_exit mutex.unlock(); return pending.size(); }
    /** Rejects UI operations on another thread. @throw UI-THREAD-ERROR for the wrong thread */
    nothing checkThread() { if (gettid() != ui_thread) { throw "UI-THREAD-ERROR", "UI operation must run on its owning thread"; } }
}
/** An explicit lifetime for posted results. Keep it while the receiver is active;
    call close() on teardown. A late worker post returns False after disposal. */
public class UiEventScope {
    private { NcursesUi::UiEventQueue queue; int id; }
    /** Creates a queue-owned scope. Prefer UiEventQueue::createScope(). @param owner queue @param token receiver ID */
    constructor(NcursesUi::UiEventQueue owner, int token) { queue = owner; id = token; }
    /** Publishes data to the UI thread. @param payload immutable application data @return accepted */
    bool post(auto payload) { return queue.post(id, payload); }
    /** Releases this receiver and pending payloads. @return True for the first disposal */
    bool close() { return queue.dispose(id); }
    destructor() { queue.dispose(id); }
}
} # namespace NcursesUi
