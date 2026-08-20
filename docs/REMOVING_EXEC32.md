# Removing exec32

Plan for deleting the tagged Q16 opcode unit. **Do not start this in
parallel with a glass/FIND/FOREACH/`WAIT_FRAME` agent** — both touch
`rtl/engines/jmr_js_vm.sv`. One dedicated agent. Tests first, then
fail-loud, then unhook. Do not `make bit` unless the user asks.

Product is **HTML only** (`LOAD "NAME.HTML"` → compile-on-RUN). There is
no `.JS` title path. F9 already never enables exec32. This cut removes
the leftover decoder.

**Scope note (read before Phase 1).** This document used to bundle two
independent cuts. They are now separated:

- **Cut A — remove exec32.** Every image is Value64; `u_exec32` is
  unhooked. This is the synth and debug win. **Phases 1–3 below.**
- **Cut B — remove the console `.JS` / `.JSB` / `.JSH` sidecar path.**
  Console FSM tidy. Buys nothing in the VM, adds console risk.
  **Deferred — see [Cut B](#cut-b--deferred-console-sidecar-tidy).**

Cut A does **not** require Cut B. `_patch_js_v64` already proves the
console FAT `.JS` + `.JSB` path runs **Value64 on exec64** today
(`tests/test_rtl_snippets.py:36`, `LOAD "VFIND.JS"` → `hs64`). The
console does not care what encoding the blob carries; only
`jsb_flags[3]` picks the decoder.

---

## Verified facts (measured, 2026-08-19)

Do not re-derive these; do re-check them if the file has moved on.

| Fact | Value | Where |
|---|---|---|
| exec32 module | **5,170 lines** | `rtl/engines/jmr_js_vm_exec32.sv` |
| exec64 module | 6,850 lines | `rtl/engines/jmr_js_vm_exec64.sv` |
| Parent | 13,900 lines | `rtl/engines/jmr_js_vm.sv` |
| `u_exec32` instantiation | **lines 2913–3971** (1,059-line port list) | parent |
| `u_exec64` instantiation | line 3972 | parent |
| `e32_*` references in parent | **1,120** | parent |
| Distinct `e32_*` signals | **379** | parent |
| `hs32` references | **33** | parent, from 4759 |
| `S_EXEC` / `S_NAT` references | 13 / 10 | parent |
| `_patch_js` call sites | 72 | `tests/test_rtl_snippets.py` |
| `_patch_js_v64` / `_patch_js_spr` sites | 35 | same |

**exec32 is really synthesized.** The enable is `!jsb_flags[3]` and
`jsb_flags` is a runtime register, so Vivado cannot constant-fold the
module away. Synth has never reached 100% (`docs/FPGA_FIT.md`), so this
is a real fit and runtime win, not cosmetic.

**What it does not remove.** The parent's tagged 32-bit `stack[]` /
`stack_tag[]` and the tagged object/env/callstack arrays are
**parent-owned and shared with Value64 paths**. They do not die with the
module. See [Phase 3b](#phase-3b--the-follow-up-sweep-where-the-memory-win-is).

---

## What it is

The parent VM (`jmr_js_vm.sv`) owns **one** JS heap (objects, arrays,
names, canvas). It instantiates **two** opcode decoders:

| | **exec32** (`jmr_js_vm_exec32.sv`) | **exec64** (`jmr_js_vm_exec64.sv`) |
|---|---|---|
| **ISA** | Tagged Q16. Eval stack is 32-bit words: small type tag + Q16 fixed-point / payload. | **Value64.** Eval stack is 64-bit IEEE-754 / boxed values (`FLAG_VALUE64` = `jsb_flags[3]`). |
| **When enabled** | `!jsb_flags[3]` and parent `S_EXEC` / `S_NAT`. | `jsb_flags[3]` and parent `S_V64_EXEC` (plus `S_V64_*` overlay states). |
| **Who emits it** | `encode_chunk(..., value64=False)` — the **default**. | `encode_html_chunk` (always `value64=True`). Product `LOAD`/`RUN` of `.HTML`. |
| **Product titles** | Never. | Always. |

`FLAG_VALUE64` is bit 3 of the ProgramImage flags word
(`functional_model/jsb_format.py`). HTML compile-on-RUN always sets it
(`tools/compile_js.py` `encode_html_chunk`). The parent mux:

```
hs64 =  jsb_flags[3] && (S_V64_EXEC | HEAP | WAIT_FRAME | …)   // 4733
hs32 = !jsb_flags[3] && (S_EXEC | S_NAT | HEAP …)              // 4759
```

exec32 is the **previous** number/stack encoding, kept so a FLAG_VALUE64
image cannot alias the old stack. It is not a second heap. It is not
the F10 monitor. It is not the READY console.

**exec32-only bugs** (potential-bugs **10**, tagged `time_ms` on **13**)
exist because reviews were told to inspect both files. Titles do not
need those fixes. They die with this path. Do not match exec32 to
exec64 as a glass task.

---

## Does exec64 just plug in?

**For titles: it is already plugged in.** F9 HTML never takes `hs32`.
You do not swap modules like a chip. You stop instantiating the idle
one.

**For leftover tests: re-encode, then exec64 runs.** Same bytecode
opcodes, different **const pool and stack width**. After
`encode_chunk(..., v2=True, value64=True)` the image sets `jsb_flags[3]`,
the parent enters `S_V64_EXEC`, and **exec64** decodes. That is the
plug-in. It is **not** "rename exec32 to exec64" and it is **not**
wiring exec64's ports into the `S_EXEC` enable.

Caveats:

1. `_patch_js` still emits a **tagged** `.JSB`. Console FAT-loads that
   blob → `hs32` → exec32. **Fix the encoding, not the transport**
   (Phase 1). The `.JS` filename and the FAT companion are fine — they
   already carry Value64 blobs for 35 tests.
2. Parent still has a **tagged** `S_WAIT_FRAME` / KEYEVT arm behind
   `!jsb_flags[3]` (`S_WAIT_FRAME` at 8403; the tagged fork is the
   `else` at ~8595). After the flag is required, those arms are dead
   and can be stripped — but strip them **after** the module is
   unhooked, not before.
3. PYTHON `JsHwVm` still has `_load_legacy_decoded_image` for images
   without the flag. Flip loaders first; then refuse the legacy load.
4. Value64 is IEEE, tagged is Q16. **Snippet assertions that encode Q16
   results will need updating.** This is the actual work in Phase 1.

**Do not** merge exec32 into exec64. **Do not** give exec64 the
tagged stack. **Do not** extract HEAP/JOIN/JSON. The parent heap
stays. Only the unused decoder goes.

---

## Sequencing — this job waits for FIND

`docs/SYNTH_SLOWDOWN_LEDGER.md` declares the `S_JOIN_FIND` cache
mandatory before any other glass/RTL work, and it lives in
`jmr_js_vm.sv` — the same file Phase 3 rewrites in 1,120 places.

- **Phase 1 is safe to do now.** Python and tests only. No RTL.
- **Phases 2–3 wait for FIND to land** and for FPGA-SIM to be green.

Never run Phase 3 concurrently with a `jmr_js_vm.sv` glass agent.

---

## Order (do not skip)

### Phase 0 — do not touch yet

- No parallel agent on `jmr_js_vm.sv` glass.
- Do not delete `jmr_js_vm_exec32.sv` until the user waives
  "never delete files." Unhook is enough for FPGA-SIM/Vivado to
  stop compiling it.
- Do not "fix" potential-bugs **10**.

### Phase 1 — every image is Value64

Goal: nothing in-tree can produce `jsb_flags[3]==0` except an
explicit **reject** test.

**Do not rewrite the 72 snippets into HTML wrappers.** That was the old
plan and it is wrong for three reasons: it edits 72 call sites for no
functional gain; it silently changes *what the tests test* (raw JS
snippet vs HTML compiler + canvas wrap), so a later failure is ambiguous
between an exec64 bug and a wrap artifact; and it drags Cut B forward.
Change **one variable**: the encoding.

| Consumer | What it does today | Exact fix |
|---|---|---|
| `tests/test_rtl_snippets.py` `_patch_js` (72 sites) | `encode_chunk(compile_source(src))` → **tagged** `.JSB`, then `LOAD "FOO.JS"` / `RUN`. | **One line.** `encode_chunk(compile_source(src), v2=True, value64=True)` — i.e. make `_patch_js` identical to `_patch_js_v64`. **Zero call-site edits.** Then fix whatever snippets fail (below). |
| `_patch_js_v64` | Already Value64. | Once `_patch_js` matches, keep it as an alias or collapse the two. Do not churn the 35 call sites. |
| `_patch_js_spr` (~12 drawImage snippets) | Same FAT `.JS` + tagged `.JSB` plus sprite/ASET pack. | Same one-line encoding flip. The sprite/ASET pack is orthogonal — do **not** re-route it through `encode_html_chunk`. |
| Same file `test_program_image_scalar_checkpoint_matches_python_hm` | `ProgramImage.from_chunk(..., v2=True)` **no** `value64`. | Point at `value64=True` **or** delete: `test_program_image_value64_scalar_checkpoint_matches_python_hm` already covers the product encoding. |
| `functional_model/jsb_format.py` `encode_chunk` / `from_chunk` | `value64: bool = False`. | Default **`True`**. `value64=False` should `raise ValueError` (loud), except the one unit test that asserts the raise. Docstring: HTML/Value64 is the only encoding. |
| `tools/compile_js.py` `compile_one` | `encode_chunk(chunk)` writes `NAME.JSB` and can refresh `vectors/invaders_jsb.hex`. | **Refuse.** HTML only (`encode_html_chunk`). Do not write a tagged `invaders_jsb.hex`. |
| `tools/compile_js.py` `encode_html_chunk` | Already `value64=True`. | **Leave it.** |
| `hardware_model/js_vm.py` `_load_legacy_decoded_image` | PYTHON executes tagged images. | If `not (flags & FLAG_VALUE64)`: raise / set a loud error. Delete or dead-code the legacy loader **after** tests pass with Value64 only. |
| `tests/test_bytecode_js.py` `from_chunk(..., v2=True)` without `value64` | Format/decode tests. PYTHON, not exec32 silicon, but they still mint tagged blobs. | Add `value64=True` to every `from_chunk` / `encode_chunk` meant to **run**. Keep **one** test that a missing flag is rejected. |
| `rtl/jmr_js_core.sv` `CODE_HEX("invaders_jsb.hex")` | `$readmemh` default if the VM starts with no PROG stream. | Tiny Value64 stub that traps, or empty. Never a tagged INVADERS image. Never silent-run a title. |

**The real work is the Q16 → IEEE fallout.** The plumbing is one line;
expect a handful of the 72 snippets to fail because the assertion
encodes a Q16 result, an integer-division truncation, or a
fixed-point rounding artifact. Fix the **assertion** when Value64 is
correct. If a snippet fails because exec64 is genuinely wrong, that is
a **found bug** — file it in `docs/potential bugs.md` and fix it; it is
not a regression from this cut and it is not a reason to keep exec32.

Phase 1 done when: `encode_chunk(..., value64=False)` raises; no
in-tree helper mints a tagged blob; the full `tests/test_rtl_snippets.py`
and `tests/test_bytecode_js.py` pass with Value64 only.

**Prove it:** full snippet suite green plus
`test_program_image_value64_scalar`. Rebuild FPGA-SIM only after Phase 3.

### Phase 2 — silicon refuses tagged

| Place | Exact fix |
|---|---|
| Parent, image header decode / RUN start (`jmr_js_vm.sv`) | If `jsb_flags[3]==0`: loud fault (existing machine_fault path), **never** `hs32`, never `S_EXEC`. Same idea in PYTHON `JsHwVm.load_*`. |
| `hs32` comb (4759) | Can stay `1'b0` wired, then delete. |
| `sim/sim_main.cpp` | Trace `sp`/`raf` still branches on `jsb_flags & 8`. After refuse, only the Value64 arm is live — print that arm only. |

Phase 2 done when: a deliberately tagged blob in FPGA-SIM faults
loud and does **not** enter `S_EXEC`. Titles unchanged. Run the full
suite here — with `hs32` forced low, exec32 is already functionally
gone, so **this is where a silent dependency shows up**, while the
module is still wired and easy to put back.

### Phase 3 — unhook the module

> **Read [The `e32_` naming trap](#the-e32_-naming-trap) before touching
> a single line.** A `grep e32_ | delete` pass **will** break the parent.

| Place | Exact fix |
|---|---|
| `rtl/engines/jmr_js_vm.sv` | Remove `jmr_js_vm_exec32 u_exec32 (...)` (2913–3971). Remove **only** the 305 exec32-driven signals. Collapse `hs32 ? (hs_m_x ? x_ff : e32_x_q) : x_ff` muxes to `x_ff`. `casestate` overlay: drop `e32_leave_hold` / `S_EXEC`/`S_NAT` exec32 hold. **Do not** delete `S_V64_*` or Port A tasks. |
| `sim/Makefile:99` | Drop `jmr_js_vm_exec32.sv` from the Verilator file list. |
| `tools/board_flow/vivado_build.tcl:91` | Drop the same file from `read_verilog`. |
| `rtl/engines/jmr_js_vm_exec32.sv` | Unhooked. **Do not delete the file** unless the user says so. |

Then `make -C sim sim_server_synth` (Verilator). Titles still
exec64. Snippets still Value64. Parent heap/glass untouched except
mux deletion.

**Legal SRAM:** do not put `mem[i] <=` back in the FSM while editing
the mux. `stack_wr` / `vobj_alloc_wr` / … stay.

**Strip the dead tagged arms in a separate commit, after the unhook
builds clean** — never in the same pass. `S_WAIT_FRAME` (8403) tagged
`else` fork at ~8595, and the tagged KEYEVT fork. Those arms are the
last readers of `e32_raf_fn_rdata` and `e32_raf_tap1..7`, so only after
they are gone can the dead-signal sweep see those as unread.

### Phase 3b — the follow-up sweep (where the memory win is)

Not required for the unhook to build; do it after Phase 3 is green.

Once `jsb_flags[3]` is guaranteed, `hp_v64` is constant 1 — the parent
task `hs_hp_v64(v)` (2241) is only ever called with 0 from exec32
paths. That makes **13 `!hp_v64` arms** dead, and only then does the
tagged 32-bit `stack[]` / `stack_tag[]` SRAM become removable
(`stack_rd_a` fan-in at 2512–2525, read process at 5099–5109, varr tag
write at 2381, `hp_qt_ff[0]` at 8745).

Do this as its own pass with its own FPGA-SIM run. It is the largest
BRAM/LUTRAM saving in the whole cut, and it is also the easiest place
to silently break a Value64 heap fill.

### Phase 4 — docs and rules

| Place | Exact fix |
|---|---|
| `.cursor/rules/never-fake-fpga-sim.mdc` | "Inspect **exec64** and the parent." Drop "both exec32 and exec64." |
| `.cursor/rules/one-heap-keep-gen.mdc` | Drop "titles on 64 still synthesize 32." |
| `.cursor/rules/python-first-parity.mdc` | Same inspect line. This cut **is** an ISA deletion the user requested; do not read "do not redesign" as a ban on **this** plan. Still do not merge engines or extract JOIN/JSON/GC. |
| `docs/SESSION_HANDOFF.md:79` | Inspect exec64 only. |
| `docs/FPGA_FIT.md` / `docs/ARCHITECTURE.md` (45, 55) | One decoder. Mux gone. |
| `docs/potential bugs.md` | Close **10** as **removed with exec32**. **13** `time_ms+=17` only if Value64 readers still need it (today Value64 uses `vframe_no`). |
| `functional_model/jsb_format.py` comments | Migration complete; missing flag is an error. |

---

## The `e32_` naming trap

**The prefix lies.** Of the 379 distinct `e32_*` signals, **74 are
parent-owned** — the parent's shared Port-A read-result bus and poke
bus, merely named `e32_`. They are read by parent tasks and by
**Value64 states**. Deleting them breaks exec64.

**Mechanical discriminator** (run it, do not eyeball it):

```bash
# KEEP: appears on the LHS of an assignment outside the port list -> parent-driven
awk 'NR<2913 || NR>3971' rtl/engines/jmr_js_vm.sv \
  | grep -oE '^[^=<]*\be32_[A-Za-z0-9_]+ *(<=|=[^=])' \
  | grep -o 'e32_[A-Za-z0-9_]*' | sort -u
```

Everything that list prints is **parent silicon**. Everything else
(305 signals, mostly `e32_*_q` and `e32_*_wdata`) is an exec32 output
and goes.

**Re-run the discriminator against the live file** — the line range
2913–3971 must be re-checked if the file moved.

### Proof it matters

| Signal | Looks like | Actually is |
|---|---|---|
| `e32_stack_raddr` (2512) | exec32 address | The **default** of the parent's `stack_rd_a` mux. Parent states override it. Delete the signal and the mux loses its fall-through. |
| `e32_stack_tag_rdata` (5108) | exec32 read | Driven by the **parent**, consumed by the parent at 2381 (varr tag write) and 8745 (`hp_qt_ff[0]`). |
| `e32_tfn_*_rdata` (5550–5615) | exec32 read | Parent read process. The address mux has explicit `S_V64_METH`, `S_FOREACH`, `S_KEYEV`, `S_WAIT_FRAME` terms, with `e32_tfn_raddr` only as the fall-through. |
| `e32_cs1_*_rdata` (5725–5734) | exec32 read | Consumed by parent task `cstk_win_load1()` (1963). |
| `e32_p_we/sel/addr/data` | exec32 output | **Parent→exec32** poke bus, driven by the parent task `e32_poke` (2229) from `S_TRAIL`. |
| `e32_raf_tap1..7` | exec32 output | Parent rAF queue taps. |

**The tagged heap arrays are shared, not exec32-private.**
`S_V64_METH` (13207) calls `enter_captured_fn(fip)` at 13230, and that
task reads `e32_obj_n_rdata` / `e32_tfn_parent_rdata` /
`e32_tfn_this_rdata` and writes `obj_cls[]`, `obj_n[]`, `tenv_parent[]`,
`vars[]`, `cstack_env[]`. A Value64 title depends on all of it. This is
why "it is not a second heap" is literally true and why the cut is
**decoder only**.

### The `*_raddr` rule

The 12 `e32_*_raddr` signals **are** exec32 outputs, but they sit as the
**last `else` of a parent read-address mux**, e.g.:

```systemverilog
e32_tfn_entry_rdata <= tfn_entry[
    (… S_FOREACH …)    ? e32_cs1_fe_fn_rdata[12:0] :
    (… S_KEYEV …)      ? kev_fn[12:0] :
    (… S_V64_METH …)   ? hp_rval[12:0] :
    (… S_WAIT_FRAME …) ? (…raf_fn[0]…) :
    e32_tfn_raddr];                       // <-- exec32's request
```

**Do not delete the mux.** Replace the `e32_*_raddr` fall-through with a
safe constant (`13'd0`) or with the last explicit parent term. Same for
`stack_rd_a = e32_stack_raddr;` at 2512. Getting this wrong reads the
wrong heap slot on a Value64 path and shows up as glass corruption, not
a compile error.

### Phase 3 pre-checks (verify, do not assume)

1. **`e32_poke` from `S_TRAIL`.** 6979 pokes `sel 17` (intern varmap) and
   6985 pokes `sel 20` (document/window seed) into exec32's private
   tables. `S_TRAIL` is the shared **v2 name/class trailer parser** and
   runs for Value64 images too. Confirm exec64 gets the equivalent seed
   — the parent also writes `intern_var[]` / `intern_var_ok[]` directly
   at 6977–6978 and exec64 reads those via `e32_intern_var_rdata`
   (KEEP set) — **before** deleting `e32_poke` and its callers.
2. **`e32_leave_hold`.** Confirm the `casestate` overlay hold has no
   Value64 caller before dropping it (`e64_leave_hold` at 13049 is the
   live one).
3. **Order of operations.** Unhook → build → strip tagged arms → build →
   dead-signal sweep. Three commits. A signal that looks dead after the
   unhook may still be read by a tagged arm you have not stripped yet.

---

## Cut B — deferred console sidecar tidy

**Not part of removing exec32.** Do this later, as its own job, with its
own FPGA-SIM run. Listed here so it is not lost.

| Place | What it does today | Eventual fix |
|---|---|---|
| Console FAT `.JS` + `.JSB` (`jmr_console_engine.sv`) | `src_is_js` (158) → `C_JSB_PREP` (1617) opens `NAME.JSB` from FAT. HTML already uses `C_JSB_TETHER` (PROG). | `RUN` only if `src_is_html` (PROG). Else `?NB`. Delete `src_is_js` classify (718) and the `src_is_js \|\| src_name_len` FAT arm (567). Keep `C_JSB_TETHER`/`FEED` — that is the ProgramImage pump, not a sidecar. RECTDEMO / empty NEW stay the rect engine. |
| `.JSH` names | Comments/RPC still say HTML RUN loads `.JSH`. Card never writes a sidecar. `jsb_want_jsh` (159) picks FAT suffix `H` vs `B`. | Comments: in-memory ProgramImage over PROG. `jsb_want_jsh` dies with the FAT suffix. Keep `JSHLOAD` RPC **or** alias `PROGLOAD` (same poke); do not invent a disk `.JSH`. DIR already hides `.JSH`/`.JSB` — also hide `.JS`. |
| Snippet tests | `LOAD "FOO.JS"` + Value64 `.JSB` companion. | **Only then** do the HTML-wrap rewrite, if it is still wanted. It is a test-transport change, not an ISA change. |

Cut B's prerequisite is Cut A Phase 1 (the blobs must already be
Value64). Its blocker is that it edits the console FSM, which is not
where the fit problem is.

---

## What we lose / do not lose

**Lose:** tagged ProgramImages. Q16 fixed-point semantics in 72 snippet
tests (they move to IEEE). Intentional.

**Do not lose:** HTML compile-on-RUN, exec64, parent heap, JOIN,
JSON, GC, canvas, ASET SRAM, PROG stream, F9 titles, opt-in
`JMR_SIM_HOST=1`, the console `.JS` FAT path (Cut B, deferred).

**Would brick if Phase 3 happens before Phase 1:** every FPGA-SIM test
that still mints a tagged `.JSB`.

---

## What is not leftover (do not delete)

| Keep | Why |
|---|---|
| Host twin `JMR_SIM_HOST=1` | Opt-in debug of the Python VM. Default FPGA-SIM is still Verilator. Not a second ISA. |
| JOIN / JSON / GC / exec64 / parent heap | The HTML machine. Not exec32. Do not extract or merge. |
| PROG stream (`C_JSB_TETHER`, `PROGBEGIN`/`PROGSTART`) | How HTML `RUN` loads the ProgramImage. The `C_JSB_*` names are the byte pump. |
| The 74 parent-driven `e32_*` signals | Parent silicon with a misleading prefix. See [the trap](#the-e32_-naming-trap). |
| Tagged `stack[]` / object / env / cstack arrays | Shared with Value64 states. Phase 3b at the earliest, never in Phase 3. |

`.JS` titles are not a product. `storage/savetest.js` may remain on disk
(do not delete files unless asked).

---

## Agent checklist

**Phase 1 (safe now, no RTL)**

1. `_patch_js` → `value64=True`. One line. No call-site edits. No HTML wrap.
2. `_patch_js_spr` → same one-line flip.
3. `encode_chunk` / `from_chunk` default `True`; `False` raises.
4. Fix Q16→IEEE assertion fallout. File genuine exec64 bugs; do not keep exec32 for them.
5. PYTHON refuse tagged load. `compile_one` refuses `.JS`. `CODE_HEX` stub is Value64 or empty.
6. Full `test_rtl_snippets.py` + `test_bytecode_js.py` green.

**Phases 2–3 (FPGA-SIM play is green — five titles run, slowly; do this next)**

7. Parent: missing flag → fault; `hs32` forced `1'b0`. Full suite again — silent dependencies surface here, while the module is still wired.
8. Run the KEEP/DELETE discriminator. Confirm the three pre-checks.
9. Unhook `u_exec32`; collapse `hs32` muxes; fix `*_raddr` fall-throughs; drop from `sim/Makefile` + `vivado_build.tcl`. Commit. `make -C sim sim_server_synth`.
10. Strip dead tagged `WAIT_FRAME` / KEYEVT arms. Separate commit. Build.
11. Dead-signal sweep. Separate commit. Build.
12. Phase 3b: `!hp_v64` arms + tagged stack SRAM. Its own pass, its own run.
13. Update rules/docs. Unhooked `jmr_js_vm_exec32.sv` stays until the user allows delete.

**2026-08-20 mapping OOM (2 threads, user saw it)** made this cut
**required before the next `make bit`**, not optional hygiene. Worker
cap is not enough. After exec32: Port A for the LUTRAM monsters (separate
agent). Full order:
[FPGA_FIT.md](FPGA_FIT.md#cleanup-before-the-next-make-bit-2026-08-20-oom).
Do not fold Port A into Phases 1–3.
