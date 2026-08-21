# Removing exec32 — Cut A DONE; Phase 3b NOT done

## Read this first — “we removed exec32” is only half true

**Cut A (done 2026-08-21):** the tagged Q16 **decoder module** is gone.
`jmr_js_vm_exec32.sv` deleted; `u_exec32` uninstantiated; `hs32` tied 0;
non-Value64 images fault **code 9**. No title runs that path.

**Phase 3b (not done):** the parent `jmr_js_vm.sv` still holds the
**entire tagged twin** — `gc_queue`, tagged `stack`/`stack_tag`,
`vars`/`tfn_*`/`arr_len`/… — plus dead `!hp_v64` FSM arms. Vivado
**still synthesizes** that RAM. The 2026-08-21 place failure’s
Distributed RAM report still showed `gc_queue` alone as
**RAM64M ×1280** (~224 Kb) next to live `vgc_queue`.

So: decoder removed ≠ tagged machine removed. Fit agents must finish
3b; do not Port-A the dead twin. Detail + Headline:
[FPGA_FIT.md](FPGA_FIT.md) § Dead tagged twin.

The old 400-line execution plan is in git history
(`git log -- docs/REMOVING_EXEC32.md`); do not resurrect it as a to-do.

---

## What landed — Cut A (Phases 1–3): complete

| Phase | What was done |
|---|---|
| 1 — every image is Value64 | `encode_chunk` / `ProgramImage.from_chunk` default `value64=True` and **raise** on `value64=False` (one test asserts the raise). `_patch_js` / `_patch_js_spr` mint Value64. `hardware_model` refuses a non-`FLAG_VALUE64` image. `tools/compile_js.py compile_one` refuses `.JS` sidecar builds. `vectors/invaders_jsb.hex` (the `$readmemh` boot default) is a 71-byte Value64 stub, not a tagged INVADERS image. |
| 2 — silicon refuses tagged | `S_GOT_HDR2` faults **code 9** when `flags[3]==0`; `hs32` tied `1'b0`. |
| 3 — unhook decoder | `u_exec32` instantiation removed; `jmr_js_vm_exec32.sv` **deleted** (user waiver 2026-08-21 — git history keeps it); dropped from `sim/Makefile` and `tools/board_flow/vivado_build.tcl`. The 302 exec32-driven `e32_*_q` wires are undriven and read 0 (safe fall-through for raddr muxes) — **still present until 3b sweeps them**. |

**Measured effects of Cut A:** Verilator eval **+16%** (netlist shrink
alone), no title regression (all five smoke green), probe ladder 8/8.
**Did not** remove the tagged twin memories — that is why place still
saw ~430 Kb of dead LUTRAM.

**What Cut A exposed and forced us to fix** — Value64 gaps the tagged
decoder had been masking; all now in exec64 (detail in
[potential bugs.md](potential%20bugs.md)): `dispatchEvent` +
`KeyboardEvent`, `findIndex`, `ctx.font`, natural-size `drawImage`,
`join` digits, dynstr `indexOf`, `String.replace` char, KEYBITS edges,
halt-state parent/exec sync.

---

## Still outstanding — Phase 3b (finish the cut; do now for fit)

Was deferred “after first successful `make bit`.” That run **synth’d
but failed place** on over-util — see [FPGA_FIT.md](FPGA_FIT.md). Phase
3b is now **suggested step 1** of the fit repair: delete unreachable
legacy, then worry about live BRAM.

Now that `jsb_flags[3]` is guaranteed, `hp_v64` is constant 1. That makes
**13 `!hp_v64` arms** dead, and only then does the tagged 32-bit state
become removable:

| Dead target (never used by V1 titles) | Size | Live twin (keep) |
|---|---:|---|
| `gc_queue` | 16384×14 = **224 Kb** | `vgc_queue` |
| `stack` / `stack_tag` | 2048×32 + 2048×3 | `vstack` |
| `vars` / `var_tag` / `var_init` | 512 each | `vvars` |
| `obj_n` / `obj_cls` / `tfn_*` / `tenv_parent` / `arr_len` / `env_oid` / `env_free` | 1024–1536 each | `vobj_*` / `vfn_*` / `varr_*` / `venv_*` |

≈ **430 Kb** of memory that should simply vanish — do **not** Port-A it.

Order: strip the dead tagged arms (`S_WAIT_FRAME`'s tagged `else` fork and
the tagged KEYEVT fork are the last readers of `e32_raf_fn_rdata` /
`e32_raf_tap1..7`) → build → dead-signal sweep → build → remove the tagged
arrays. Three commits, three builds. Then FPGA-SIM smoke the five titles.

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
companion — that transport works and is not worth churning. **Not** the
same as the dead tagged twin above.

## What must not happen

Do not merge engines, do not give exec64 a tagged stack, do not extract
JOIN/JSON/GC/HEAP into modules, do not re-add a second decoder for a
library title. One heap, one decoder, keep gen-match. Do not claim
“exec32 removed” again until Phase 3b has deleted the tagged arrays.
