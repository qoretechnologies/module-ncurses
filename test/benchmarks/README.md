# Text layout benchmark

Copyright 2026 Qore Technologies, s.r.o.

Run from an otherwise idle checkout after configuring and building Release:

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
cmake --build build -j4
rg CMAKE_BUILD_TYPE build/CMakeCache.txt
QORE_MODULE_DIR=build:build/qlib-qmod qore --enable-debug --warnings-are-errors test/benchmarks/text-layout.qr
```

The script uses monotonic microseconds and compiled local user modules. Rebuild after
changing any module source: stale compiled modules must fail validation instead of
falling back to an installed module. Run three independent trials and compare medians.
Measurements are local observations, not portable test thresholds. Deterministic
work-count assertions live in `ncurses-incremental.qtest`, `ncurses-dirty.qtest`,
`ncurses-input.qtest` and `ncurses-transcript.qtest`.

## Recorded comparison: 2026-11-06

Environment: x86_64 Linux, Qore 3.0.0, CMake Release (`-O3 -DNDEBUG`), compiled user
modules. Before: module commit `e9f41432e12671d1626909a3d99e9e09fb0e7839`.
After: source digest `7749f5c7bdfdb3e72c7b02f68f81ce0529df8d9821e7c55b6eac5912c99309fb`
on base `87119f000afe26a7a26d3d9a4f373afde6617bb8`. The digest hashes sorted paths,
NUL, file bytes, NUL for `src`/`qlib` `.qpp/.cpp/.h/.qm/.qc` files and `bin/qrepl`.
The identical benchmark script was used for both builds; raw trials are in
[`results-20261106.csv`](results-20261106.csv).

| Workload | Count | Before median (ms) | After median (ms) |
|---|---:|---:|---:|
| grow | 250 | 1,797.275 | 42.647 |
| grow | 1,000 | 29,775.543 | 173.952 |
| batch | 5,000 | 238.441 | 340.242 |
| edit | 50 | 12,729.533 | 9.402 |
| resize | 5 | 1,556.153 | 1,378.627 |
| idle | 10,000 | 591.600 | 67.399 |
| cursor-x | 200 | 2,810.053 | 3.456 |
| cursor-é | 200 | 2,841.642 | 3.207 |
| cursor-👩🏽‍💻 | 200 | 3,062.751 | 3.271 |

`grow` appends one 120-character mixed Unicode line at a time and queries wrapped
rows at width 60 after every append. `batch` sets 5,000 such lines and prepares
width 60 once. `edit` replaces logical line 2,500 fifty times. `resize` prepares
widths 30, 59, 60, 79 and 80. `idle` requests 10,000 unchanged draws after one initial
paint: total paints fall from 10,001 to 1. Cursor workloads perform 200 left/right
pairs in 16,384 repeated ASCII, combining-accent or joined-emoji graphemes.

Streaming appends, single-line edits and cached cursor movement improve substantially.
First bulk layout is about 43% slower in this run because it also constructs stable
identities, per-line source records and indexes. Resize remains linear in retained
text. This is a measured cost of the incremental representation; retention bounds
memory and work, and batching avoids repeated initial layout. These timings include
Qore-level bookkeeping and do not measure an entire interactive application's latency.
