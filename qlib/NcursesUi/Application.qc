#! @file Application.qc Top-level UI application orchestrator

/*  Application.qc Copyright 2026 Qore Technologies, s.r.o.

    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the "Software"),
    to deal in the Software without restriction, including without limitation
    the rights to use, copy, modify, merge, publish, distribute, sublicense,
    and/or sell copies of the Software, and to permit persons to whom the
    Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
    DEALINGS IN THE SOFTWARE.
*/

public namespace NcursesUi {
/** @internal A removable UI-thread tick callback. */
hashdecl UiTickCallback { code<nothing()> callback; *NcursesUi::Widget owner; }

/** Top-level application orchestrator.

    Manages the session, event loop, layout, and drawing. Clients
    create an Application, set a root widget, optionally configure
    callbacks and global key handlers, then call run().

    @par Example
    @code{.py}
    NcursesUi::Application app({"mouse": True});
    NcursesUi::Widget root();
    app.setRoot(root);
    app.run();
    @endcode

    @since ncurses 1.0
*/
public class Application {
    private {
        #! the ncurses session
        Ncurses::Session session;
        #! the event dispatcher
        NcursesUi::EventDispatcher dispatcher;
        #! the root widget
        *NcursesUi::Widget root;
        #! optional layout manager for root
        *NcursesUi::BoxLayout root_layout;
        #! tick callbacks
        hash<string, hash<NcursesUi::UiTickCallback>> tick_callbacks = {};
        int next_tick = 0;
        NcursesUi::UiEventQueue events;
        #! whether the event loop is running
        bool running = False;
        #! readEvent timeout in ms
        int read_timeout_ms = 100;
        #! readEvent poll interval in ms
        int poll_ms = 25;
        #! saved cursor visibility before first modal was pushed
        int saved_cursor = 1;
        bool saved_cursor_override = False;
        bool modal_cursor_active = False;
    }

    /** Creates a new Application with the given session options.
        @param opts session options (see Ncurses::Session constructor)
        @since ncurses 1.0
    */
    constructor(hash<auto> opts) {
        session = new Ncurses::Session(opts);
        dispatcher = new NcursesUi::EventDispatcher();
        Ncurses::Session target = session;
        events = new NcursesUi::UiEventQueue(sub () { target.wakeup(); });
    }

    /** Creates a new Application from an existing session.
        @param s the session to use
        @since ncurses 1.0
    */
    constructor(Ncurses::Session s) {
        session = s;
        dispatcher = new NcursesUi::EventDispatcher();
        Ncurses::Session target = session;
        events = new NcursesUi::UiEventQueue(sub () { target.wakeup(); });
    }

    /** Returns the session.
        @since ncurses 1.0
    */
    Ncurses::Session getSession() {
        return session;
    }

    /** Returns the event dispatcher.
        @since ncurses 1.0
    */
    NcursesUi::EventDispatcher getDispatcher() {
        return dispatcher;
    }

    /** Returns the focus manager.
        @since ncurses 1.0
    */
    NcursesUi::FocusManager getFocusManager() {
        return dispatcher.getFocusManager();
    }

    /** Returns the root widget.
        @since ncurses 1.0
    */
    *NcursesUi::Widget getRoot() {
        return root;
    }

    /** Sets the root widget and performs initial layout.
        @param w the root widget
        @since ncurses 1.0
    */
    nothing setRoot(NcursesUi::Widget w) {
        events.checkThread(); dispatcher.setRootScope(w);
        root = w; pruneCallbacks(); layoutRoot();
    }

    /** Sets a layout manager for the root widget.
        @param layout the layout to use
        @since ncurses 1.0
    */
    nothing setRootLayout(NcursesUi::BoxLayout layout) {
        root_layout = layout;
    }

    /** Sets a global key handler.
        @param handler the handler callback
        @since ncurses 1.0
    */
    nothing setGlobalKeyHandler(*code<hash<NcursesUi::EventResult>(hash<Ncurses::InputEvent>)> handler) {
        dispatcher.setGlobalKeyHandler(handler);
    }

    /** Adds a tick callback that fires after each event loop iteration.
        @param cb the callback
        @since ncurses 1.0
    */
    nothing addTickCallback(code<nothing()> cb) { addOwnedTickCallback(cb); }

