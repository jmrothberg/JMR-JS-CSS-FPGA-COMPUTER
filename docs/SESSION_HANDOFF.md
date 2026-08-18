# Session handoff

**2026-08-17 (headless, not an F9).** One file for the next agent. Do **one**
step from **Next**. Do not overnight-go. **Do not tell the user to F9 the
three games yet.**

Product: a **standalone HTML/JS-native computer** on Nexys Video **T200**.
Not a browser. Not dukpy. FPGA-SIM and the `.bin` are the same `rtl/*.sv`.

Law: `never-fake-fpga-sim`, `one-heap-keep-gen`, `python-first-parity`,
`no-dukpy-cheat-native-cpu`. ABI: [`docs/JMR_JS_COMPATIBILITY.md`](JMR_JS_COMPATIBILITY.md).

## Now

PYTHON F9 glass for INVADERS / PACMAN / DONKEY is **user-confirmed**. FPGA-SIM
titles are **not** F9-ready. This is **not** a dead end: the flatten-era
MAKE_FN push is back for IIFE. **No `make bit`.** No host twin.

Caps stay 1024 / `1536×32+128×128` / 512. Synth rules:
`never-fake-fpga-sim` (do not put combo `stack[]` / `name_blen[i]` back).

**Flatten leftover (inspect 2026-08-17, after other-agent seal):** opcode
`always_comb` no longer drives SRAM we/raddr. Combo `intern_var` / `cstack_*` /
`env_oid` / `fn_proto_ip` gone from exec. `sim_server_synth` PASS. **No
`make bit` yet.** Still not the hung class:

- exec32 still has local `char_id[0:255]` (parent also has `char_id`; decoder
  uses `char_id_rdata`)
- exec32 still has local `to_delay`/`to_fn`/`to_id`/`to_period` [0:63] plus
  unused `to_*_nev` decls (parent has `to_fn`; compact is FSM)
- exec64 raddr is a **second** opcode-keyed `always_comb` that still drives
  `varr_raddr` / `vobj_raddr` / … ports (`vst_s` TOS, not a 1024-mux)

Leave: `cls_*` 16×16, `vst_s`/`e32_sv`, `leave_hold` FF, `sti`/`stfx` unused.
Do not touch IIFE/`leave_hold` else. Glass Next 0 is still DONKEY `NEW_OBJ`.

## What worked (learn from this)

Flatten-era play used **exec-owned vsp** so MAKE_FN+CALL_VAL saw the Fn as TOS.
Parent ALLOC now plants `vst_win[0]` + `hs_vsp`. The extra EXEC beat with
`use_e64_win` used lagged `e64_vsp_q` and **shifted the TOS window**
(`win[0]=UNDEF`, Fn in `win[1]`) whenever pre-MAKE_FN `vsp!=0`. Empty-stack
IIFE lived (`vsp_d==e64`); nonempty DONKEY `var sprites; sprites=(function(){…})()`
died fault 4.

Fix in tree: `use_e64_win` requires `!hs_m_vsp`; combo `vsp_hs`/`VST_REL` follows
parent sticky vsp; IIFE BIND copies `e64_bind_*` when entering BIND.

## Headless evidence (this session)

| Program | Result |
|---|---|
| `fillRect`+`swapBuffers` | `S_IDLE eip=9` `nz0=64 front=1` `fault=0` |
| `function tick` + inner `rAF(tick)` | **`S_WAIT_FRAME raf=1` looping**, `nz0=64` |
| empty IIFE `return 7` then fillRect | **paints** `nz0=64 fault=0` |
| nonempty IIFE `var sprites; sprites=(function(){ Image; return 1; })()` | **paints** `nz0=64 fault=0` (the old DONKEY CALL_VAL gate) |
| `function f(){ return 7; } var n=f();` | **still `fault=2` at RET_VAL** `eip=2 vcsp=1` (parent `vcsp_ff=1`, exec FF 0) |
| `function go(){ fillRect; swap; } go();` | paints then **fault 2** on RET |
| DONKEY | **past IIFE 3668.** `S_IDLE eip=2488 fault=0` `obj=21 arr=2 spr=6 vcsp=1`. Op is `NEW_OBJ`/`SET_PROP mario` (`new …` argc=4 at 2487). **nz=0** |
| INVADERS | `S_IDLE eip=1803 LET_VAR fault=2 vcsp=1 obj=9 arr=2` — CALL_USER RET / `JSON.parse()\|\|[]` |
| PACMAN | `S_IDLE eip=1878 DUP fault=5` polyfill `if (!Date.now)` ~L25. JUMP 1822 **did** run |

## Failed-fix ledger (do not repeat)

