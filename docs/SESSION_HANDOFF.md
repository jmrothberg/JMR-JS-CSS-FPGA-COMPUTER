# Session handoff — architecture recovery plan

Last updated: **2026-08-15**.

This product is a standalone JavaScript-native FPGA computer. The required
ladder is:

```text
loaded NAME.HTML → compile current source → JMR program image
→ exact Python hardware model → Verilator RTL → board → ASIC
```

No browser, dukpy, host twin, stale sidecar, title gate, or hidden host CPU may
stand in for a rung. `INVADERS.HTML`, `PACMAN.HTML`, and `DONKEY.HTML` are
integration/acceptance tests, not the ISA.

## Stop and read this first

The current problem is architectural, not three independent title bugs.
Do not continue title-by-title RTL patches. Do not build a `.bit`/`.bin`.

The tree currently has two different execution semantics:

- PYTHON compiles HTML, encodes a binary blob, then executes the original
  Python `Chunk` object (`functional_model/machine.py`), with Python
  numbers/objects/lists and effectively unbounded lifetimes.
- FPGA-SIM executes serialized words, hashed name tables, Q16.16/int tags,
  fixed arrays/objects/stacks, special closure environments, eight timers,
  and frame-time heap rewinds (`rtl/engines/jmr_js_vm.sv`).
- `hardware_model/js_vm.py` decodes the blob but then delegates execution back
  to the same functional Python VM. It does not model the RTL heap, tags,
  limits, stack frames, timer queue, or cycle-visible event semantics.

Therefore “PYTHON passes” does not validate what RTL receives. This is the
main reason fixes regress and snippets pass while titles fail.

## Honest observed status

No title is currently accepted on FPGA-SIM.

- **INVADERS:** keys reach RTL; game frames can cost about 5.58 million clocks;
  movement is painfully slow; a shot has not been proven to remove an alien.
  Existing traces show timers schedule/fire but no reliable title-level
  collision completion. Do not claim collision from a small `find/splice`
  snippet.
- **PACMAN:** arrow key events reach RTL, but movement has regressed before and
  ghosts have not been proven to leave the house. Traces show object allocation
  oscillating between roughly 2762 and 3384 at frame boundaries: the nursery
  rewind is changing/reusing heap state while live game objects exist. The
  KEYBITS keyup path also reports Down release as keyCode 38 (Up) instead of
  40; this can make games fight a released vertical key.
- **DONKEY:** title draws, Enter reaches RTL, then `raf` drops from 1 to 0 and
  stays there. Repeated Enter events cannot advance a callback that is no
  longer queued.
- **PYTHON BREAK digits:** `DONKEY.HTML` line 709 runs
  `console.log(this.x, this.y)` every frame. The repeated `280 608` lines are
  retained game logs revealed when BREAK repaints the monitor. This is a
  monitor/log policy defect, not random memory.
- **FPGA-SIM speed:** RAM-loading removes the long FAT startup, but gameplay is
  still slow. Full title frames observed at 1.1–5.6 million simulated clocks.
- **Board:** the current BOARD backend compiles HTML on the PC and streams the
  result over PROG. That is a development tether, not a standalone machine.
  J15 USB remains dead, but the JA keyboard and JB stick Pmod workaround has
  passed separately; see `docs/FPGA_BRINGUP.md`.

The previous handoff’s “done/do not reopen” claims were too strong. A green
feature snippet is a unit test only. Full deterministic title progression and
user F9 play are both required before a feature is accepted.

## Confirmed architecture gaps

1. **No on-machine compiler exists.** The Constitution specifies lexer,
   tokenizer, parser, and bytecode-generator engines, but there are no such RTL
   modules. Host compile + PROG stream cannot be the final standalone path.
2. **The loaded source is not the compiled source on BOARD/SIM.** Host backends
   reread `storage/NAME.HTML`. Donkey is 1,375,698 bytes, while RTL SOURCE BRAM
   is 131,072 bytes and silently keeps only a prefix.
3. **The number ABI is not shared.** Python uses Python int/float semantics;
   RTL mixes int32 and Q16.16 using tag-aware special cases. Math fixes are
   therefore local heuristics rather than one specified Number engine.
4. **Heap lifetime is guessed.** `n_obj_keep`, `n_arr_keep`,
   `ARR_KEEP_DELAY`, `commit_*_keep`, and `release_env_to` attempt to infer
   liveness from frame timing. Comments in the RTL record repeated cases where
   a live callback, child object, closure, or array was recycled.
5. **Stack resets hide defects.** Several frame/key paths force `sp` to zero or
   one. A boundary must assert balanced frames; silently clearing the stack can
   hide leaks and discard live values.
6. **Monitor state has multiple owners.** Python Machine, RTL VRAM, sim backend
   rerasterization, board mirror, and GUI prompt overlays can each mutate the
   glass. This caused text crossing F9 runtimes, LOAD row jumps, and disappearing
   command lines.
