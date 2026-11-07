# Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT
# Full applications need their real event loop between browser commands. A control
# reader posts requests to the UI thread; PTY fences acknowledge input explicitly.
class NativeApplicationBridge {
    private {
        NcursesUi::Application app;
        NcursesGallery::Runner runner;
        File protocol;
        File terminal;
        NcursesUi::UiEventScope commands;
        EventNotifier stop();
        Counter readers(0);
        list<hash<Ncurses::InputEvent>> pending = ();
        *hash<auto> input;
        bool routing = False;
        bool stopped = False;
        int tick;
        list<hash<auto>> control_pending = ();
    }
    constructor(NcursesUi::Application application, NcursesGallery::Runner story, File output, File tty) {
        app = application; runner = story; protocol = output; terminal = tty;
        commands = app.createEventScope(sub (auto command) { control_pending += command; });
    }
    nothing run() {
        on_exit close();
        app.setGlobalKeyHandler(hash<NcursesUi::EventResult> sub (hash<Ncurses::InputEvent> event) {
            if (routing) { return <NcursesUi::EventResult>{}; }
            if (pending.size() >= 32768) { throw "GALLERY-INPUT-LIMIT", "Unacknowledged input exceeded its limit"; }
            pending += event; drainInput(); return <NcursesUi::EventResult>{"handled": True};
        });
        tick = app.addOwnedTickCallback(sub () {
            list<hash<auto>> batch = control_pending; control_pending = ();
            foreach hash<auto> command in (batch) { dispatch(command); }
        });
        app.setReadTimeout(-1, 25); readers.inc();
        try { background readCommands(); } catch (hash<ExceptionInfo> ex) { readers.dec(); rethrow; }
        complete(0); app.run();
        # Intentional application quit may occur before readEvent consumes the input
        # fence. The final composed frame is the completion for that command.
        if (input) { int sequence = input.sequence; input = NOTHING; complete(sequence); }
        protocol.printf("%s\n", make_json({"type": "ended"}));
    }
    private nothing complete(int sequence, *hash<auto> captured) {
        hash<auto> artifact = captured ?? runner.capture(); artifact.index = runner.checkpointIndex();
        terminal.write(sprintf("\e]777;ncurses-gallery;%d\a", sequence));
        protocol.printf("%s\n", make_json({"type": "frame", "sequence": sequence, "artifact": artifact}));
    }
    private nothing dispatch(hash<auto> command) {
        if (command.action == "close") { app.quit(); return; }
        if (command.error) { throw "GALLERY-CONTROL-ERROR", command.error; }
        try {
            *hash<auto> captured;
            switch (command.action) {
                case "input": input = command; drainInput(); return;
                case "capture": break;
                case "settle": runner.settle(); break;
                case "reset": runner.reset(); break;
                case "step":
                    routing = True;
                    try { captured = runner.step(); } catch (hash<ExceptionInfo> ex) { routing = False; rethrow; }
                    routing = False; break;
                case "resize":
                    app.getSession().resize(int(command.rows), int(command.cols));
                    app.processEvent(<Ncurses::InputEvent>{"type": Ncurses::InputType::Resize}); break;
                default: throw "GALLERY-COMMAND-ERROR", "Unknown bridge action";
            }
            complete(int(command.sequence), captured);
        } catch (hash<ExceptionInfo> ex) { report(command, ex); }
    }
    private nothing drainInput() {
        if (!input || routing) { return; }
        try {
            while (pending) {
                hash<Ncurses::InputEvent> event = shift pending;
                bool fence = event.ch == "\x1e" && (event.type == Ncurses::InputType::Char || event.type == Ncurses::InputType::Alt);
                if (!fence || event.type == Ncurses::InputType::Alt) {
                    if (fence) { event = <Ncurses::InputEvent>{"type": Ncurses::InputType::Char, "ch": "\e"}; }
                    routing = True;
                    try { if (!runner.handleEvent(event).handled) { app.processEvent(event); } }
                    catch (hash<ExceptionInfo> ex) { routing = False; rethrow; }
                    routing = False;
                }
                if (fence) { int sequence = input.sequence; input = NOTHING; complete(sequence); break; }
            }
        } catch (hash<ExceptionInfo> ex) { hash<auto> command = input; input = NOTHING; report(command, ex); }
    }
    private nothing report(hash<auto> command, hash<ExceptionInfo> ex) {
        bool fatal = command.action == "input";
        protocol.printf("%s\n", make_json({"type": "error", "sequence": command.sequence, "error": ex.err, "description": ex.desc, "fatal": fatal}));
        if (fatal) { app.quit(); }
    }
    private nothing readCommands() {
        on_exit readers.dec(); binary tail = binary();
        try {
            while (True) {
                list<hash<SocketPollInfo>> ready = Socket::poll((<SocketPollInfo>{"socket": stdin, "events": SOCK_POLLIN},
                    <SocketPollInfo>{"socket": stop, "events": SOCK_POLLIN}), -1);
                bool closing = False;
                foreach hash<SocketPollInfo> entry in (ready) { if (entry.socket == stop) { closing = True; } }
                if (closing) { return; }
                *binary bytes = stdin.readShortBinary(4096, 0);
                if (!bytes) { commands.post({"action": "close"}); return; }
                tail += bytes;
                if (tail.size() > 131072) { throw "GALLERY-CONTROL-LIMIT", "Control message exceeded its limit"; }
                int newline;
                while ((newline = tail.find(<0a>)) >= 0) {
                    string line = binary_to_string(tail.substr(0, newline), "UTF-8"); tail = tail.substr(newline + 1);
                    if (!commands.post(parse_json(line))) { return; }
                }
            }
        } catch (hash<ExceptionInfo> ex) { commands.post({"error": ex.desc}); }
    }
    nothing close() {
        if (stopped) { return; } stopped = True;
        commands.close(); app.removeTickCallback(tick); stop.notify(); readers.waitForZero(); app.setGlobalKeyHandler(NOTHING);
    }
}
