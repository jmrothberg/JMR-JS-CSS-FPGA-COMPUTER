# Session handoff

**2026-08-15 night.** Plan does the work. This file is **current truth only**.

Product plan: `working_html_fpga-sim`. PYTHON glass step is **user-confirmed**.

## User last saw (PYTHON GUI)

| Title | Glass |
|---|---|
| INVADERS | works |
| PACMAN | works |
| DONKEY | works |

User F9 PYTHON: all three `LOAD "NAME.HTML"` / `RUN` play **on the previous 8192/4096/128 heap**. PYTHON leftover-BRAM caps are now `MAX_OBJECTS=1024`, `MAX_ARRAYS=512`, `ARRAY_ELEMENTS=128`, `ENV_DEPTH=512` (ten live nested maps need >256 arrays; env 512 is the BRAM trade). Re-F9 PYTHON if a title overflows 512 envs. Do not mark BOARD/ASIC done.

## FPGA-SIM lockstep (waiting F9 — do not treat this table as F9)

`make -C sim sim_server_synth` is current. Same ProgramImage stream as PYTHON. Headless pixel gates on real RTL (`sim/sim_build_synth/jmr_js_sim_server`, no host twin). **After leftover-BRAM caps (2026-08-16):**

| Title | Gate | Result |
|---|---|---|
| INVADERS | held-left FB changes, `fclk` ≤ 64M | passed |
| PACMAN | Enter leaves splash, maze `nz` ≥ 1000 | **failed** — `fault=3` at `ip=1235` |
| DONKEY | title `nz` ≥ 50, Enter keeps rAF, FB keeps changing | **failed** — FB blank after Enter |

Last RTL lockstep: class `get name()` on GET_PROP now invokes (same stack as CALL_METHOD argc 0). DONKEY floor collision uses `this.marioBottom`; without the getter the overlap test saw `+0` and the player fell through. Same class of miss as a projectile AABB that never sees real edges.

User has **not** F9-approved FPGA-SIM `(RTL)` yet. Please F9 FPGA-SIM `(RTL)`.

PACMAN idle crash (2026-08-16): Value64 GC now rewinds bump cursors; `Array.map` / JSON.parse collect-then-retry. Confirm on F9 after flatten compiles.

**Silicon after flatten (2026-08-16):** nested `vobj_rdata[79:64][9:0]` is now `vobj_rdata[73:64]`. Slot caps: `MAX_OBJ=1024` / `MAX_ARR=512` / `ARR_CAP=64`. Env slots are 1-D `venv_slot` (same `S_HEAP_*` + `hp_env`, stop at `venv_len`) — not 2-D `venv_val` (Synth 8-4556). `ENV_DEPTH` stays 1024 in RTL and PYTHON. External 4 MB remains ASET art. `make -C sim sim_server_synth` rebuilt. Other agent re-runs `make -C tools/board_flow bit`. **No flash until F9.**

Headless pixel gates after those caps:

| Title | Gate | Result |
|---|---|---|
| INVADERS | held-left FB changes, `fclk` ≤ 64M | passed |
| PACMAN | Enter leaves splash, maze `nz` ≥ 1000 | **failed** — `fault=3` at `ip=1235` (CALL_NATIVE getImageData), `gc=1`, `heapovf=0` |
| DONKEY | title `nz` ≥ 50, Enter keeps rAF, FB keeps changing | **failed** — FB went blank after Enter |

Do not mark F9 green. Restart the GUI for the new `jmr_js_sim_server`. **No `.bin` until F9.** Other agent runs `make -C tools/board_flow bit` only after you approve. Runtime JSON/stringify and PACMAN/DONKEY play are paused until this synth-legal heap is F9-checked.

**F9 FPGA-SIM 2026-08-16 (not approved):** `LOAD "pacman.html"` / `RUN` compiled, then `fault=255` at `ip=13670`. Flatten `MAKE_ARRAY` wrote the array handle onto `stack[0]` *before* `S_HEAP_FILL`, so `a[0]` became the array itself and PACMAN used that tagged value as an index. Handle now lands after the SRAM copy. FRAME also returns on a dead VM (does not burn 64M). Restart the GUI for the new `jmr_js_sim_server`. **No `.bin` until F9.**

**Silicon loops / vstack (2026-08-16):** Synth 8-3380 `for (i = j; i < 4)` in
`remove_key_listener` is now constant-trip `if (i >= j)`. `release_env_to`
is `S_REL_ENV` (one live env index per clock, dup scan 32). MAX_OBJ/MAX_ARR
find-free is `S_FREE_OBJ` / `S_FREE_ARR`. `vstack` is 1W1R BRAM + 16-deep TOS
window; bind_argv and Math.min/max are sequential. Reset
`for (i = 0; i < ENV_DEPTH)` / `MAX_OBJ` metadata FFs stay constant-trip.
4 MB asset SRAM still art. No `ifdef SYNTHESIS`.

