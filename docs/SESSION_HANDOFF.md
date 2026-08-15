# Session handoff — next agent start here

Last updated: 2026-08-14 (JA+JB in JS board top; FPGA-SIM untouched).
Battery is play-progression with **ghost-color outside house** (not any-pixel).
Fonts are **not** Chrome (8×8 / rect stub) — out of scope. User F9 remains
the play gate. Mission: PYTHON + FPGA-SIM full-game match

## LANDED 2026-08-14 — Pmod JA+JB in JS board top (FPGA-SIM unchanged)

User asked to wire the proven LED-test PHY into the JS console so the next
board flash types on **JA** and plays from the **JB** stick. Same plugs; do
not rewire. PYTHON / FPGA-SIM / GUI not edited (F9 still PC keys). J15 RX
left in place. `jmr_ps2_host` still off. Frozen JS LEDs unchanged.

Files: [`rtl/top_nexys_video.sv`](../rtl/top_nexys_video.sv),
[`constraints/nexys_video.xdc`](../constraints/nexys_video.xdc),
[`rtl/phys/jmr_i2c_master.sv`](../rtl/phys/jmr_i2c_master.sv),
[`rtl/phys/jmr_i2c_joy.sv`](../rtl/phys/jmr_i2c_joy.sv),
[`tools/board_flow/vivado_build.tcl`](../tools/board_flow/vivado_build.tcl).
LED test under `tools/pmod_input_test/` kept. Next JS `bit flash` picks it up.

## LANDED 2026-08-14 — Pmod PS/2 + I2C joystick LED test **PASS** (not JS console)

Isolated bit [`tools/pmod_input_test/`](../tools/pmod_input_test/) — user confirmed
JA keyboard + JB stick on the LED map. No PYTHON / FPGA-SIM / `top_nexys_video`
edits. J15 USB-HID RTL left in place (PIC24 dead on this unit and a second
Video board). Re-flash (Vivado idle):

```bash
source scripts/vivado_env.sh && make -C tools/pmod_input_test bit flash
```

Plug: **Pmod PS/2 → JA** (Data=JA1 Clock=JA3). **Mini I2C stick 0x5A → JB**
(SCL=JB1 SDA=JB2, labels not colors). LEDs LD0 left: LEFT UP DOWN RIGHT A/C
B/D stick-OK keyboard-pulse. Same plugs as the JS console top (merged above).

## LANDED 2026-08-14 late — PACMAN unfrozen (boot nursery headroom)

`ARR_KEEP_DELAY` 8 → 3. The nursery does **not rewind at all** during the keep
grace window, and then the watermark snapshots whatever exists — so 8 frames of
per-frame temps got baked into the kept region (PACMAN snapshotted at
`obj=3263`). With too little headroom left, a frame allocated over its own live
rAF `Fn` object, the dispatcher then ran a stale function (`cbip` landed inside
the `Game` factory at ip 1823, not the loop), that function returned without
re-arming, and `raf` stuck at 0 — PACMAN froze on its first drawn frame with the
presenter free-running (swaps +140/sample instead of +8). Now `obj=2288`,
`raf=1` stays 1 through Enter and direction keys, one swap per frame, and the
mouth animates.

- Diagnosed with a new minimal latch: `dbg_cb_ip` (VMSTAT `cbip=`) = ip where
  the last frame-level callback returned. That is what identified the stale
  function; keep it.
- Guard: `test_rtl_boot_heavy_loop_survives`.
- Rejected alternative: arming both keep watermarks at the first callback
  registration (`commit_boot_keep`). It fixed PACMAN but starved the finder
  snippet's boot closures (hung in `S_ENV_LOAD`). The task is left in place,
  unused, as the documented design note.
- Not a regression from the string-bytes work: the 18:19 trace (before it) has
  the byte-identical `state=16 ip=16325 raf=0 obj=3263 arr=1972`.

### Known remaining parity gaps vs PYTHON (PACMAN/INVADERS screens)

1. **`fillText` draws solid bars in RTL, real glyphs in PYTHON.** This is the
   "screen not complete" report: PACMAN's SCORE/LEVEL and INVADERS' HUD are
   bars. A font ROM already exists (`tools/export_font_rom_hex.py`) — wire
   `fillText` to it.
2. **Maze rounded outer border** draws as partial straight lines in RTL vs a
   clean rounded rect in PYTHON (path/arc rasteriser).
3. Top-level `LET_VAR` is "init only if missing" in **both** FM and RTL
   (startLoop re-entry), so `var row = []` in a *top-level* loop aliases one
   array on either rung. Shared compromise, not a divergence — real titles
   build rows inside functions.

## LANDED 2026-08-14 late — RTL string bytes + deep heap keep