7. **The RTL VM is a monolith.** Language, heap, events, timers, strings,
   canvas dispatch, and raster loops share one very large module. This violates
   the documented engine boundaries and makes each semantic patch risky.
8. **Tests do not compare machine state.** Many tests only check a pixel count,
   one counter, or one frame. They do not compare value tags, stack frames,
   roots, heap graphs, callback queues, or monitor events across Python and RTL.

## Artifact decision: one in-memory program image

The user should never manage bytecode files.

- Disk/card source of truth: `NAME.HTML` only.
- `RUN` creates one versioned **ProgramImage** in memory: bytecode, debug/source
  map, string/name data, asset descriptors, palette, and ASET payload.
- PYTHON, FPGA-SIM, and BOARD consume the exact same ProgramImage byte stream.
- Do not write generated `.JSH` into `storage/`; do not list it in DIR/F10.
- Retire the `.JSB` versus `.JSH` product distinction. They already share the
  `JSB1` encoding; the different suffixes only encode history and confuse the
  architecture.
- Source demos should compile through the same ProgramImage path. Serialized
  golden vectors may exist only under test/build artifacts, never as card
  programs or preferred runtime input.
- Existing generated files are stale artifacts. Do not use them as truth and
  do not remove any file without the user’s explicit permission.

The final standalone board must generate this image itself. During architecture
recovery, host generation is allowed only as an explicitly labeled development
tool for testing the execution engine.

## Required recovery plan

### Phase 0 — freeze the churn and record baselines

- No title-specific patches, no title rewrites, no board build.
- Preserve existing traces and record deterministic short input scripts for
  each reported failure.
- Separate **verified**, **unit-tested**, and **user-accepted** status. Never
  promote one to another.

Exit gate: each failure has a reproducible state transition and no document
claims a title is green.

### Phase 1 — freeze the machine value/stack/heap contract

- Specify one 64-bit tagged `Value` ABI. Recommended direction for general
  Canvas JS is NaN-boxed IEEE-754 binary64 numbers plus explicit tags for
  undefined, bool, string, object, array, function, and element handles.
- Use one shared multi-cycle Number engine. Bitwise ops use specified `ToInt32`.
  Do not continue mixed int/Q16 heuristics.
- Define call frames (`return_ip`, `base_sp`, `this`, lexical environment,
  function) and assert stack balance at every return/event/frame boundary.
- Replace frame-watermark reclamation with a real stable-handle heap and
  deterministic mark/sweep at safe points. Roots include globals, eval/call
  stacks, lexical environments, listeners, rAF, timers, arrays/objects, and
  native-held handles. Overflow must halt with a loud machine error.

Exit gate: the contract document and Python tests cover arithmetic edge cases,
closures, cycles, nested callbacks, timers, listener removal, and collection.

### Phase 2 — make the Python hardware model real

- ProgramImage bytes are encoded once and decoded by the model that executes
  them. PYTHON must not execute the pre-serialization `Chunk`.
- Implement the exact tagged values, finite memories, heap collector, stack
  frames, queues, caps, overflow behavior, frame clock, and deterministic RNG.
- Keep the high-level functional VM only as a compiler/language oracle, not as
  proof of hardware parity.

Exit gate: corrupt trailers, capacity failures, stale handles, and stack
imbalance fail in PYTHON before RTL is touched.

### Phase 3 — differential conformance before titles

- Compile each semantic test once; feed the same ProgramImage to Python HM and
  RTL.
- Compare canonical checkpoints: IP/op, stack frame digest, globals, reachable
  heap digest, rAF/timer/listener queues, emitted canvas commands, monitor
  events, and errors.
- Add generational/random instruction sequences for arithmetic, object/array
  mutation, closure capture, GC roots, and callback ordering.
- Unit snippets remain useful, but every reported integration bug also gets a
  deterministic title-progression gate.

Exit gate: no checkpoint divergence across the frozen compatibility suite.

### Phase 4 — split and replace the RTL VM by engines

- Keep the sequencer and bytecode encoding where compatible.
- Extract Number/ALU, Heap/GC, Call/Environment, Event/Timer, String/JSON, and
  Canvas-command engines behind explicit request/response interfaces.
- Remove nursery rewinds, grace-frame constants, silent stack resets, and
  recycled callback OIDs only after their conformance replacements pass.
- Keep caps as general VM constants with loud overflow; never size or gate by
  title.

Exit gate: all Phase 3 checkpoints match RTL without title special cases.

### Phase 5 — one monitor and input contract

- Define ordered monitor events: command echo, output line, READY, prompt,
  MORE, game enter/exit, and error.
- Each backend owns its own framebuffer, command buffer, cursor, and history.
  F9 only selects a backend; GUI must not copy or synthesize another backend’s
  screen.
- GUI becomes a renderer/input forwarder, not another console implementation.
- Raw key down/up is queued exactly once and visible in the Architecture
  Monitor. HTML alone chooses bindings.
