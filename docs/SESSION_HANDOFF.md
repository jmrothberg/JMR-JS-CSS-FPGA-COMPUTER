# Session handoff

**2026-08-16 night.** This file is **current truth only**.

Product plan (steps, not glass): [`working_html_fpga-sim`](/home/jonathan/.cursor/plans/working_html_fpga-sim_a719ac28.plan.md). Read that file and follow it. PYTHON glass for INVADERS / PACMAN / DONKEY is **user-confirmed**. Do not mark FPGA-SIM F9 green. **No `.bin` until F9.** INVADERS starts on **Space**.

## User last saw

| Runtime | Title | Glass |
|---|---|---|
| PYTHON | INVADERS / PACMAN / DONKEY | play |
| PYTHON | MRDO | loads/plays at **~1 fps** |
| FPGA-SIM | PACMAN | **still bounces to READY.** Newest: `traces/session_20260817_023235_222288_FPGA-SIM.log` — `S_DONE` **`fault=2` `ip=1718` `vcsp=128`** `arr=1571` `raf=0` `fclk≈2.1M` (not 241). IP 1718 is `new Stage(options)` in `createStage` (HTML ~404) during `_COIGIG.forEach`. |

## PACMAN bounce (fault 2 this glass, 241 was the previous one)

Do not no-op ARRAY_SET 241. Do not edit `storage/PACMAN.HTML`.

Previous 241 fix refilled TOS `win[1..]` from BRAM on **every BIND / forEach-done / RET_VAL**. Glass then died at **call-stack overflow** (`fault=2`, `CSTK=128`) while constructing stages — BIND refill was speculative and ran on constructors. **Reverted BIND and forEach-done WIN_FILL.** RET_VAL refill when `base>=1` stays (that is the `item.path = finder()` hole the snippet proved).

Lockstep after revert: `test_hw_value64_nested_foreach_finder_paths`, `test_rtl_value64_nested_foreach_finder`, plus `test_*_foreach_ctor_assign_function_prop` (12× `new Ctor` + `Object.assign` of a function prop inside forEach — `fault=0`, pixels). `make -C sim sim_server_synth` rebuilt. **No `.bin`.**

Restart the GUI, F9 FPGA-SIM `(RTL)`, `LOAD "PACMAN.HTML"` / `RUN`.

## MRDO speed (not a hang)

Attract/play always `paintField()`: **24×26** tiles, each dirt cell several `fillRect` + `isTun`/`cell`. Last RTL draw is a **1×1** `fillRect` (sprite `drawPix` / HUD). Compiler already lowers `palK`'s `ch==="1"`…`"e"` chain to `lut[ch]|0` and inlines tiny callees (`functional_model/compiler.py`). That is compile-on-RUN — restart the GUI to pick it up. It does **not** make 624 dirt tiles cheap; PYTHON still ~1 fps after a 52164-byte ProgramImage. FPGA-SIM `fclk≈9M` is the same paint, not `S_DONE`.

## FPGA-SIM RTL = `.bin` RTL

Same `rtl/*.sv` as the chip. Do not debug PACMAN/MRDO with Verilator-only heaps, combo muxes, sim-sized depths, JS heap in ASET, or `unique case` on the opcode/`nat_id` switches (that last one hung Vivado at ~100 GB). Caps and the full list: `docs/AGENT_PASTE.md` § FPGA-SIM must stay `.bin`-legal, `docs/FPGA_FIT.md`. **No `.bin` until F9** — still write synthesizable RTL now.

## Vivado (separate from glass)

`jmr_js_vm.sv`: the giant opcode `case (code_rdata[7:0])` and native `case (nat_id)` / `case (nid)` are **plain `case`** now. `unique case` on those two made Vivado build every arm in parallel (~100 GB, no bitstream). Small `unique case`s (`state`, `trail_ph`, `spr_hdr`, `alu_op`) stay. **JS heap stays out of the 4 MB ASET SRAM.** `make -C sim sim_server_synth` rebuilt (unique→case + TOS `win[1]` refill). **No board `.bit`/`.bin`.**

## Caps (leftover T200 BRAM — do not grow)

`MAX_OBJ=1024` (fn bank independent). Arrays two-tier: `1536×32` short + `128×128` long (`MAX_ARR=1664`). `ENV_DEPTH=512`. Same numbers in PYTHON. Overflow loud. Dual FB ~0.6 MB; leftover ~1 MB is code+heap. Asset SRAM 4 MB is ASET art only.

## FPGA-SIM lockstep (waiting F9 — not this table as F9)

`make -C sim sim_server_synth` rebuilt this session. Same ProgramImage stream as PYTHON. No host twin.

| Title | Status |
|---|---|
| INVADERS | last headless held-left FB change passed; user has not F9-approved |
| PACMAN | last F9 bounced — `fault=2` `@1718` `vcsp=128`; BIND/forEach WIN_FILL reverted; **user F9 again** |
| DONKEY | last recorded F9 notes were older faults; re-check after PACMAN F9 |
| MRDO | live, slow splash (`fclk≈9M`); not READY-bounce |

Restart the GUI after compiler or sim-binary changes.

## Next (when you pick the bugs back up)

1. User F9 FPGA-SIM `(RTL)` PACMAN after GUI restart (`LOAD "PACMAN.HTML"` / `RUN`). Newest bounce was **fault 2 / vcsp=128** at `new Stage`, not 241. **No `.bin` until F9.**
2. MRDO: do not rewrite the HTML. Speed is VM `fillRect`/CALL_METHOD cost of the dirt field; palK LUT is already in. Keydown+keyup in one slow FRAME can miss `startHeld && !startWas`.
3. DONKEY recheck after PACMAN 241 is gone on glass.