1. **`str[i]` / `str.length` in RTL (INVADERS aliens were invisible).**
   The VM kept only a hash+length per interned string and never read the
   trailer's UTF-8 names, so `row.length` was undefined (character loop body
   skipped) and `row[col]` was undefined. Every string-row sprite drew nothing
   while `fillRect`/`drawImage` art painted — that is why the glass looked
   frozen with bunkers + ship but no wave (`raf=1`, `swaps` still climbing).
   - `jsb_format` now marks the name section with **`NAMB`** so the trailer FSM
     finds it with the same 4-byte peek it already does for `SPR1`/`SPRD`
     instead of inferring the position (PYTHON decode skips the marker, and
     tolerates its absence).
   - VM streams the bytes into `name_mem` (**32 KB on-chip BRAM, registered
     read** — one cycle in `S_STRIDX`/`S_STRIDX_WR`, no 32 KB mux, same shape on
     ASIC). The 4 MB external bank stays for art.
   - `char_id[256]`/`char_ok[256]`: a 1-char name's hash IS its byte, so `str[i]`
     maps a byte to that intern id in one lookup and `row[col] === "1"` is a
     plain intern compare — no string walk.
   - `.length` also answered for `CLS_DYNSTR` (replace / JSON results).
   - VMSTAT gained `strb=` (name bytes loaded) and `strovf=`.
   - Snippet: `test_rtl_string_row_bitmap_draws`.
   - Verified: INVADERS formation band went **40 px → 26364 px**; splash wave
     10522 px. `traces/INVADERS_rtl_active.png`.
2. **Deep heap keep (generic lifetime bug).** `commit_arr_keep` was **dead
   code** and `commit_obj_keep` only kept `oid+1`, but a constructor allocates
   its children AFTER the instance — so `arr.push(new C())` kept the object and
   rewound its own arrays and child objects on the next frame. New
   `commit_deep_keep` raises BOTH watermarks to the current bump pointers on a
   genuinely-new store; array-over-array slot overwrite now copies in place
   (like object-over-object), so per-frame churn still cannot creep.
   Snippets: `test_rtl_ctor_children_survive_frames` (needs per-frame churn to
   show — rewind only resets the pointer, it does not clear data),
   `test_rtl_coord_overwrite_does_not_heapovf` still green.
3. **Do NOT raise the sim SPI speed.** `-GSD_RUN_DIV=1` (clk/4) and `0` (clk/2)
   both make the C++ card in `sim_main.cpp` miss MOSI setup — every LOAD returns
   `?IO` and all RTL snippets fail with FB `nz=0`. Sim stays at the module
   default clk/8. DONKEY load time must be fixed above the SPI layer.

## LANDED 2026-08-14 night — DONKEY Enter + PACMAN reverse + INVADERS Space

1. **DONKEY title Enter.** RTL `GET_PROP` now materializes class methods as
   Fn values (`this.startSelect` / `this.choose`) and caches them on the
   instance — same as PYTHON `bytecode.py`. Snippets:
   `test_class_field_listener_sees_enter`,
   `test_rtl_class_field_listener_enter`.
2. **PACMAN reverse / mouth.** `player.control = {orientation}` was a
   nursery object; the per-frame rewind deleted it before the next cell
   center. SET_PROP now copies object-into-object in place and commits keep
   on first store onto old-space. rAF/timer fns also commit keep (`raf=0`
   killed the start() loop, so the mouth `times%2` never ticked). Snippet:
   `test_rtl_control_object_survives_frames`. Coord overwrite still rewinds
   (`test_rtl_coord_overwrite_does_not_heapovf`).
3. **INVADERS Space.** Attract splash needs `const { key } = e; key === " "`
   (no auto-click). Snippets: `test_destructure_space_key_starts`,
   `test_rtl_destructure_space_key`.
4. **DONKEY LOAD/RUN minutes.** RUN wait now uses `TICKN 20000` instead of
   236× `TICKN 2000` RPCs (that RPC overhead was most of the wall time).
   **Do NOT speed up the sim SPI divider:** `-GSD_RUN_DIV=1` (clk/4) and `0`
   (clk/2) both make the C++ card model in `sim_main.cpp` miss MOSI setup and
   every LOAD returns `?IO` (all RTL snippets fail, FB `nz=0`). Sim stays at
   the module default clk/8, same as the board.

## LANDED 2026-08-14 evening — GUI + DONKEY title + play clocks

1. **GUI window never resizes.** `gui_jmr_js.py` pins geometry after first
   layout (`resizable False`, minsize=maxsize). Status/hint are width=80
   truncated — Enter / F9 / LOADING must not grow the alleys. Glass stays
   640×480.
2. **One cursor.** Yellow `|` glyph removed. Cyan block at insert column
   (`cursor_col`).
3. **DONKEY FPGA-SIM title stuck.** RTL `OP_NEW_OBJ` now copies `(type,
   options)` for interned `KeyboardEvent`/`Event`/`CustomEvent`/`MouseEvent`
   (PYTHON twin in `bytecode.py`). Boot script `new KeyboardEvent("keydown",
   {key:"Enter"})` + `dispatchEvent` advances title → character → game.
   Snippets: `test_keyboard_event_ctor_sets_key`,
   `test_rtl_keyboard_event_ctor_sets_key`.
4. **Play clocks.** GUI `frame_tick` uses `FRAME` (tick until `dbg_swap_n`
   or 2M-clock cap) instead of `TICK`=1000. VM `frame_tick` is every 65536
   clocks — 1000-clock TICK starved PACMAN ghosts/reverse and DONKEY rAF.
   LINE also breaks after `game_mode` (+16 slices for boot rAF) and logs
   `OK clk=… capped=…`.
5. **Logs.** KEYEVT coalesced; periodic `play fb_frames=` + VMSTAT; no
   duplicate GLASS.

**Still user F9:** confirm DONKEY title→game, PACMAN reverse+mouth, INVADERS
Space start. Board / `.bit` untouched. Fonts still rect stub.

