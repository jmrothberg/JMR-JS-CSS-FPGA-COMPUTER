# Removing exec32 — DONE (2026-08-21)

The tagged Q16 opcode unit is **gone**. This file is now the completion
record plus the one piece of work that is still outstanding (Phase 3b).
The 400-line execution plan it used to hold is in git history
(`git log -- docs/REMOVING_EXEC32.md`); do not resurrect it as a to-do.

## What landed

**Cut A — remove exec32 (Phases 1–3): complete.**

| Phase | What was done |
|---|---|
| 1 — every image is Value64 | `encode_chunk` / `ProgramImage.from_chunk` default `value64=True` and **raise** on `value64=False` (one test asserts the raise). `_patch_js` / `_patch_js_spr` mint Value64. `hardware_model` refuses a non-`FLAG_VALUE64` image. `tools/compile_js.py compile_one` refuses `.JS` sidecar builds. `vectors/invaders_jsb.hex` (the `$readmemh` boot default) is a 71-byte Value64 stub, not a tagged INVADERS image. |
| 2 — silicon refuses tagged | `S_GOT_HDR2` faults **code 9** when `flags[3]==0`; `hs32` tied `1'b0`. |
| 3 — unhook | `u_exec32` instantiation removed; `jmr_js_vm_exec32.sv` **deleted** (user waiver 2026-08-21 — git history keeps it); dropped from `sim/Makefile` and `tools/board_flow/vivado_build.tcl`. Builds clean: the 302 exec32-driven `e32_*_q` wires are undriven and read 0, which is exactly the safe fall-through the raddr muxes were written to expect. |

**Measured effects:** Verilator eval **+16%** (netlist shrink alone), no
title regression (all five smoke green), probe ladder 8/8.

**What the cut exposed and forced us to fix** — every one of these was a
Value64 gap masked by the tagged decoder's coverage, and all are now
implemented in exec64 (detail in [potential bugs.md](potential%20bugs.md)):
`dispatchEvent` + the `new KeyboardEvent` family, `findIndex`, `ctx.font`
size parsing, natural-size `drawImage` under `setTransform`, `join` over
string digits, `indexOf` on a dynstr receiver, `String.replace`'s
replacement char, KEYBITS (physical joystick) edges, and the halt-state
parent/exec sync that the checkpoint parity tests measure.

## Still outstanding — Phase 3b (the remaining memory win)

Not required for synthesis; **do it after the first successful `make bit`**,
as its own pass with its own FPGA-SIM run.

Now that `jsb_flags[3]` is guaranteed, `hp_v64` is constant 1. That makes
**13 `!hp_v64` arms** dead, and only then does the tagged 32-bit state
become removable:

| Target | Size | Note |
|---|---:|---|
| `gc_queue` | 16384×14 = **224 Kb** | the single biggest would-be LUTRAM item in the design |
| `stack` / `stack_tag` | 2048×32 + 2048×3 | tagged eval stack |
| `vars` / `var_tag` / `var_init` | 512 each | tagged globals |
| `obj_n` / `obj_cls` / `tfn_*` / `tenv_parent` / `arr_len` / `env_oid` / `env_free` | 1024–1536 each | tagged heap twins |

≈ **430 Kb** of memory that simply vanishes — which is why
[FPGA_FIT.md](FPGA_FIT.md) says do **not** spend Port A effort on them.

Order: strip the dead tagged arms (`S_WAIT_FRAME`'s tagged `else` fork and
the tagged KEYEVT fork are the last readers of `e32_raf_fn_rdata` /
`e32_raf_tap1..7`) → build → dead-signal sweep → build → remove the tagged
arrays. Three commits, three builds.

### The `e32_` naming trap (still true, still load-bearing)

**The prefix lies.** Of the ~376 `e32_*` names, **74 are parent-owned** —
the parent's shared Port-A read-result and poke buses, merely named `e32_`.
They are read by parent tasks and by **Value64** states. Deleting them
breaks exec64. Run the discriminator, do not eyeball:

```bash
# KEEP: appears on the LHS of an assignment -> parent-driven silicon
grep -oE '^[^=<]*\be32_[A-Za-z0-9_]+ *(<=|=[^=])' rtl/engines/jmr_js_vm.sv \
  | grep -o 'e32_[A-Za-z0-9_]*' | sort -u
```

Everything that prints is parent silicon (`e32_stack_raddr`,
`e32_stack_tag_rdata`, `e32_tfn_*_rdata`, `e32_cs1_*_rdata`,
`e32_intern_var_rdata`, `e32_name_len_tos`, …). Those names should be
renamed (`p_*`) during 3b so the trap stops existing — a cosmetic pass that
finally makes the prefix honest.

## Cut B — console `.JS` / `.JSB` / `.JSH` sidecar tidy (still deferred)

Unchanged and still optional. `RUN` should accept only `src_is_html`
(PROG stream); the FAT `.JS` + `.JSB` path and `jsb_want_jsh` could go.
Buys nothing in the VM, adds console risk, and is **not** where the fit
problem is. Snippet tests still `LOAD "FOO.JS"` with a Value64 `.JSB`
companion — that transport works and is not worth churning.

## What must not happen

Do not merge engines, do not give exec64 a tagged stack, do not extract
JOIN/JSON/GC/HEAP into modules, do not re-add a second decoder for a
library title. One heap, one decoder, keep gen-match.
