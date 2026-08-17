# Session handoff

**2026-08-17.** This file is **current truth only**. Failed fixes stay here so the next agent does not repeat them.

Product plan: [`working_html_fpga-sim`](/home/jonathan/.cursor/plans/working_html_fpga-sim_a719ac28.plan.md). **No `.bit` / `make bit`.** Do not rewrite `storage/*.HTML`. FPGA-SIM is the same `rtl/*.sv` as the standalone `.bin`.

## User last F9 (`traces/session_20260817_134044_000976_FPGA-SIM.log`, `rtl_mtime=1786972337`)

Correct `LOAD`. One miss, three glass symptoms:

| Title | Log | Glass |
|---|---|---|
| INVADERS | compile-on-RUN; HUD `vdraw=48,465,14×5`; `obj=206` (no ~480 cell objects); `dihit` climbing | no bunkers |
| PACMAN | first `fclk≈879k` then `≈32k`; `vdraw` leftover INVADERS 14×5; `FBRAW nz=0`; `arr=393` | black |
| DONKEY | `spr=6` `dihit` climbing `FBRAW nz≈60k` | world draws; Mario faces left |

`obj=206` after Space is the invaders grid **without** bunker cell objects. `xs.length` / `cells.push` / `standRight[0]` / `maps.forEach` all hit exec `varr_gen` after GC reuse (handle gen=2, exec copy still 1 because poke 45 never stamps gen). ARRAY intern returned undefined / skipped push. Donkey `drawFrame(undefined,undefined)` → sprite 0,0 = standLeft.

## Failed-fix ledger (do not repeat)

| Tried | Why it came back |
|---|---|
| Skip `vobj_gen` / clone heaps in exec64 | Overnight cheat. **Forbidden.** |
| Stamp gen into poke 45 to hide dual-copy skew | Same cheat class as poke 44. Drop the **exec gen gate** instead; keep `varr_valid`. |
| Compiler `a1=1` guessed global | Hoisted fns skipped env. a1=0 chain unless local. |
| Intern gated on **exec object** alloc/gen | Copies lag → skip fillRect. Shape-only; parent HEAP keeps gen. |
| Parent HEAP gen vs **TOS** | Latch gen at issue (`hp_spr_w[11:0]`). |
| Isolation pytest ≠ HTML | Do not mark F9 green from pytest. |
| Title-named RTL gates | Forbidden. |

## Fix in (rebuild `make -C sim sim_server_synth` before F9)

- ARRAY `.length` / `[i]` / `push` / `forEach`: intern on `varr_valid` only, **not** exec `varr_gen` (same class as `obj_ok`).
- RUN clears `vdraw_*` so SNAP is this title, not leftover intern.

## Caps (do not grow)

`MAX_OBJ=1024`. Arrays two-tier `1536×32` + `128×128`. `ENV_DEPTH=512`. Same in PYTHON.

## Next

You F9 this rebuild. Expect FPGA-SIM first tap. Maze must hold. Do not start `make bit`.
