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

/** Top-level application orchestrator.

    Manages the session, event loop, layout, and drawing. Clients
    create an Application, set a root widget, optionally configure
    callbacks and global key handlers, then call run().

    @par Example
    @code
    NcursesUi::Application app({"mouse": True});
    NcursesUi::Widget root();
    app.setRoot(root);
    app.run();
    @endcode

    @since ncurses 2.0
*/
public namespace NcursesUi {
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
        list<code> tick_callbacks = ();
        #! whether the event loop is running
        bool running = False;
        #! readEvent timeout in ms
        int read_timeout_ms = 100;
        #! readEvent poll interval in ms
        int poll_ms = 25;
        #! saved cursor visibility before first modal was pushed
        int saved_cursor = 1;
    }

    /** Creates a new Application with the given session options.
        @param opts session options (see Ncurses::Session constructor)
        @since ncurses 2.0
    */
    constructor(hash<auto> opts) {
        session = new Ncurses::Session(opts);
        dispatcher = new NcursesUi::EventDispatcher();
    }

    /** Creates a new Application from an existing session.
        @param s the session to use
        @since ncurses 2.0
    */
    constructor(Ncurses::Session s) {
        session = s;
        dispatcher = new NcursesUi::EventDispatcher();
    }

    /** Returns the session.
        @since ncurses 2.0
    */
    Ncurses::Session getSession() {
        return session;
    }

    /** Returns the event dispatcher.
        @since ncurses 2.0
    */
    NcursesUi::EventDispatcher getDispatcher() {
        return dispatcher;
    }

    /** Returns the focus manager.
        @since ncurses 2.0
    */
    NcursesUi::FocusManager getFocusManager() {
        return dispatcher.getFocusManager();
    }

    /** Returns the root widget.
        @since ncurses 2.0
    */
    *NcursesUi::Widget getRoot() {
        return root;
    }

    /** Sets the root widget and performs initial layout.
        @param w the root widget
        @since ncurses 2.0
    */
    nothing setRoot(NcursesUi::Widget w) {
        root = w;
        layoutRoot();
    }

    /** Sets a layout manager for the root widget.
        @param layout the layout to use
        @since ncurses 2.0
    */
    nothing setRootLayout(NcursesUi::BoxLayout layout) {
        root_layout = layout;
    }

    /** Sets a global key handler.
        @param handler the handler callback
        @since ncurses 2.0
    */
    nothing setGlobalKeyHandler(*code<hash<NcursesUi::EventResult>(hash<Ncurses::InputEvent>)> handler) {
        dispatcher.setGlobalKeyHandler(handler);
    }

    /** Adds a tick callback that fires after each event loop iteration.
        @param cb the callback
        @since ncurses 2.0
    */
    nothing addTickCallback(code cb) {
        tick_callbacks += cb;
    }

    /** Pushes a modal widget.

        Hides the cursor when the first modal is pushed.

        @param w the widget to make modal
        @since ncurses 2.0
    */
    nothing pushModal(NcursesUi::Widget w) {
        if (!dispatcher.hasModal()) {
            # first modal - hide cursor
            session.setCursor(0);
        }
        dispatcher.pushModal(w);
    }

    /** Pops the topmost modal widget.

        Restores cursor visibility when the last modal is popped.

        @return the popped widget
        @since ncurses 2.0
    */
    *NcursesUi::Widget popModal() {
        *NcursesUi::Widget w = dispatcher.popModal();
        if (!dispatcher.hasModal()) {
            # last modal popped - restore cursor
            session.setCursor(saved_cursor);
        }
        return w;
    }

    /** Sets the cursor visibility to restore when the last modal is popped.
        @param visibility cursor visibility (0=invisible, 1=normal, 2=very visible)
        @since ncurses 2.0
    */
    nothing setSavedCursor(int visibility) {
        saved_cursor = visibility;
    }

    /** Sets the readEvent timeout parameters.
        @param timeout_ms total timeout in milliseconds
        @param poll poll interval in milliseconds
        @since ncurses 2.0
    */
    nothing setReadTimeout(int timeout_ms, int poll) {
        read_timeout_ms = timeout_ms;
        poll_ms = poll;
    }

    /** Returns whether the event loop is running.
        @since ncurses 2.0
    */
    bool isRunning() {
        return running;
    }

    /** Runs the event loop.

        Loop: draw dirty widgets -> readEvent -> dispatch -> tick callbacks.
        Continues until quit() is called.

        @since ncurses 2.0
    */
    nothing run() {
        if (!root) {
            return;
        }
        running = True;
        Ncurses::Window screen = session.screen();

        try {
            while (running) {
                # draw
                drawAll();

                # read event
                *hash<Ncurses::InputEvent> ev = screen.readEvent(read_timeout_ms, poll_ms);

                # dispatch
                if (ev) {
                    if (ev.type == Ncurses::InputType::Resize) {
                        handleResize();
                    } else {
                        dispatcher.dispatch(root, ev);
                    }
                }

                # tick callbacks
                foreach code cb in (tick_callbacks) {
                    cb();
                }
            }
        } catch (hash<ExceptionInfo> ex) {
            close();
            rethrow;
        }
    }

    /** Processes a single event (for testing without the event loop).
        @param ev the event to process
        @return EventResult
        @since ncurses 2.0
    */
    hash<NcursesUi::EventResult> processEvent(hash<Ncurses::InputEvent> ev) {
        if (!root) {
            return <NcursesUi::EventResult>{"handled": False};
        }
        if (ev.type == Ncurses::InputType::Resize) {
            handleResize();
            return <NcursesUi::EventResult>{"handled": True};
        }
        return dispatcher.dispatch(root, ev);
    }

    /** Stops the event loop.
        @since ncurses 2.0
    */
    nothing quit() {
        running = False;
    }

    /** Closes the session.
        @since ncurses 2.0
    */
    nothing close() {
        running = False;
        if (session.isOpen()) {
            session.close();
        }
    }

    /** Performs a full draw cycle.
        @since ncurses 2.0
    */
    nothing drawAll() {
        if (!root) {
            return;
        }
        root.drawTree(session.screen());
        # draw modal widgets (they have their own panel windows)
        list<NcursesUi::Widget> modals = dispatcher.getModalStack();
        foreach NcursesUi::Widget modal in (modals) {
            modal.drawTree(session.screen());
        }
        session.updatePanels();
        session.doupdate();
    }

    /** Lays out the root widget to fill the terminal.
        @since ncurses 2.0
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
        @since ncurses 2.0
    */
    private nothing handleResize() {
        layoutRoot();
        if (root) {
            root.markDirty();
        }
    }
}

} # namespace NcursesUi