Goldens (`tools/golden_frames.py` 2026-08-14 evening): DONKEY RTL now paints
(`nz=45632` vs PYTHON `60003`) — title is no longer a stuck sprite-soup.
PACMAN occupancy PYTHON vs RTL still **148 center-bits** (maze arcs vs spokes
gap; not a hard CI gate). INVADERS PYTHON vs RTL tile mismatch remains
(fillText stub + timing). User F9 is the play gate.

## OPEN BUGS 2026-08-14 — finite surface + maze + ghosts

Frozen ISA from compiling the three HTML titles is in
[JMR_JS_COMPATIBILITY.md](JMR_JS_COMPATIBILITY.md) (done / gap / never).
WebGL, Fetch, Audio, TTF, `window.open` = **never**. Fonts stay 8×8 / rect
stub — not Chrome Arial.

### PYTHON — this stretch

1. **`join('')` EQ `case '1100'`.** String-value `===` plus JS ToString on
   join so neighbor-bit keys hit quarter-**arcs**, not `default` spokes.
   Snippets: `test_join_empty_eq_case_1100`,
   `test_switch_join_draws_arc_not_spokes`.
2. **Ghost-update snippet** leaves the start cell (`timeout` / `!offset` /
   finder / `_COS`). `test_ghost_update_leaves_start_cell`.

### FPGA-SIM — this stretch

3. **Array nursery = object keep.** `commit_arr_keep` raises `n_arr_keep` to
   **oid+1** (not `n_arr`). `Array(n)` / `map()` temps are nursery. Rewind
   does not wait for `click_fired`. Finder JSON/steps no longer pin
   `arr=4095`. Snippets: `test_rtl_join_empty_eq_case_1100`,
   `test_rtl_switch_join_draws_arc_not_spokes`,
   `test_rtl_ghost_update_leaves_start_cell`,
   `test_rtl_finder_many_frames_still_paths`.

### Battery / goldens

- Play-progression fails unless **ghost-colored** pixels exist **outside**
  the house bbox (map cells 11–16 × 12–15 at origin 16,8 size 14), PYTHON
  and RTL, after Enter (title → stage 0).
- `tools/golden_frames.py`: PACMAN **stage 0** occupancy mask (HUD x≥410
  masked). PYTHON vs RTL center-bits = corridor topology. Chrome occupancy
  skipped if still on the title (no Enter). Color `#09f` vs `#9966CC` is
  FSTY, not topology.

**Still out of scope:** fillText glyph ROM, Chrome fonts, `.bit`/`.bin`.
User F9 PYTHON then F9 FPGA-SIM is the play gate.

---

## Product goal (do not forget)

We already have a **fully working BASIC-native FPGA computer**:

- Repo: `/home/jonathan/JMR-BASIC-FPGA-COMPUTER`
- Board: Digilent **Nexys A7-100T** (Artix-7 **XC7A100T** — “T100”)
- Standalone: VGA + USB keyboard on **J5** + console + games — **keyboard works**

This repo is the **same product idea**, different language and graphics:

- Repo: `/home/jonathan/JMR-JS-CSS-FPGA-COMPUTER` (**this** tree)
- Board: Digilent **Nexys Video** (Artix-7 **XC7A200T** — “T200”)
- Native language: **JavaScript** (bytecode + engines), not BASIC tokens
- Glass: **HDMI 640×480** Canvas / FB, not VGA BASIC text strip
- Steal **method** from BASIC (PYTHON → real FPGA-SIM → board). Steal **not**
  A7 pinouts, BASIC ISA, or BASIC LUT history.

**End state:** a fully functional JS-native FPGA computer — tethered **or**
untethered — same experience as BASIC on T100, but JS/CSS-Canvas on T200.

---

## NEW AGENT MISSION (stop here until this is true)

**Goal of this stretch:** `INVADERS.HTML`, `PACMAN.HTML`, `DONKEY.HTML` each
`LOAD` + `RUN` as the **full game** on **PYTHON** and **FPGA-SIM (RTL)**,
and those two **look and play the same** (same glass, same keys, same
graphics quality). Chrome is the visual authoring check, **not** a proof
rung. **Do not flash the board** until the user F9-approves both.

**Definition of done (PYTHON + FPGA-SIM only):**

1. User types only `LOAD "NAME.HTML"` then `RUN` (edit HTML; line numbers =
   that file). Compile-on-RUN every time. Never prefer stale `.JSH`.
2. **Great graphics survive.** Donkey sheets are full quality. Art rides the
   fresh `.JSH` **ASET section** into the **external 4 MB SRAM asset bank**
   (2M × 16 IS61WV204816 contract; FPGA board = DDR3 behind a simple SRAM
   port; ASIC = the real chip — see `docs/ARCHITECTURE.md`). No `NAME.DAT`
   file. EDIT then RUN regenerates everything. Do **not** downscale into
   code BRAM.
3. PYTHON bytecode VM and FPGA-SIM RTL play the **same** title the **same**
   way. Battery stays green. No dukpy. No host twin (`JMR_SIM_HOST=1`).
4. Grow the **VM / compiler / natives / DAT pager** to fit the HTML. Do
   **not** rewrite the three games down to a subset. Do **not** delete files.