| Tried | Why it came back |
|---|---|
| Skip `vobj_gen` / clone heaps in exec64 | Overnight cheat. **Forbidden.** |
| `a1=1` for every non-local | Skips `const bunkers` / upvalues. Only hoisted **function names**. |
| HEAP GETPROP `vst_win[0]` plant alone | Inner rAF of a **local** still HEAP-misses; IIFE CALL_VAL still dead |
| TOS window mux `EXEC && !leave_hold` + MAKE_FN `vst_win[0]` plant | rAF snippet already worked; nonempty IIFE still shifted TOS |
| Sticky `hs_m_vsp`/`hs_m_ip` until EXEC **without** `!hs_m_vsp` on the window | Extra beat `wvsp=e64_vsp_q < vsp_d` shifted UNDEF into TOS |
| `leave_hold <= (state != EXEC)` in the enable=0 else | **Deadlock** `eip=0` every snippet (exec `state` never EXEC at boot). Reverted. |
| Treat PACMAN `ip=0` as “never started” without `eip=` | IDLE `ip` is `ip_ff`; exec ip is `eip` |
| “Heaps are parent SRAM” while exec32 still had local `stack` | Killed-trial hang. Titles on exec64 still **synth exec32**. |
| `keep_hierarchy` to dodge combo `stack[]` | Unused `e32_p_clr` trim still flattened. RSS 16→37 GB, log stuck. |
| Chase **8-3936** `venv_rdata` trim | Last printed line, not the cause. Cause was **8-4767** `stack_reg` FFs. |
| 8-660 `vst_at` → unpacked `vst_peek[0:15]` **port** | Next flatten. Packed **port** OK. |
| Pack `vst_win_pack` then `` `VST_AT(x)[11:0] `` | **8-2599** nested `bus[a:b][c:d]`. Trial 15s fail. Unpack inside exec to 16 local 64-bit wires, then part-select those. |
| Drop unused combo `*_n` ports, leave SRAM we/raddr in opcode `always_comb` | Trial 4 hang unchanged. `e32_p_clr` last print, not the cause. |

**Keep:** `p_clr` one index/clock. Parent name SRAM. EXEC scalar `we` **before**
unique case. `hs64` includes EXEC/HEAP/ALLOC/GC/WAIT_FRAME/FRAME_*/BIND/RECT/CTOR_*.
Nested CALL_USER fillRect paints. Hoisted-fn `a1=1` rAF loops. Parent copies
`e64_fault_code_q`. BIND copy from exec on IIFE enter. Window `!hs_m_vsp`.
Do **not** restore `leave_hold <= (state != EXEC)` in the else overlay.

## Vivado trial 2026-08-17 (killed)

`make -C tools/board_flow bit` (reuse project, not `bit-fresh`). License OK.
exec64 module synth finished. exec32 `stack_reg` **8-4767 / 8-13159** → 65536
FFs (“too many ports (16)”); `arr_len` 13312 FFs; `vars` 16384 FFs. Log stuck
on `e32_p_clr_reg was removed` (`jmr_js_vm.sv` exec32 instance). RSS 16→37 GB
at 101% CPU, no new reports. Killed. No `.bit`. That private exec32 `stack` is
now parent SRAM + 16 TOS FFs (`e32_sv`). Next trial still user-only.

**Second trial (same day, 15s, not a hang):** `make bit` **8-2599** on
`jmr_js_vm_exec64.sv` `` `VST_AT(...)[11:0] `` after packing `vst_win_pack`.
Peak ~2.5 GB. No `.bit`. Do not part-select a packed-vector slice.

**Fourth trial (same day, killed):** combo `*_n` outputs became local; parent
muxes `*_q` only. `sim_server_synth` PASS. Synth still froze on
`e32_p_clr_reg was removed`; RSS 13.6→24.5 GB, log size stuck. Killed.
`e32_p_clr` is the last unused-FF print (same class as 8-3936), not the
cause. Remaining cone: combo `intern_var[]` / `cstack_*` / `env_oid[]` plus
SRAM `we`/`raddr` ports still assigned **inside** the opcode `always_comb`.

## Next (order)

0. **DONKEY `NEW_OBJ` 2487** (`a0=155 argc=4`) then `SET_PROP mario`. Ctor path
   inside ALLOC (kind 0 → kind 3 / BIND). Stops `S_IDLE fault=0` at 2488 — not
   HEAP, not WAIT_FRAME. Need the instance on TOS after ctor so SET_PROP runs.
   Do **not** skip gen. Rebuild `make -C sim sim_server_synth`. **No `make bit`.**
1. **CALL_USER RET_VAL fault 2.** Exec `vcsp` FF stays 0 while parent `vcsp_ff=1`.
   INVADERS `eip=1803` is that class. `vcsp_n=+1` on CALL_USER + ALLOC `fr=e64-1`
   did **not** stick through CTOR_PAD/BIND. Do not `leave_hold` deadlock again.
2. PACMAN `fault=5` DUP in `Date.now` polyfill (`eip=1878`). DUP itself faults 1
   in the opcode map — 5 is unsupported/other. After IIFE, first ops `JUMP 1822`.
3. Headless titles until `WAIT_FRAME raf>=1` and **nonzero** `FBRAW`.
   Only then F9 FPGA-SIM `(RTL)` on the three games.

**Stop:** overnight-go, `make bit`, host twin, skip gen, clone heaps, restore
local `name_blen[]`, rewrite HTML, delete files, `leave_hold` held in else.