    /** Adds a removable tick callback. @param callback UI-thread callback
        @param owner optional widget lifetime; hidden, disabled or detached owners are removed
        @return subscription ID for removeTickCallback() */
    int addOwnedTickCallback(code<nothing()> callback, *NcursesUi::Widget owner) {
        events.checkThread(); int id = ++next_tick;
        tick_callbacks{id} = <NcursesUi::UiTickCallback>{"callback": callback, "owner": owner}; return id;
    }
    /** Removes a tick callback and releases its captures. @param id subscription ID @return removed */
    bool removeTickCallback(int id) { events.checkThread(); return exists remove tick_callbacks{id}; }
    /** Creates an explicitly owned UI receiver. Workers call scope.post(payload);
        only this application's thread invokes the callback. Close the scope on teardown.
        @param callback UI mutation callback @param owner optional widget; hidden/disabled/detached owners are disposed
        @return scope; late posts after disposal return False */
    NcursesUi::UiEventScope createEventScope(code<nothing(auto)> callback, *NcursesUi::Widget owner) {
        return events.createScope(callback, owner ? bool sub () { return ownsAvailable(owner); } : NOTHING);
    }
    /** Delivers one finite batch and prunes obsolete callbacks on the UI thread.
        @return callbacks delivered; callback exceptions propagate */
    int processPending() { pruneCallbacks(); return events.drain(); }
    private bool ownsAvailable(NcursesUi::Widget owner) {
        if (!owner.isAvailable()) { return False; }
        if (root && root.containsWidget(owner)) { return True; }
        foreach NcursesUi::Widget modal in (dispatcher.getModalStack()) { if (modal.containsWidget(owner)) { return True; } }
        return False;
    }
    private nothing pruneCallbacks() {
        events.prune();
        foreach string id in (keys tick_callbacks) {
            *NcursesUi::Widget owner = tick_callbacks{id}.owner;
            if (owner && !ownsAvailable(owner)) { remove tick_callbacks{id}; }
        }
    }
    private nothing runTickCallbacks() {
        pruneCallbacks();
        foreach string id in (keys tick_callbacks) {
            *hash<NcursesUi::UiTickCallback> entry = tick_callbacks{id};
            if (entry && (!entry.owner || ownsAvailable(entry.owner))) { entry.callback(); }
        }
    }

    /** Pushes a modal, suspending focus and saving cursor visibility.
        Text inputs in the modal display a caret; other controls hide it.
        @param w modal widget
        @since ncurses 1.0
    */
    nothing pushModal(NcursesUi::Widget w) {
        on_exit updateModalCursor();
        dispatcher.pushModal(w);
    }

    /** Pushes a popup with outside-click dismissal and click-through.
        @param w popup widget
        @since ncurses 1.0
    */
    nothing pushPopup(NcursesUi::Widget w) {
        on_exit updateModalCursor();
        dispatcher.pushPopup(w);
    }

    /** Pops a modal and restores valid prior focus and cursor visibility.
        @return popped widget, or NOTHING for an empty stack
        @since ncurses 1.0
    */
    *NcursesUi::Widget popModal() {
        on_exit { pruneCallbacks(); updateModalCursor(); }
        return dispatcher.popModal();
    }

    /** Removes an owned scope while preserving overlays above it and their focus.
        The owner must still hide or destroy its native panel.
        @param widget modal or popup to remove
        @return True if removed, False if not active
        @throw MODAL-SCOPE-ERROR during a focus or modal transition
        @since ncurses 1.0
    */
    bool removeModal(NcursesUi::Widget widget) {
        on_exit { pruneCallbacks(); updateModalCursor(); }
        return dispatcher.removeModal(widget);
    }

    /** Overrides the cursor visibility restored after the last modal.
        Otherwise the visibility preceding the first modal is restored.
        @param visibility 0 (hidden), 1 (normal), or 2 (very visible)
        @throw CURSOR-VISIBILITY-ERROR for an invalid visibility
        @since ncurses 1.0
    */
    nothing setSavedCursor(int visibility) {
        if (visibility < 0 || visibility > 2) {
            throw "CURSOR-VISIBILITY-ERROR", "Cursor visibility must be 0, 1, or 2";
        }
        saved_cursor = visibility;
        saved_cursor_override = True;
    }

    private nothing updateModalCursor() {
        if (!session.isOpen()) {
            return;
        }
        if (dispatcher.hasModal()) {
            *NcursesUi::Widget focus = dispatcher.getFocusManager().getCurrentFocus();
            int previous = session.setCursor(focus && focus.wantsCursor() ? 1 : 0);
            if (!modal_cursor_active && !saved_cursor_override) {
                saved_cursor = previous;
            }
            modal_cursor_active = True;
        } else if (modal_cursor_active) {
            if (saved_cursor >= 0) {
                session.setCursor(saved_cursor);
            }
            modal_cursor_active = False;
        }
    }

    /** Sets the readEvent timeout parameters.
        @param timeout_ms total timeout in milliseconds
        @param poll poll interval in milliseconds
        @since ncurses 1.0
    */
    nothing setReadTimeout(int timeout_ms, int poll) {
        events.checkThread();
        if (timeout_ms < -1 || timeout_ms > 2147483647 || poll < 1 || poll > 2147483647) {
            throw "NCURSES-ERROR", "timeout_ms must be -1..INT_MAX and poll must be 1..INT_MAX";
        }
        read_timeout_ms = timeout_ms; poll_ms = poll;
    }