**Honest: F9 play-test round 3 landed 2026-08-14 (PYTHON then RTL). Battery
PASS is pixels+Left smoke, not a play proof. Do not claim INVADERS-shoot
or ghosts-leave-box from that PASS. User F9 PYTHON then F9 FPGA-SIM is the
remaining gate.**

| Item | Reality |
|---|---|
| Compile-on-RUN PYTHON | **Landed** — default HTML path is bytecode; dukpy only if `JMR_HTML_DUKPY=1` |
| Stale `.JSH` preferred | **Fixed on PYTHON** — `RUN` compiles then writes fresh `.JSH` |
| External SRAM asset bank (ASET) | **Landed** — full-res sheets ride `.JSH` ASET → 4 MB SRAM model; RTL blits per-pixel from the SRAM port (`aset_mode`), 16 descriptors, compiler **fails loud** past 16 (never drops art). Old downscale trap removed |
| RTL setTransform scale | **Landed** — `ctx_sx/ctx_sy` Q16.16 copied from FM `machine.py _xf` (`int(x*sx+tx)`, `max(1,int(w*sx))`); save/restore keep scale. DONKEY world→glass scales on RTL |
| PYTHON vs Chrome | All three RUN + respond to keys on PYTHON bytecode; **full look/play match not yet user-F9-verified** — do not claim done |
| PYTHON LIST | **Fixed** — 64-col wrap + MORE paging; ESC aborts MORE (`more_waiting`; GUI must not paint `>` over `-- MORE --`). Fat `data:image` lines **are** the HTML — LIST never shows `.JSH` |
| Raw keyboard → games | **Landed** — KEYEVT for **all** keyCodes (incl. space/arrows). KEYBITS joy tether kept; skip KEYBITS-edge synthetic keydown when a KEYEVT for that code is already queued. `e.key` for space is U+0020 `" "`, not `"Space"`. HTML decides bindings |
| RTL Date frame clock | **Fixed** — `time_ms` advances 17 ms once per frame in `S_WAIT_FRAME` (FM twin); `Date.now()`/`getTime()` are pure reads. The old +17-per-CALL hack made PACMAN game time race ahead |
| PACMAN purple flood | **Fixed** — `getImageData(0,0,640,480)` hit the fillRect argc-4 fallback and painted a full-screen rect with the stale wall strokeStyle. Fallback retired; `getImageData`→undefined / `putImageData` no-op (maps redraw per frame) |
| FPGA-SIM vs PYTHON | Battery **PASS** (2026-08-14 round 3): INVADERS/PACMAN/DONKEY HTML pixels+keys on PYTHON and RTL. Dedicated **128 KiB SOURCE BRAM** (not 8K work RAM). DIR names only (hide `.JSH`/`.JSB`). LOAD wait is this stem+LINES. LIST waits for MORE/prompt. `e.key === " "` KEYEVT; mini-finder BFS on RTL (`var f=function` → CALL_VAL). ASET SRAM stays art from address 0. **Open RTL debt:** (1) `fillText` still a rect stub (glyph ROM missing), (2) RTL walls paint `#9966CC` while FM level-1 walls are `#09f`. |
| Board | **Out of scope** this stretch. Last bit 03:36 lags the tree. No `.bit`/`.bin` |

---

## OPEN BUGS 2026-08-14 (user play-test) — landed this stretch

Traces `session_20260814_12*` plus the user's F9
`session_20260814_140402_*` / screenshot (one invader, dead controls, PACMAN
title-only) confirmed heap saturation on RTL and PYTHON `===` using deep
equality. Battery **PASS** after the fixes below. User F9 is the remaining
gate. No `.bit`/`.bin`.

### PYTHON — landed

1. **INVADERS — wrong alien eliminated.** Per-call env was already
   `call_fn` → `{"__par": fn.env}`. Extra hole: `===` on objects/arrays is
   now identity (`is`), not Python deep `==`, so `find(x => x === obj)`
   cannot match a different dict with the same fields. Generic tests in
   `tests/test_bytecode_js.py`.
2. **PACMAN — ghosts never leave the box.** `String.replace` accepts the
   compiler RegExp stub; `g` → all matches.

### FPGA-SIM — landed

3. **INVADERS — bullets pass through / all vanish after a shot.** `MAKE_FN`
   is a heap object with a **live env pointer**. `setTimeout` has its own
   8-slot queue (fire after rAF; `toovf` sticky). Heap no longer saturates
   on animate: uncaptured call envs recycle; per-frame object bump rewind
   of nursery slots (do not wrap live objects).
4. **LIST wrap paging.** `list_col` 0..63; wrap counts a page row, does not
   bump `list_disp`.
5. **PACMAN title-only / black after maze.** No live-slot wrap. JSON +
   replace in RTL. Live env so `nextStage`/`animate` share `_index`. Object
   nursery + env recycle. Offline: maze beans stay, `obj` stable ~3K, Left
   changes FB. Battery PACMAN.HTM pixels+key **OK**.
6. **DONKEY RUN wait.** GUI wait is size-scaled `TICKN` (byte cap), break on
   `running=1` / `?NH` / `?NB`.

---

## OPEN BUGS 2026-08-14 afternoon F9 — landed this stretch

User F9 after the morning stretch: FPGA-SIM INVADERS did not shoot; LIST
stopped ~230; PACMAN maze drew but arrows/ghosts failed; DONKEY RUN froze
ESC; LOAD lacked PYTHON's name+line count. PYTHON INVADERS still culled a
top-row alien (explosion at the hit); PYTHON PACMAN ghosts stayed in the
box (scared worked); LIST MORE stuck on fat HTML.

