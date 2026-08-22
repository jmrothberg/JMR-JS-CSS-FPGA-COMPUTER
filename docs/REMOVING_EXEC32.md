# Removing exec32 — Cut A done; source cleanup DONE 2026-08-22

Words: [README.md — Words used](../README.md#words-used-in-this-project).

**exec32** was the old **tagged Q16** opcode decoder (JavaScript numbers
stored as 32-bit tagged integers). **exec64** is the only decoder now
(**Value64** / NaN-box). “We removed exec32” used to be only half true —
read this before deleting anything named `e32_*`.

## Read this first

**Cut A (done 2026-08-21):** the tagged decoder **module** is gone.
`jmr_js_vm_exec32.sv` deleted; `u_exec32` uninstantiated; `hs32` tied 0;
non-Value64 images fault **code 9**. No title runs that path.

**Phase 3b via the `v64_on` fold (attempted 2026-08-21) — IT DID NOT
WORK.** `jsb_flags[3]` is constant 1 after header decode, and the theory
was that Vivado would prove the tagged arrays unreachable and sweep them
without a hand delete. The 2026-08-22 05:10 census on that netlist proved
otherwise: **`gc_queue` alone survived as 229,362 flip-flop bits**, with
consts / vars / tenv_parent / obj_cls / tfn_* / env_oid adding ~101k more
— roughly 330k tagged FF bits at ~9 LUTs each, i.e. essentially the
entire 1M-LUT overage. Vivado could not prove the tagged states dead
because shared tasks (`stack_wr`, `gc_mark_value`) and runtime per-op
flags (`imgd_v64`, kev variants) keep formal entry paths alive.

**Do not trust a constant fold to remove a large array.** Cost of this
lesson: one ~5h synthesis run. Detail: [FPGA_FIT.md](FPGA_FIT.md).

**Phase 3b source cleanup — DONE 2026-08-22 (~05:05), by hand.** All 64
tagged write sites were deleted and the tagged stack task neutered, so
every array below is now **writerless** and synthesis can actually sweep
it. Verified in the source: `gc_queue` / `consts` / `vars` / `var_tag` /
`tenv_parent` / `obj_cls` / `obj_n` / `env_oid` have **zero** write sites;
`stack` / `stack_tag` keep their Port-A write processes but both enable
terms are constant 0 (`stack_we` is only ever assigned `1'b0`;
`e32_stack_we` has no driver at all now that exec32 is uninstantiated).
Verified in behavior: 198/198 bytecode suite, PACMAN plays, all five bug
reproductions green, RTL suite with no new failures.

**Do not Port-A the dead twin.** The dead targets, for reference (live
twins stay):

| Dead target (never used by V1 titles) | Size | Live twin (keep) |
|---|---:|---|
| `gc_queue` | 16384×14 = **224 Kb** | `vgc_queue` |
| `stack` / `stack_tag` | 2048×32 + 2048×3 | `vstack` |
| `vars` / `var_tag` / `var_init` | 512 each | `vvars` |
| `obj_n` / `obj_cls` / `tfn_*` / `tenv_parent` / `arr_len` / `env_oid` / `env_free` | 1024–1536 each | `vobj_*` / `vfn_*` / `varr_*` / `venv_*` |

The arrays are still *declared*. That is deliberate and harmless — a
writerless array is swept by synthesis; deleting the declarations is
cosmetic and risks the `e32_*` naming trap for no fit gain. The LUT
result of this delete lands with the next ~5h synth. The old 400-line
execution plan is in git history (`git log -- docs/REMOVING_EXEC32.md`);
do not resurrect it as a to-do.

## What landed — Cut A (Phases 1–3): complete

| Phase | What was done |
|---|---|
| 1 — every image is Value64 | `encode_chunk` / `ProgramImage.from_chunk` default `value64=True` and **raise** on `value64=False`. Hardware model refuses a non-`FLAG_VALUE64` image. |
| 2 — silicon refuses tagged | `S_GOT_HDR2` faults **code 9** when `flags[3]==0`; `hs32` tied `1'b0`. |
| 3 — unhook decoder | `u_exec32` removed; `jmr_js_vm_exec32.sv` **deleted** (user waiver 2026-08-21 — git history keeps it); dropped from `sim/Makefile` and `tools/board_flow/vivado_build.tcl`. |

**Measured effects of Cut A:** Verilator eval **+16%** (netlist shrink
alone), no title regression. **Did not** by itself remove tagged
memories — that is why the 04:11 place run still saw ~430 Kb of dead
LUTRAM until the `v64_on` fold.

**What Cut A exposed and forced us to fix** — Value64 gaps the tagged
decoder had been masking; all now in exec64 (detail in
[potential bugs.md](potential%20bugs.md)): `dispatchEvent` +
`KeyboardEvent`, `findIndex`, `ctx.font`, natural-size `drawImage`,
`join` digits, dynstr `indexOf`, `String.replace` char, KEYBITS edges,
halt-state parent/exec sync.

## The `e32_` naming trap (still true, still load-bearing)

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
renamed (`p_*`) in the optional source sweep so the trap stops existing.

## Cut B — console `.JS` / `.JSB` / `.JSH` sidecar tidy (still deferred)

**Future plan, optional.** `RUN` should accept only `src_is_html`
(PROG stream); the FAT `.JS` + `.JSB` path and `jsb_want_jsh` could go.
Buys nothing in the VM, adds console risk, and is **not** where the fit
problem is. Snippet tests still `LOAD "FOO.JS"` with a Value64 `.JSB`
companion — that transport works and is not worth churning. **Not** the
same as the dead tagged twin above.

## What must not happen

Do not merge engines, do not give exec64 a tagged stack, do not extract
JOIN/JSON/GC/HEAP into modules, do not re-add a second decoder for a
library title. One heap, one decoder, keep gen-match. Do not delete
`e32_*` names by prefix. Do not claim the tagged twin is “still the place
blocker” after the `v64_on` fold without reading a **clean**
`bit-fresh` report.
