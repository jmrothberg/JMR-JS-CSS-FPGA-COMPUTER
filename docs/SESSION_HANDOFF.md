# Session handoff

**2026-08-18 (headless, not an F9).** One file for the next agent. Do **one**
step from **Next**. Do not overnight-go. **Do not tell the user to F9 the
three games yet.**

Product: a **standalone HTML/JS-native computer** on Nexys Video **T200**.
Not a browser. Not dukpy. FPGA-SIM and the `.bin` are the same `rtl/*.sv`.

Law: `never-fake-fpga-sim`, `one-heap-keep-gen`, `python-first-parity`,
`no-dukpy-cheat-native-cpu`. ABI: [`docs/JMR_JS_COMPATIBILITY.md`](JMR_JS_COMPATIBILITY.md).

## Now

PYTHON F9 glass for INVADERS / PACMAN / DONKEY is **user-confirmed**. FPGA-SIM
titles are **not** all F9-ready. Headless gate: `S_WAIT_FRAME` `raf>=1` and
**nonzero** `FBRAW` on all three. Do **not** `make bit`. Extra CALL operand
beat (`opnd3`) stays — rAF after `getElementById`/`getContext` ALLOC is proven.

INVADERS splash **paints** on FPGA-SIM (`FBRAW nz=19233`, `fault=0`, rAF
looping inside `drawSplash`). PACMAN still **fault 4** during boot.
DONKEY **parks** `WAIT_FRAME` after one title `update` (`raf=0` by HTML:
rAF only in `gameState=="game"`). Title art is `Image.onload` + `drawImage`;
`fillText` is at world y=500/600 after `setTransform`.

## What worked (this session)

| Program | Result |
|---|---|
| `constructor(){ this.n = f(); }` | **paints** `nz0=64` `fault=0` |
| `rAF(tick)` fillRect loop | **`WAIT_FRAME raf=1` `nz0=64`** |
| top-level `forEach` then `rAF` | **`WAIT_FRAME raf=1`** |
| `forEach` **inside** `animate` then rAF | **`WAIT_FRAME raf=1`** (was rAF overflow 3) |
| nested `forEach` then rAF | **`WAIT_FRAME raf=1`** |
| `p.update()` class method inside `forEach` then rAF | **`WAIT_FRAME raf=1`** |
| `ctx.fillRect` after `getContext` | **`WAIT_FRAME raf=1` `nz0=800`** |
| INVADERS title | **splash pixels** `nz=19233` `vdraw=70,68,500,7` `fault=0` (TICKN samples mid-frame; splash > `FRAME_DIV`) |
| PACMAN title | **`fault=4`** `eip=1720` `ip=16129` `ev=3` `cr=LOAD_VAR` after `new Stage` |
| DONKEY title | `WAIT_FRAME` `raf=0` `vdraw=0,0,640,480,0` (black `clearRect`); **past Game ctor** |

Parent-reserve ALLOC (FOREACH / FRAME_RAF / LOOKFN / getter / onload) poked
`hs_vcsp(e64+1)` the cycle **before** ALLOC. Exec had not absorbed it, so
`fr = e64-1` overwrote the caller with `0xfffc` (animate `RET_VAL` fault 2 /
leftover rAF overflow). Fix: if `hs_m_vcsp && vcsp_ff == e64+1`, `fr = e64`.

Exec `ctx_sx`/`ctx_sy` were 0 after rst (`fillRect` clip to 0). Init `FX_ONE`
on rst and `p_clr`. Parent GOT_HDR already did; exec fillRect uses exec FFs.

## Failed-fix ledger (do not repeat)

| Tried | Why it came back |
|---|---|
| Skip `vobj_gen` / clone heaps | Forbidden |
| `leave_hold <= (state != EXEC)` in enable=0 else | Deadlock `eip=0` |
| FETCH trampoline taking JUMP while `vctor_takejmp` | field2 width UNDEF |
| Kind-3 `fr = max(e64-1, vcsp_ff)` | Parent leaked to 193; CALL_USER wrote the wrong frame |
| Sticky `hs_m_vcsp` poke always wins over `vcsp_n` | Nested `new` stayed at depth 1 and clobbered Game's frame[0] |
| Delay `hs_m_vcsp` clear until CALL `opnd2` | INVADERS RET 3367 still `ev=0` |
| Wait-beat `vcsp_n = vcsp_hs` including overlay 0 | FOREACH `hs_vcsp(0)` wiped animate |
| Skip `vfn_valid`/`gen` on rAF | Overnight cheat; forbidden |

**Keep:** MAKE_FN push `win[1]` + `vst_hold_win`. CALL/CALL_VAL/CALL_METH
**third operand wait**. ALLOC overlay-detect `fr`. Exec identity `ctx_sx`.
Exec `vcsp <= vcsp_n` when the opcode changed depth, raise-only poke when
live. BIND copy from exec **only on IIFE `leave_hold`**. Window `!hs_m_vsp`.
Method-bind GET_PROP sentinel `13'h1FFF`. Do **not** restore `leave_hold`
held in else.

## Next (order)

0. **PACMAN `fault=4`** at createStage `LOAD_VAR stage` after `new Stage(options)`.
   Same-shape snippets (`class Stage` / `this.createStage = function` /
   `var Stage = function` in a factory) **paint**. Title has `var Stage` plus
   a class-table `Stage`, `Object.assign(this, _settings, _params)` with
   `update:function(){}` inside the ctor, then `game.createStage()` from an
   IIFE. Prove env recycle vs ctor-ip vs intern_var HEAP miss. Do not skip gen.
1. **DONKEY title art.** HTML does **not** re-arm rAF on the title branch.
   `showTitleScreen`: `clearRect` + `Image` data-URI `onload` `drawImage` +
   `fillText` at y=500/600 in world space after `setTransform`. Headless
   `nz=0` is the black clear; onload/drawImage/fillText must land on 640×480.
2. **INVADERS** headless `FRAME` (not only `TICKN`) until `WAIT_FRAME` with
   `nz>0`, then Enter/space. Splash already has pixels.
3. Only then F9 FPGA-SIM `(RTL)` on the three games. **No `make bit`.**

**Stop:** overnight-go, `make bit`, host twin, skip gen, clone heaps, restore
local `name_blen[]`, rewrite HTML, delete files, `leave_hold` held in else,
sticky `hs_m_vcsp` over `vcsp_n`.
