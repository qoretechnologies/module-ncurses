# Native widget review protocol

Copyright 2026 Qore Technologies, s.r.o.

The shared Qore registry is executable tooling under `examples/gallery`, not an
installed user module. Native gallery, headless tests and generated Storybook CSF
stories all use its stable IDs, fixtures, geometries, events and expectations.
Fixture model deliveries execute on the UI thread and make background/stale-result
scenarios deterministic without timers or external services.

The browser connects to a loopback-only WebSocket server. One connection owns one
`NativeStory`, one Python supervisor, one PTY and one Qore process. Startup accepts
only an ID in the exported registry and bounded geometry. Qore uses the PTY slave
exclusively for ncurses I/O; stdin/stdout are private JSON control pipes. The
supervisor multiplexes control, raw PTY bytes and native frames with asyncio and
file-descriptor readiness. Commands are serialized by the server and native owner.
No client-supplied executable or shell command is evaluated.

For input, the supervisor writes actual terminal bytes followed by U+001E. The
native loop consumes events until the reserved fence; a standalone Escape followed
by the fence is decoded as Escape rather than relying on a timer. The bridge
rejects fence characters in input. UTF-8 and xterm's byte-oriented Latin-1 transport
are distinguished explicitly. Mouse integration replays SGR reports, including
terminals that deliver press/release pairs instead of aggregated click events.

After processing a command, the runner completes `drawAll()` and observational
`Session::capture()`. It writes an OSC 777 sequence marker to the same PTY stream,
then emits the corresponding semantic frame on the control pipe. The browser waits
for that exact marker to be parsed by xterm, requests a render, and waits for
`onRender` before resolving the request. This orders native drawing, transport,
parsing and painting without sleeps, polling or assumptions about network latency.

A reset releases the old fixture/modal tree and reconstructs the same story at its
initial geometry. A resize applies TIOCSWINSZ and ncurses logical resize before its
explicit layout checkpoint. Same-page story replacement awaits prior disposal.
Disconnect closes the control pipe, which unwinds Qore `on_exit` cleanup. The
supervisor reaps its child and closes both PTY descriptors. Startup/command/graceful
close deadlines reject pending operations; bounded hard termination covers a
stuck process. An unexpectedly dead supervisor also causes its owned native
process group to be terminated. Qore inherits the isolated supervisor process group,
so termination does not depend on receiving the native PID announcement first.
Browser rejection paths release parse/render
barriers and resources. Tests observe process-exit events, including Linux pidfds
for the supervisor-crash case.

The artifact manifest describes the renderer configuration and hashes each PNG and
compressed semantic frame. Comparisons include every cell, color/attribute,
continuation, cursor, focus and scroll value plus exact image pixels. An incomplete
run cannot be accepted. A separate acceptance command requires identified review
evidence, verifies artifact hashes and records that evidence's digest. CI only
compares and publishes artifacts. The checked-in review record contains per-widget
interaction observations and dispositions; tests alone are not presented as proof
of usability.

## Bridge choice

`ttyd` 1.7.7 was evaluated with its released Linux binary (SHA-256
`8a217c968aba172e0dbf3f34447218dc015bc4d5e59bf51db2f2cd12b7be4f55`). A loopback,
run-once session launched the real table gallery, accepted End through its WebSocket
protocol, displayed the last row and terminated its child on disconnect. Its
[protocol](https://github.com/tsl0922/ttyd/blob/1.7.7/src/server.h) supports terminal
input/output, resize and flow control, but has no native semantic-frame/checkpoint
channel. This workflow would still need a separate instrumented gallery/control
channel. The implemented Python standard-library PTY supervisor keeps both channels
under one bounded lifecycle and avoids adding a platform-specific bridge binary.
The browser terminal remains upstream [xterm.js](https://xtermjs.org/docs/), and
Storybook supplies navigation, direct links and args rather than duplicated widget
implementations.

## Mouse geometry

Button and checkbox action regions intersect their one painted row/label with
ancestor visibility and the last drawing target. Unused layout rows/columns and
padding do not activate them. A fully clipped draw clears its target. Attachment
actions retain typed source spans after text normalization; wrapped/scrolled mouse
coordinates round-trip through `LineListContent` before dispatch. Completion popup
mouse selection and keyboard acceptance share the same highlight/callback path.
Timeline selection and file toggles accept native primary presses as well as
synthesized clicks; release events do not repeat an action.