- While a game runs, `console.log` goes to a bounded diagnostic ring/trace.
  BREAK shows `^BREAK`, `READY`, and the prompt rather than flooding the glass
  with per-frame logs. One-shot console programs may publish their output when
  they return.

Exit gate: the same scripted monitor transcript and key-event sequence match
PYTHON, FPGA-SIM, and board RTL.

### Phase 6 — implement true compile-on-RUN hardware

- Build Python hardware models, then RTL engines, for HTML script streaming,
  tokenization, parsing, bytecode emission, source maps, base64/PNG ingest, and
  ASET loading.
- Do not require the full multi-megabyte HTML in BRAM. Compile from a streaming
  view of the loaded source plus editor changes; use external memory/scratch as
  specified, then reclaim scratch for assets.
- `RUN` must consume the loaded/editor source, never reread a host pathname.
- Remove BOARD host compilation from the product path. Tether compilation may
  remain only as an explicit bring-up mode.

Exit gate: with the PC disconnected, BOARD loads HTML from µSD, compiles it,
loads code/assets, reports HTML source-line errors, and runs.

### Phase 7 — performance as a machine requirement

- Set cycle budgets before optimization: 100 MHz / 60 Hz gives about
  1.67 million cycles per frame.
- Measure VM, full-canvas clear, paths, text, and blits separately.
- Raster/blitter engines must meet the board frame budget; Verilator must also
  meet an explicit wall-time target without host-twin shortcuts.
- Keep RAM-load/direct-memory setup for FPGA-SIM tests; it removes irrelevant
  SPI time but does not excuse a slow execution engine.

Exit gate: deterministic title scenarios run within cycle and wall-time budgets.

### Phase 8 — acceptance and only then `.bin`

Automated integration gates:

- INVADERS: start, held left/right changes player position, shot overlaps and
  removes an alien, game state does not reboot, sustained frames meet budget.
- PACMAN: all four arrows turn correctly, player does not fight released keys,
  each ghost leaves its start/house region, state survives collection.
- DONKEY: title → selection → gameplay via actual Enter events; rAF/timers remain
  live; BREAK returns to a clean monitor.

Then the user F9-tests PYTHON and FPGA-SIM. Only after user acceptance:

1. build `.bit`/`.bin`;
2. test the real board standalone;
3. update board/ASIC status.

## Current worktree: retain carefully, do not overclaim

The current uncommitted work spans 17 files. It includes useful development
transport and UI work, but it is not an accepted title fix.

Evidence-backed items worth retaining:

- ASCII `WORKING...`.
- 640×480 indexed framebuffer and 4 MB ASET SRAM architecture.
- FPGA-SIM direct ProgramImage/code/asset RAM loading instead of simulating
  multi-megabyte FAT transfers.
- Explicit one-shot `sim_frame_pulse` rather than free-running `FRAME_DIV=1`.
- `-O2` simulator build.
- Existing trace-first diagnostics and general semantic unit tests.
- The latest headless LOAD check now keeps
  `> LOAD "INVADERS.HTML"` and prints `LOADED...` on the following row.

Unverified changes in the worktree:

- per-runtime F9 screen reset;
- vertical-arrow `event.key` mapping;
- idle FRAME early completion;
- LOAD source bypass wiring;
- BOARD JSH tether;
- all title play/collision/progression behavior.

Do not call these done until their parity/integration gates pass.

## Failed approaches to retire

- Repeated title symptom patches inside the monolithic RTL VM.
- Treating zero overflow counters as proof that live objects are correct.
- Per-frame object/array watermarks and grace delays as garbage collection.
- Resetting the eval stack to hide imbalance.
- Pixel-count or “frame changed” checks as gameplay proof.
- Persistent `.JSH`/`.JSB` files in `storage/` or architecture-monitor catalogs.
- Host compilation/asset extraction presented as final BOARD compile-on-RUN.
- Increasing FRAME caps or changing SD SPI divisors to hide semantic stalls.
- Declaring a feature “done” because an isolated snippet passes.

## Key evidence and files

- Existing traces first: `traces/*_FPGA-SIM.log`, especially the tail.
- Functional execution: `functional_model/machine.py`,
  `functional_model/bytecode.py`.
- Binary format: `functional_model/jsb_format.py`.
- Current non-hardware HM facade: `hardware_model/js_vm.py`.
- RTL VM/heap/events: `rtl/engines/jmr_js_vm.sv`.
- Monitor/source loader: `rtl/engines/jmr_console_engine.sv`.
- FPGA-SIM transport/frame loop: `sim/sim_main.cpp`,
  `runtime/sim_backend.py`.
- Board host-compile tether: `runtime/board_backend.py`.
- Compiler/asset host implementation: `tools/compile_js.py`.
- Product rules: `CONSTITUTION.md`, `docs/ARCHITECTURE.md`,
  `docs/JMR_JS_COMPATIBILITY.md`.

Never delete files or rewrite the three title HTML files without explicit user
permission. No Vivado build until this recovery plan reaches Phase 8.