    /** Returns whether the event loop is running.
        @since ncurses 1.0
    */
    bool isRunning() {
        return running;
    }

    /** Runs the event loop.

        Loop: draw dirty widgets -> readEvent -> dispatch -> tick callbacks.
        Continues until quit() is called.

        @since ncurses 1.0
    */
    nothing run() {
        events.checkThread();
        if (running) { throw "UI-LOOP-REENTRANT", "Application event loop is already running"; }
        on_exit running = False;
        if (!root) {
            return;
        }
        running = True;
        Ncurses::Window screen = session.screen();

        try {
            while (running) {
                processPending();
                if (!running) { break; }
                # draw
                drawAll();

                # read event
                *hash<Ncurses::InputEvent> ev = screen.readEvent(read_timeout_ms, poll_ms);

                processPending();
                if (!running) { break; }
                # dispatch
                if (ev && ev.type != Ncurses::InputType::Wake) {
                    if (ev.type == Ncurses::InputType::Resize) {
                        handleResize();
                    } else {
                        processEvent(ev);
                    }
                }

                # tick callbacks
                runTickCallbacks();
            }
        } catch (hash<ExceptionInfo> ex) {
            close();
            rethrow;
        }
    }

    /** Processes a single event (for testing without the event loop).
        @param ev the event to process
        @return EventResult
        @since ncurses 1.0
    */
    hash<NcursesUi::EventResult> processEvent(hash<Ncurses::InputEvent> ev) {
        events.checkThread();
        if (ev.type == Ncurses::InputType::Wake) { processPending(); return <NcursesUi::EventResult>{"handled": True}; }
        if (!root) {
            return <NcursesUi::EventResult>{"handled": False};
        }
        if (ev.type == Ncurses::InputType::Resize) {
            handleResize();
            return <NcursesUi::EventResult>{"handled": True};
        }
        on_exit updateModalCursor();
        return dispatcher.dispatch(root, ev);
    }

    /** Stops the event loop.
        @since ncurses 1.0
    */
    nothing quit() {
        events.checkThread(); running = False;
    }

    /** Closes the session.
        @since ncurses 1.0
    */
    nothing close() {
        events.checkThread(); running = False; events.close(); tick_callbacks = {};
        on_exit { if (session.isOpen()) { session.close(); } }
        dispatcher.cancelMouseCapture();
    }

    /** Performs a full draw cycle.
        @since ncurses 1.0
    */
    nothing drawAll() {
        pruneCallbacks();
        if (!root) {
            return;
        }
        dispatcher.getFocusManager().reconcile(dispatcher.topModal() ?? root);
        updateModalCursor();
        # Non-panel overlays share the root surface. Their previous pixels must be
        # restored when their geometry, visibility or content changes.
        foreach NcursesUi::Widget modal in (dispatcher.getModalStack()) {
            if (!(modal instanceof NcursesUi::PanelWidget) && modal.isDirty()) { root.markDirty(); }
        }
        bool dirty = root.isDirty();
        foreach NcursesUi::Widget modal in (dispatcher.getModalStack()) { if (modal.isDirty()) { dirty = True; } }
        if (!dirty) { return; }
        bool exposed = root.isDirty();
        root.drawTree(session.screen());
        # draw modal widgets (they have their own panel windows)
        list<NcursesUi::Widget> modals = dispatcher.getModalStack();
        foreach NcursesUi::Widget modal in (modals) {
            bool changed = exposed || modal.isDirty();
            modal.drawTree(session.screen(), exposed);
            exposed = changed;
        }
        session.updatePanels();
        session.doupdate();
    }

    /** Lays out the root widget to fill the terminal.
        @since ncurses 1.0
    */
    nothing layoutRoot() {
        if (!root) {
            return;
        }
        hash<Ncurses::Size> sz = session.screen().size();
        root.setFrame(NcursesUi::Geometry::makeRect(0, 0, sz.rows, sz.cols));
        if (root_layout) {
            root_layout.apply(root);
        } else {
            root.layout();
        }
    }

    /** Handles a terminal resize event.
        @since ncurses 1.0
    */
    private nothing handleResize() {
        dispatcher.cancelMouseCapture();
        layoutRoot();
        hash<Ncurses::Size> size = session.screen().size();
        foreach NcursesUi::Widget modal in (dispatcher.getModalStack()) {
            modal.fitToScreen(size.rows, size.cols);
        }
        if (root) {
            root.markDirty();
        }
    }
}

} # namespace NcursesUi
