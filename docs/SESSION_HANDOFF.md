# Session handoff

**2026-08-17.** This file is **current truth only**.

Product plan (steps, not glass): [`working_html_fpga-sim`](/home/jonathan/.cursor/plans/working_html_fpga-sim_a719ac28.plan.md). Read that file and follow it. PYTHON glass for INVADERS / PACMAN / DONKEY is **user-confirmed**. Do not mark FPGA-SIM F9 green. **No `.bin` until F9.** INVADERS starts on **Space**.

## User last saw

| Runtime | Title | Glass |
|---|---|---|
| PYTHON | INVADERS / PACMAN / DONKEY | play |
| PYTHON | MRDO | loads/plays at **~1 fps** |
| FPGA-SIM | PACMAN | splash then skip-stages (YOU WIN). Fix is in RTL; **restart GUI** and F9. Do not treat pytest as F9. |

## Why PACMAN bounced (not a VM crash)

`fault=0` the whole time. Splash → maze (`vdraw=385,419,4,4,25`, `fclk≈5M`) → overlay (`vdraw=0,0,640,480,0`, `fclk≈715k`) after ~12 maze frames. That is `nextStage()` every rAF, then YOU WIN.

PACMAN `stage.update` does `JSON.stringify(beans.data).indexOf(0)` (JS ToString(0) is `"0"`, character search). INVADERS / MRDO / ASTEROID never do that. No title gate. Do not rewrite `storage/PACMAN.HTML`. Do not no-op 241.

Root cause (Value64 dynstr `indexOf`): HP_OGETI overwrites `hp_key` with the slot name, then the scan used `hp_key[7:0]` as the needle (NUL) → always −1 → `indexOf(0)<0` every frame. Tagged CPU already kept the needle in `idx_needle`. Illegal `for (k=0;k<JSON_CAP)` in `always_ff` was the same class as the opcode hang.

FPGA-legal fix (same RTL as `.bin`): latch needle in `hp_wval` (OGETI does not touch it), walk `json_mem` one byte/clock in existing `S_IDXSTR` (`hp_v64` writes IEEE index). `test_rtl_value64_stringify_indexof_zero_keeps_beans` passes. Not F9.

Traces: FRAME VMSTAT is no longer dumped on every capped overlay. Log first3, `fcap=1`, and a **vdraw change** (maze→win). Iterate with the IDX0 snippet, not a full PACMAN F9.

## Vivado split — still in; needle fix after any in-flight `make bit`

`jmr_js_vm.sv` no longer holds the three giant opcode/native switches in one `always_ff`. Same clk, same boot (`jsb_flags[3]` → `S_V64_EXEC` else `S_EXEC`), same heap caps, no `ifdef SYNTHESIS`, no ASET heap, no title gates.

A `make bit` started this session may have snapshotted RTL **before** the dynstr `indexOf` needle fix. Do not flash that `.bit` as a PACMAN skip-stages proof. Re-run `make bit` only when you ask, after F9.

## Caps (leftover T200 BRAM — do not grow)

`MAX_OBJ=1024`. Arrays two-tier: `1536×32` short + `128×128` long (`MAX_ARR=1664`). `ENV_DEPTH=512`. Same numbers in PYTHON. Overflow loud. Dual FB ~0.6 MB; leftover ~1 MB is code+heap. Asset SRAM 4 MB is ASET art only.

## FPGA-SIM lockstep (waiting F9 — not this table as F9)

Restart the GUI after this sim-binary change.

| Title | Status |
|---|---|
| INVADERS | last headless held-left FB change passed; user has not F9-approved |
| PACMAN | skip-stages RTL fix in; **user F9 again** after GUI restart |
| DONKEY | re-check after PACMAN F9 |
| MRDO | live, slow splash; not READY-bounce |

## Next

1. Restart GUI, F9 FPGA-SIM PACMAN (LOAD + RUN, Enter off splash). Expect maze to hold, not YOU WIN in ~12 frames.
2. You run `make bit` when you want this RTL (exec split + sequential dynstr indexOf) on the board. Do not start it from here.
3. MRDO speed is `fillRect`/CALL_METHOD cost; do not rewrite the HTML.