Inner loop = pytest of language/console/RTL **snippets** (not LOAD+RUN of
the three titles). Battery is smoke after those pass. User F9 remains the
play gate. No HTML rewrites, no title gates, no `.bit`/`.bin`. SOURCE stays
8K; 4 MB SRAM stays the ASET art bank.

### PYTHON — landed

1. **Wrong alien (`for (let i)` clobber).** Inside a call env, `for (let i)`
   was compiled as STORE_VAR and walked into the caller / forEach `i`.
   Callees now LET_VAR so `i++` stays in this frame. Test:
   `test_for_let_in_callee_does_not_clobber_foreach_i`.
2. **JSON stringify+replace+parse + mini-finder.** Nested number arrays
   round-trip; `Array(n).fill(0).map(() => Array(m).fill(0))` works. Generic
   tests in `tests/test_bytecode_js.py` — not a maze-`2` or `/2/g` special
   case. F9 ghosts-in-box may still be RTL pathing; pytest language path is
   green.
3. **LIST MORE abort.** `more_waiting` while `_await_list_more`; ESC aborts
   (Space/Enter page). `hard_break` must **not** clear the MORE abort (GUI
   `break_program` pushes ESC then `hard_break`). No `>` painted on wrapped
   LIST rows. Fat `data:image` LIST **is** the HTML; `.JSH` is never LIST
   source.

### FPGA-SIM — landed

4. **Nursery rewind ate `arr.push` objects.** `commit_obj_keep` raises
   `n_obj_keep` to **`oid+1`** (not `n_obj`) on push / SET_PROP / ARR_SET of
   a nursery obj/fn. Late `rAF(animate)` must not freeze the whole bump.
   Snippet: `test_rtl_push_object_survives_frame`.
5. **Raw KEYEVT.** Host no longer drops 32 / 37–40. KEYBITS-edge synthetic
   keydown only if the KEYEVT FIFO is empty. `e.key` for space is intern
   `" "` (U+0020). Snippet: `test_rtl_keyevt_space_keycode`.
6. **RUN/LOAD wait + ESC.** `type_line` pumps `run_wait_idle` between TICKN
   slices and aborts on `_break_run_wait` (`hard_break`). Fat HTML wait is
   size-scaled — do not shrink Donkey art.
7. **LOADED NAME (N LINES) + LIST from card.** HTML LOAD copies SOURCE up to
   8K then **drains FAT** counting all newlines. LIST restores `src_name`
   and streams the **card** HTML, never `.JSH`. Snippets:
   `test_rtl_load_html_line_count`, `test_rtl_list_after_run_is_source`.

**Still out of scope:** fillText glyph ROM, wall-color `#09f` vs `#9966CC`.
Do **not** claim shoot / ghosts-leave-box / look-play match from battery
PASS. User F9 PYTHON then F9 FPGA-SIM.

---

## OPEN BUGS 2026-08-14 F9 round 3 — landed this stretch

User F9 after the afternoon stretch: PYTHON INVADERS correct; PACMAN
steers on FPGA-SIM; leftover holes were language/console (DIR/LIST/LOAD,
8K SOURCE leftover, `e.key === " "`, finder BFS via `var f = function`).

Inner loop = pytest snippets (`test_bytecode_js`, `test_console_log`,
`test_rtl_snippets`). Battery is pixels+Left smoke. User F9 is the play
gate. No HTML rewrites, no title gates, no `.bit`/`.bin`. ASET SRAM stays
art from address 0.

### PYTHON — landed

1. **DIR names only.** No `1  INVADERS.HTML`. Catalog still hides `.JSB`/`.JSH`.
2. **Finder BFS.** `Object.assign` / stringify+`/2/g` / fill+map / objects in
   `steps` path out of a truthy-`2` cell after replace opens it. No maze-`2`
   special case. `var rec = function(){ rec() }` is CALL_VAL.
3. **EDIT insert cursor.** GUI Left/Right move an insert index when not
   running; Backspace deletes there.

### FPGA-SIM — landed

4. **128 KiB SOURCE BRAM.** Dedicated `source_mem`, not the 12 KB work map.
   LOAD copies HTML into SOURCE (INVADERS/PACMAN class). ASET SRAM still
   art from 0.
5. **Traces.** `NOTE GLASS` after DIR/LOAD/LIST/SAVE (letterbox). No FB?
   timing spam. PYTHON logs the reply of those verbs.
6. **LIST MORE.** `LINE` ticks until prompt or `-- MORE --`. Host does not
   paint `>` over MORE. Space pages; ESC aborts.
7. **LOAD wait.** Requires **this** stem + `LINES` (or `?IO`/`?LS`), not a
   stale `LOADED` still on glass. Remaining newlines counted per sector.
8. **DIR / SAVE.** Glass names match PYTHON (`.HTM`→`.HTML`; hide `.JSH`/
   `.JSB`). SAVE persists onto `card.img` so LOAD of the new name works.
9. **KEYEVT `e.key === " "`.** Intern hash 32 + len 1; event alloc then env
   on the next cycle (`S_KEYEV`) so the event object is not clobbered.
   Snippet: `test_rtl_keyevt_space_e_key_char`.
