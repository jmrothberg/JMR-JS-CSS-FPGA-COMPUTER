# Paste this to the next agent

Read `docs/SESSION_HANDOFF.md` first. It replaces the previous
title-by-title debugging strategy with an architecture recovery plan. Also
read `CONSTITUTION.md`, `docs/ARCHITECTURE.md`,
`docs/JMR_JS_COMPATIBILITY.md`, `docs/FPGA_BRINGUP.md`, and every rule under
`.cursor/rules/`.

This is an **HTML-JavaScript native-instruction CPU**, analogous in product
method to the JMR BASIC computer but not derived from its instruction set
architecture. The shared ladder (contract, same-blob Python, lockstep of
**results not wall-clock**, compile loaded source, F9 before `.bit`) is in
`CONSTITUTION.md` under **Language-native computer method**. Python must
stay fast. Use it when updating BASIC or a later native graphics
processing unit too.

JavaScript is the architectural instruction surface:

```text
LOAD "NAME.HTML"
RUN
  → the machine reads the currently loaded/editor HTML
  → the machine tokenizes and compiles its JavaScript
  → internal JMR micro-ops/ProgramImage execute in hardware engines
  → Canvas, heap, events, timers, input, storage, and video are CPU engines
```

The user programs HTML and JavaScript, never a conventional hidden ISA.
Internal bytecode is like an implementation-level instruction stream: it is
not a user file, not a second version of the game, and not something the user
must save or load. Card/disk source of truth is `NAME.HTML`.

Hard requirements:

- No browser, Node, dukpy, Duktape, V8, QuickJS, soft CPU, Linux, or host twin
  may execute product game logic.
- FPGA-SIM means real Verilator RTL.
- Final BOARD must compile and run HTML while disconnected from the PC.
  Current host compile + PROG stream is bring-up only, not the product.
- Do not persist or prefer `.JSB`/`.JSH` sidecars. Use one ephemeral,
  versioned in-memory ProgramImage containing code, source map, descriptors,
  palette, and ASET data.
- PYTHON must execute the exact serialized ProgramImage with the exact finite
  value, stack, heap, closure, timer, event, and overflow contracts used by
  RTL. It must not execute the pre-serialization Python `Chunk` as parity
  proof.
- Replace guessed frame nursery watermarks and silent stack resets with stable
  handles, explicit call frames, real root tracing/collection, and loud
  overflow.
- Freeze one Number ABI and implement it identically in Python and RTL. Do not
  continue Python-float versus RTL int/Q16 special-case patches.
- One monitor/input event contract owns command echo, output, READY, prompt,
  MORE, game enter/exit, BREAK, and raw key down/up. GUI only renders and
  forwards input; each runtime owns its own screen and line buffer.
- Donkey is larger than RTL SOURCE BRAM. True compile-on-RUN must stream the
  loaded/editor source; it may never silently compile a 128 KiB prefix or
  reread a different host file.
- Keep full-quality ASET art in the external 4 MB SRAM architecture. No
  `NAME.DAT`, title-sized BRAM, downscaled title, or title gate.

Current truth:

- No title is accepted on FPGA-SIM.
- INVADERS is slow and collision removal is unproven.
- PACMAN keys arrive, but movement/ghost progression is unproven; heap rewinds
  and a Down-key release keyCode mismatch remain known defects.
- DONKEY receives Enter, then its rAF queue dies.
- Python BREAK reveals repeated `280 608` because DONKEY logs Mario coordinates
  every frame; game logs need a bounded diagnostic sink instead of flooding
  monitor history.
- Do not build `.bit`/`.bin`.

Work in the phases and exit gates in `docs/SESSION_HANDOFF.md`:

1. freeze the value/stack/heap contract;
2. make the Python hardware model execute the real ProgramImage;
3. build lockstep Python/RTL conformance checkpoints;
4. split/replace the monolithic RTL VM engines;
5. unify monitor and input;
6. implement the on-machine HTML/JS compiler and asset ingest;
7. meet cycle and Verilator wall-time budgets;
8. run deterministic title progression, user F9 acceptance, then board.

Existing traces come first. Start at the end of the newest FPGA-SIM/PYTHON
trace. Do not rerun heavy titles merely to rediscover a recorded failure.

Do not rewrite or hardwire `INVADERS.HTML`, `PACMAN.HTML`, or `DONKEY.HTML`.
Do not treat a pixel count, zero overflow counter, changed frame, snippet PASS,
or battery PASS as title acceptance. Unit semantic tests and full deterministic
integration gates are both required.

Do not delete files, add a README, flash the board, or broaden scope without
the user’s explicit permission. Keep changes incremental and surgical.