**Synth 8-660 vst_at (2026-08-16):** `function automatic vst_at` is gone. Combo
TOS window is `vst_peek[0:15]` (`always_comb` from `vst_win`); FSM uses
`` `VST_AT `` (index into the wire — no function, no extra parens, no BRAM
combo read). `vst_wr` task kept. VM `$readmemh("font_rom.hex")` needs the hex
beside `rtl/engines/jmr_js_vm.sv` (board_flow copies it there, not only
`rtl/video/`). `make -C sim sim_server_synth` rebuilt; 4 Value64 checkpoints
passed.

**Board SRAM / palette (2026-08-16):** `jmr_js_vm` synthesized (8-660 gone).
Core default `SRAM_INTERNAL=1` keeps `jmr_sram_model` for FPGA-SIM (not in
the board netlist). Board top is `#(.SRAM_INTERNAL(0))` + MIG DDR3 native UI
+ `jmr_ddr3_sram_bridge` (first 4 MB = ASET art). `jmr_palette_bram` is dual
clock (write core, read pixel) and HDMI game mode uses that palette, not the
6-color stub. **This is the .bin gate:**
`source scripts/vivado_env.sh && make -C tools/board_flow bit`
Do **not** flash until F9 FPGA-SIM. Restart the GUI for the new sim server.

**No flash until F9.**

User F9 note (not approved): INVADERS/PACMAN say working then pop to monitor;
DONKEY plays a few minutes then pops. Likely heap/fault after leftover-BRAM
caps — paused until this synth-legal RTL is F9-checked. Do not mark F9 green.

**F9 FPGA-SIM 2026-08-16 glass (not approved):** DIR works. DONKEY/PACMAN
`RUN` → READY (`fault=2`, leftover `vcsp`). INVADERS splash then freeze
(`S_WAIT_FRAME`, `raf=0`; Space/Enter delivered, no play). RTL `ip>=n_ops`
with a live call now implicit-returns undefined (PYTHON). rAF/key/timer/
forEach pushes are one `vst_wr` per clock plus an idle beat so the TOS
window matches ALLOC. Restart GUI, F9 FPGA-SIM. INVADERS starts on **Space**.
**No `.bin` until F9.**

**F9 FPGA-SIM 2026-08-16 glass round 2 (not approved):** INVADERS splash then
Enter → READY (`fault=3` `ip=1165` `push`). PACMAN immediate READY (`fault=1`
`ip=2686` `MAKE_ARRAY 28`). DONKEY play: ladders + sprites, no ramps, player
sank (`raf=1`, `dihit` +41/frame, no fault). Root: 16-deep TOS window does
not refill after `MAKE_ARRAY` of 16+; `SET_PROP` then wrote onto leftover
`win[1]` instead of `this` (53 platforms / 28-wide maze rows). RTL now
refills `win[1..15]` from BRAM (`S_V64_WIN_FILL`). INVADERS still starts on
**Space** (Enter also fires the score-save `click` listener). Restart GUI,
F9 FPGA-SIM. **No `.bin` until F9.**

**F9 FPGA-SIM 2026-08-16 glass round 3 (not approved):** INVADERS splash then
Enter → READY (`fault=3` `ip=1165` Bunker `cells.push`, not Grid aliens).
PACMAN `RUN` → READY (`fault=4` `ip=1921` `LOAD_VAR Date` in the rAF
polyfill). Same array BRAM: `MAX_ARR=256` × `ARR_CAP=128` (7-bit slot). Dead
closure env parent now falls through to vvars (PYTHON globals) instead of
ERROR_HANDLE. Monitor keeps the typed `RUN` line; do not overlay WORKING.
Restart GUI, F9 FPGA-SIM. INVADERS starts on **Space**. **No `.bin` until F9.**

**F9 FPGA-SIM 2026-08-16 glass round 4 (not approved):** INVADERS works.
PACMAN `RUN` → READY (`fault=255` `ip=15072` `ARRAY_GET` `_COS[this.orientation]`).
DONKEY play then READY (`fault=3` `ip=2411` `console.log` every Mario.update,
256-entry cap). RTL `console.log` now rings like PYTHON (no halt). Non-Number
array index returns undefined, not ERROR_INTERNAL. Monitor keeps typed `LOAD`/`RUN`
rows after skip_line HTML RUN and after a VM fault (entries must not vanish).
Restart GUI, F9 FPGA-SIM. INVADERS starts on **Space**. **No `.bin` until F9.**

**F9 FPGA-SIM 2026-08-16 glass round 5 (not approved):** Monitor packed typed
LOAD/RUN at the top (16-row VRAM blanks were skipping `> run` to the bottom).
PACMAN bounce was RTL `Object.assign(this, settings, params)` dropping `params`
after TOS collapse (`times`/`orientation` missing; `fault=5` at `this.times % 2`).
Assign keeps sources until copy finishes; GC stack roots read `vstack` BRAM;
MOD ToNumbers like PYTHON. Restart GUI, F9 FPGA-SIM. INVADERS starts on
**Space**. **No `.bin` until F9.**

**F9 FPGA-SIM 2026-08-16 glass round 6 (not approved):** PACMAN `RUN` → READY
(`fault=3` `ip=9357` `MAKE_ARRAY 31`) — ten live 31×28 number-array maps
exceeded `MAX_ARR=256`. Cap is now `MAX_ARR=512` / `ENV_DEPTH=512` (same
PYTHON; ARR_CAP stays 128). ASTEROID splash then freeze after Enter: RTL
had `push`/`splice` but no `Array.pop`, so `while (a.length > 0) a.pop()`
never shrank (64M `S_HEAP_CMP`). `Array.pop` matches PYTHON. Monitor host
log is chronological (`> LOAD` / `LOADED` / `> RUN`) — do not append a
leftover `> run` after later LOADs. Restart GUI, F9 FPGA-SIM. INVADERS
starts on **Space**. **No `.bin` until F9.**