10. **Mini-finder on RTL.** Same BFS snippet as PYTHON. Nested `var f =
    function` compiles to LOAD_VAR+CALL_VAL (JSB stub 33 dropped the name).
    Array.fill/map/unshift already in the VM. Snippet:
    `test_rtl_finder_paths_out_of_house`.
11. **Nursery burst.** `commit_obj_keep` is oid+1 on nested stores too.
    Snippet: `test_rtl_push_survives_particle_burst`.

**Remaining debt:** fillText glyph ROM, wall-color `#09f` vs `#9966CC`.
Do **not** claim shoot / ghosts-leave-box / look-play match from battery
PASS. User F9 PYTHON then F9 FPGA-SIM.

---

Read first: `.cursor/rules/no-dukpy-cheat-native-cpu.mdc`,
`.cursor/rules/python-first-parity.mdc`, `.cursor/rules/never-fake-fpga-sim.mdc`,
[CONSTITUTION.md](../CONSTITUTION.md) MEMORY + vendored-titles,
[JMR_JS_COMPATIBILITY.md](JMR_JS_COMPATIBILITY.md).

**FPGA fit:** [FPGA_FIT.md](FPGA_FIT.md) numbers are the **last routed bit**
(2026-08-13 03:36): **33,639 LUT / 12,872 FF / 2 BRAM / 11,210 slices**.
Morning RTL (640×480 dual FB + card `.JSB` load) is **not** in that report —
refresh `utilization_impl.rpt` after the next WNS≥0 impl. Do not invent counts.

---

## HARD RULES for the next agent

1. **Never fake FPGA-SIM.** F9 FPGA-SIM = real Verilator RTL
   (`sim/sim_build_synth/jmr_js_sim_server`). Host twin only with
   `JMR_SIM_HOST=1`. Missing binary → fail loud. Rule:
   `.cursor/rules/never-fake-fpga-sim.mdc`.
2. **Vendored HTML titles MUST RUN.** `INVADERS.HTML` / `PACMAN.HTML` /
   `DONKEY.HTML` LOAD+RUN playable on PYTHON → FPGA-SIM → BOARD.
   `?NH` is temporary tracked debt — never "done." Constitution +
   `.cursor/rules/python-first-parity.mdc`. The **HTML decides the keys**
   (raw keycodes; game handlers bind them). No hardcoded WASD in RTL.
3. **Do NOT rebuild / flash** until **all three HTML games** are green on
   FPGA-SIM *and* the user has personally tested them in the GUI (F9) and
   approved. PYTHON is the control first. Flash only if **WNS ≥ 0**.
4. **Order:** PYTHON perfect → **FPGA-SIM perfect** (user GUI-checks) →
   Vivado bit → SRAM smoke → QSPI. Never `.bit`/`.bin` before that gate.
5. **J15 USB Host is hardware-dead on this T200** (PIC24 never enumerates).
   Play and type from the **GUI / PROG tether**. Build the key-state engine
   so when J15 is fixed, untethered play needs **zero** code changes.
6. When unsure, consult the working BASIC sibling
   `/home/jonathan/JMR-BASIC-FPGA-COMPUTER` (method + monitor + FAT + PS/2).
   Adapt for T200 + HDMI + JS/CSS — never copy A7 pinouts or BASIC ISA.

---

## Honest three-column status (2026-08-13)

| | **PYTHON** (bytecode VM + Pillow) | **FPGA-SIM** (Verilator RTL) | **BOARD** (last SRAM flash) |
|---|---|---|---|
| Monitor | DIR LOAD LIST EDIT CLS RUN HELP | same verbs | tether HELP/READY OK |
| Titles | compile-on-RUN bytecode (DAT spill **not landed**) | HTML RUN path; **not** full-game match yet | bit lags (`?NH` / old hex) |
| Legacy demos | optional `RECTDEMO` / `JOYDEMO` / same-stem `.JS` | `.JSB` on card if present | as flashed |
| Play keys | GUI arrows+Space → KEYBITS | KEYBITS → `joy_in` | GUI → PROG `0xFE`+bits → `joy_in` (J15 dead) |
| Glass | 640×480 letterbox + game FB | native **640×480** game FB | 03:36 bit: letterbox CDC fix; game was still 160×120×4 |
| Cursor blink | GUI cyan block ~2 Hz | HDMI `frame_div[5]` | HDMI blinks |
| Keyboard jack | n/a | PS/2 bench PASS | **J15 dead** |

**Last flashed bit:** `build/nexys_video/jmr_nexys_video.bit` **2026-08-13 03:36**,
**WNS +0.139 ns**, SRAM Done. Contains: dual-clock text VRAM (HDMI glyph CDC),
tether KEYBITS, ALU/MUL pipeline, `keyUp`/`keyDown`, INVADERS hex path.

**Tree ahead of silicon (HTML compile-on-RUN + asset bank):** code BRAM
**32K**, heap, JSB v2 trailer. HTML `RUN` **recompiles** current HTML → fresh
`STEM.JSH` (never overwrite `INVADERS.JSB`; never prefer a stale `.JSH`).
Full-quality `data:image` → `.JSH` ASET section → external SRAM asset bank
(no `NAME.DAT`; do not downscale
sheets into code BRAM). Battery 2026-08-14: INVADERS / PACMAN / DONKEY HTML
pixels+keys **PASS** on PYTHON and RTL. fillText is still a 64×8 rect (glyph
ROM missing). **No `.bit`/`.bin` / Vivado** until you F9-approve all three on
FPGA-SIM. Fit numbers will change (32K code + heap + dual 640×480 FB).

---

## T100 (BASIC, working) vs T200 (JS, this repo)

| | **T100 — BASIC** | **T200 — JS (this repo)** |
|---|---|---|
| Board | Nexys **A7-100T** | Nexys **Video** (200T) |
| Video | VGA | **HDMI** 640×480 — **do not switch this board to VGA** for bad text |
| USB Host jack | **J5** (works) | **J15** (**dead** on this unit) |
| PIC24 role | USB HID → PS/2 Set-2 to FPGA | Same idea; this PIC24 never enumerates |
| FPGA PS/2 pins | `ps2_clk=F4`, `ps2_data=B2` | `ps2_clk=W17`, `ps2_data=N13` (XDC) |
| Proof | Type BASIC at READY | HDMI + PROG tether; **no standalone typing** |
| Host glass | GUI + UART/KEY merge | GUI + FT245 tether (channel **A** / `.0`) + KEYBITS |

### Keyboard / play (board)

- **J15 verdict 2026-08-13:** PIC24 enumerates no USB device. Use **F9 BOARD**
  and the **PC keyboard** (tether). Digilent ticket body is in git history /
  earlier handoff revisions — forum:
  https://forum.digilent.com/forum/4-fpga/
- **HDMI back-feeds 5 V** — unplug HDMI before any J15 power-cycle test.
- **JP4 = boot source only** (not a keyboard enable).
- LEDs (JS console bit): LD7=`ps2_strobe`, LD6=`ps2_clk`, LD5=`ps2_data`, LD4=`~sd_cd`,
  LD3=MMCM, LD2=READY, LD1=game_mode, LD0=alive.
- **Pmod JA+JB in JS top 2026-08-14.** Same wiring as the LED test. FPGA-SIM
  unchanged. Next JS bit flash: type on JA, play on JB.

---

## Games on disk (one HTML title each)

| Game | Source (LOAD) | Compile output (invisible) | Card 8.3 |
|---|---|---|---|
| Space Invaders | `INVADERS.HTML` | fresh `.JSH` (code + ASET art) | `.HTM` |
| Pac-Man | `PACMAN.HTML` | fresh `.JSH` (code + ASET art) | `.HTM` |
| Donkey Kong | `DONKEY.HTML` | fresh `.JSH` (code + **full-res** ASET art) | `.HTM` |

**Product rule:** real HTML/JS native CPU (FPGA → ASIC). Same `.HTML` in
Chrome (authoring) and on PYTHON/FPGA-SIM/BOARD via **compile-on-RUN
bytecode** — **not dukpy**, **not a stale `.JSH`**. Great graphics stay:
full-quality `data:image` art rides the `.JSH` ASET section into the
external SRAM asset bank (no `NAME.DAT`). EDIT HTML then RUN regenerates
everything. Same-stem `.JS`/`.JSB` are
legacy demos, not twins. Demos: `RECTDEMO` / `JOYDEMO` / `CLIMB`.
`storage/games_*` = upstream only.

HTML titles target **640×480** (PACMAN tile size 14; DONKEY world via
`setTransform`).

```text
# All runtimes (honest path)
LOAD "PACMAN.HTML"   # or DONKEY.HTML / INVADERS.HTML — edit this
RUN                  # ALWAYS compile current HTML → fresh .JSH
                     # (code → code BRAM, ASET art → external SRAM bank)
```

**Compile-on-RUN:** source of truth = loaded HTML (editor line numbers).
`.JSH` is invisible output only — never prefer an old sidecar; stale `.JSH`
may be deleted. **Asset bank:** Donkey-class sheets go full-res into the
ASET section / external SRAM, never packed into code BRAM or downscaled.

Gap list: [JMR_JS_COMPATIBILITY.md](JMR_JS_COMPATIBILITY.md).
Rule: `.cursor/rules/no-dukpy-cheat-native-cpu.mdc`.

### Constitution mandate (2026-08-13)

`INVADERS.HTML` / `PACMAN.HTML` / `DONKEY.HTML` **MUST RUN** on PYTHON
**bytecode** → FPGA-SIM RTL → BOARD (then ASIC). `?NH` = temporary debt,
not done. HTML decides keys. **No dukpy product path. No `.bit`/`.bin` until
all three are green on FPGA-SIM and the user GUI-tests.**

### Compiler v2 progress (PYTHON — 2026-08-13)

Landed in `functional_model/compiler.py` + `bytecode.py` + `machine.py` +
`input_engine.py`:

- Language: `for`/`for-of`/`switch`/`break`, `&&`/`||`/ternary/`?.`, real `%`,
  `+=`/`++`, `function`/`return`/arrows/`MAKE_FN`/`CALL_VAL` (IIFE), classes +
  getters + class fields, `new` (incl. `var F=function` ctors), arrays/objects,
  `typeof`, regex stubs, trailing commas, `$` ids, multi-`var`, `.35` floats.
- VM: shared `_exec` for `run`/`call_fn`, `forEach`/`reduce`, Image onload,
  canvas swap each HTML frame, `drawImage`→fillRect stub, key-state engine
  (PS/2 Set-2 → keyCode + tether KEYBITS OR).
- **`INVADERS.HTML` / `DONKEY.HTML` / `PACMAN.HTML` PLAY on PYTHON
  compile-on-RUN bytecode** (not dukpy, not a stale `.JSH`). `RUN` always
  recompiles the loaded HTML and writes a fresh internal `.JSH`.
- FPGA-SIM: host compile-on-RUN patches card `.JSH` + `SDRELOAD`, then RTL
  FAT-loads that fresh file (`?NH` if missing — never Invaders hex).
- Simple `.JS` titles still RUN. No `.bit`/`.bin` until F9 FPGA-SIM approval.

### Grow the VM to the HTML (do not shrink the games)

INVADERS bytecode path is playable; keep bindings on `event.key`
(a/d/arrows/space). DONKEY/PACMAN still need more FM/RTL coverage
(prototype `Foo.prototype.x=`, full `drawImage` sheets via the **external
SRAM asset bank**,
path APIs, maze). **Do not edit the three HTML titles down** so they “fit”
a weak VM — grow compiler + VM + asset bank instead.

**Inventory:** INVADERS = first end-to-end (fillRect aliens + PNG ship).
DONKEY = sprite sheets / setTransform (full-res ASET). PACMAN = maze +
prototypes.

---

## Battery (must stay green)

```bash
make -C sim sim_server_synth
make -C sim tb_ps2_typing
.venv/bin/python tools/make_sd_image.py create sim/card.img
.venv/bin/python tools/check_runtime_parity.py   # BATTERY PASS (bytecode / no dukpy cheat)
```

Vivado (**FORBIDDEN until all three HTML games are green on FPGA-SIM and the
user has personally tested them in the GUI**). Only publish if WNS ≥ 0:

```bash
source scripts/vivado_env.sh
make -C tools/board_flow bit
make -C tools/board_flow flash    # SRAM first; QSPI later
```

---

## FPGA-SIM proven (not host twin)

- 64×16 letterbox, origin (64,112); one prompt (strip trailing blanks / bare `>`)
- LIST / MORE / EDIT / CLS; FIFO depth 128; LIST HTML from card (never `.JSH`);
  LOAD prints `LOADED NAME (N LINES)`; SOURCE prefix stays 8K
- Product path: `LOAD "*.HTML"` / `RUN` → **compile-on-RUN** → fresh bytecode
  into code BRAM (never prefer stale `.JSH`; never Invaders hex)
- Native **640×480** game FB; tether dump may subsample
- KEYBITS → `joy_in`; GUI mouse stick **OFF**
- PS/2 bench OK; board J15 still dead → PROG tether

## PYTHON proven

- Same monitor verbs; `_keep_fb` after RUN
- Titles: HTML via **compile-on-RUN bytecode** (default). dukpy only `JMR_HTML_DUKPY=1`.
- **Not done:** Chrome-identical full games; external SRAM asset bank (ASET) landing
- GUI letterbox **cyan cursor blink**

## Board proven (update when re-flashed)

- See last flash note above; claim only what that bit actually runs
- HTML on matching bit = compile-on-RUN / fresh `.JSH` VM; tether KEYBITS until J15 fixed

## One glass (FEATURE, not a bug)

READY/monitor = 64×16 letterbox. RUN = full-field game FB. Same 640×480 HDMI
and GUI mirror.

Torn HDMI **glyphs** were clock-domain: VRAM write @ core_clk, async read from
pixel_clk. Fixed like BASIC (`scan_clk=pixel_clk` + aligned scanout).

---

## `(NO VM)` / `?NB` / `?NH`

- Old `(NO VM)` = no bytecode VM (RECTDEMO engine only)
- `?NB` = no companion `.JSB` on the card
- `?NH` = HTML not executable on the RTL VM yet

---

## Next agent priority

1. Land the **external SRAM asset bank** (ASET section; stop packing /
   downscaling Donkey into code BRAM — `NAME.DAT` design is retired).
2. Grow compiler + bytecode VM + natives until all three HTML titles are
   **full games** on PYTHON, then the **same** on FPGA-SIM RTL — look and
   play match. Never dukpy, never host twin, never stale `.JSH`.
3. Keep `tools/check_runtime_parity.py` **BATTERY PASS** after RTL edits.
4. **No board / Vivado / `.bit`** until the user F9-approves PYTHON + FPGA-SIM.
5. Do **not** treat J15 as an RTL bug. Tether until hardware/RMA.
6. Never call `JMR_SIM_HOST=1` “FPGA-SIM.”

## Key files

| Area | Path |
|---|---|
| SIM server | `sim/sim_main.cpp`, `runtime/sim_backend.py` |
| Board tether | `runtime/board_backend.py`, `rtl/engines/jmr_uart_link.sv` |
| Glass | `functional_model/canvas_engine.py`, `rtl/video/jmr_text_hdmi_scanout.sv` |
| VRAM CDC | `rtl/engines/jmr_video_vram.sv` (`scan_clk`) |
| VM | `rtl/engines/jmr_js_vm.sv`, `functional_model/jsb_format.py` |
| Console / JSB load | `rtl/engines/jmr_console_engine.sv` |
| Battery | `tools/check_runtime_parity.py` |
| BASIC reference | `/home/jonathan/JMR-BASIC-FPGA-COMPUTER` (read-only) |
