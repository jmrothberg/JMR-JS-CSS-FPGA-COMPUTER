# Potential bugs

Words: [README.md — Words used](../README.md#words-used-in-this-project).
**FPGA-SIM** = the chip simulated. **RTL** = `rtl/*.sv`. **rAF** =
`requestAnimationFrame`. **GC** = Garbage Collection.

This file is **copy 2** of “one heap / generation / dual-copy skew”
(copy 1: `.cursor/rules/one-heap-keep-gen.mdc`). Read
[Recurring classes](#recurring-bug-classes) before chasing a title name.

**F9 play (2026-08-22):** INVADERS / PACMAN / DONKEY / ASTEROID / MRDO
work on FPGA-SIM. **BOARD PACMAN #84:** chase is one-step (2026-08-26);
eyes home is in-place `_ghostHome` (2026-08-27) — not `finder`. This is
**not** a “games are broken” list.

**How to read:** start at **Open now**. **Fixed** is a catalog (what it
was, what caused it, how it was closed). Session essays live in
`git log -- "docs/potential bugs.md"`. Caps:
[FPGA_FIT.md](FPGA_FIT.md). Speed:
[SYNTH_SLOWDOWN_LEDGER.md](SYNTH_SLOWDOWN_LEDGER.md).

---

## Open now

Nothing here blocks the five titles on F9. Left:

### Glass / console (you can see these)

**V1.0 editor is view-only.** The chip has **no compiler**. `RUN` loads the
card-minted `.JSH`. Changing the numbered buffer (`EDIT n`, `10 body`,
`INSERT`/`DELETE`, `SAVE` of that buffer) cannot change what plays. Use
`LIST` / `DIR` / `LOAD` to **learn**. Author on the PC, remake `card.img`.
**Edit + play** waits on **V1.5 compile-on-RUN**. Do not treat #42 / #43
as V1.0 silicon holes.

| ID | Status | What | How to close |
|---|---|---|---|
| **#82** | **OPEN** (cause known 2026-08-26) | `LIST` / `DIR` print `-- MORE --` when the listing is already done. Content that lands on an exact multiple of 14 glass rows (`BOXES.HTML` = 42 = 3×14) eats the next keystrokes as page-advances (`?SN` / bare READY). The prompt **does** draw; the old “MORE invisible” theory was wrong. | Before paging, test end-of-content: LIST `src_i >= src_len \|\| list_disp > list_hi`; DIR when the catalog is drained. Sites: `C_DIR_NL`, `C_LIST_NL`, `C_LIST_WRAP_PAGE` (`list_on_page >= 13`). |
| **#42** | V1.5 (not V1.0) | READY `INSERT n` — PYTHON edits; RTL `?SN`. Useless until compile-on-RUN. | V1.5 insert is an unused number (`15` between `10`/`20`). Do **not** add an `INSERT` verb. |
| **#43** | V1.5 (not V1.0) | READY `DELETE n` — PYTHON editor-delete; RTL `REMOVE` is **file** delete. Useless until compile-on-RUN. | V1.5 delete is `10` + Enter. Keep `REMOVE "NAME"` for the card. |

### Tests only (not F9)

| ID | Status | What |
|---|---|---|
| **#70** | OPEN xfail | rAF/timer queue **hash** RTL vs hardware model. Frames/heap already match. |
| **#71** | OPEN xfail | Call-overflow fault: HM `sp=1`, RTL `sp=0`. Clean halt is synced; fault path is not. |
| **#72** | OPEN xfail | `new P()` on a class from an IIFE GC-storms `S_V64_CTOR_PAD` (~950 objects). Inefficiency + flake, not a title. |
| **#83 leftover** | xfail | Constructorless-class case still xfail’d next to the method-scan fix. |

### Speed / cost (correct paint, too many clocks)

Not hangs. Numbers:
[SYNTH_SLOWDOWN_LEDGER.md](SYNTH_SLOWDOWN_LEDGER.md).

| ID | What | Do not |
|---|---|---|
| **#1 / #2 / G8** | Intern FIND is a linear walk (2 clk/slot). `"SCORE "+n` misses last-4. Hash+length match without **byte** confirm can collide. | Expect FIND alone to stop a 64M frame cap. A miss is ≤2k clocks, not 8M. |
| **#3** | Intern table never GC’d. Cap 1024 → undefined HUD strings (wrong paint, not halt). | Treat as a freeze. |
| **G1 / G10** | 1 pixel/clock raster. Full 640×480 ≈ **307k** clocks (PACMAN often ×2). INVADERS `drawBitmap` is many tiny `fillRect`s. | Chase an infinite FSM; it **finishes**. |
| **#24 / #35** | Extra Port A settle beats (`.length`, RECT_LD first beat). | Combo-peek `*_rdata` (hang / 70 GB synth). |

### ISA stubs / caps (no current title dies)

Loud miss or PYTHON-matching no-op. Grow only if a title needs it.

| ID | What |
|---|---|
| **#16** | Key FIFO depth 8 — drop on full. |
| **#17** | `addEventListener` 16 total / 4 per type → **fault 3**. Drop + overflow flag would be kinder. |
| **#21** | `JSON_CAP` overflow → fault 3. Keep loud. |
| **#23** | `Date.toISOString` — PYTHON stub; RTL LOOKFN-miss. INVADERS save path. |
| **#26** | `drawImage` **miss** paints nothing (`dbg_di_miss`). Hit path is fixed (#51). |
| **#30** | FRAME_TIMER can push a timer fn without gen/valid check. |
| **#33 / #34** | `globalAlpha` not latched on RTL. PYTHON also does **not** blend (only skips `fillRect` at alpha 0). |
| **#45 / #36 leftover** | `ctx.font` size: glyphs stay 8×8 on Value64. `measureText` length is full u16; scale still missing. |
| **#32** | Unknown runtime `fillStyle` → white. No current title builds a color string at runtime. |
| **#4** | `join` of non-digits. Titles do not hit it. |
| **#9** | `vraf_n >= 8` → fault 3. |
| **#11** | CALL_VAL second stack-window miss → fault 4. |
| **#20 / G9** | `getImageData` of an unpainted FB can cache black. |

### Not bugs (do not re-file)

| Item | Why |
|---|---|
| **#27** | DONKEY title / character-select has **no rAF** until `gameState=="game"`. Two Enters is correct JS. |
| **#48** | `push` past `ARR_CAP=128` faults in PYTHON **and** RTL. Product cap. |
| **#79** | Headless PACMAN attract once exploded the pathfinder (`ARR_CAP` / env). F9 2026-08-22 live play looked fine (`fault=0`). **BOARD 2026-08-26** still died on the same recursive `finder` — **#84**. Lesson: do not shrink `ENV_DEPTH` to 256; do not recurse BFS on a tick. |
| **#80** | Heap metadata LUTRAM writes land **+1 beat**. Current readers wait `*_rdata`. New same-slot write/read next beat needs a bypass or an extra settle. |
| INVADERS bunker “holes” | Alien bombs. PYTHON RNG ≠ RTL LFSR. |
| **#46 / #50** | Retracted — see [Retracted](#retracted-theories-do-not-re-derive-these). |

---

## SOLVED 2026-08-28: the recurring "blurred sprite" was art/RAM oversubscription

The MKPVP red-player blur (chased and "fixed" repeatedly across runs;
back on 51/53, absent on 52) was never RTL. **MKPVP sheet 2 (2036x850)
occupies SRAM bytes 2,091,728..3,822,328 — straight through FRONT
(2,961,408..3,268,608), WORK, SPR, SRC and IMGD.** Every present writes
the framebuffer through the middle of the red player's art; a direction
flip switches to sheet 1 (below FRONT) and is instantly sharp. Run 52
was "clean" only because it deleted the present (no front writes).
Every historical fix that moved regions changed WHICH art died.

**MKPVP oversubscribes the 4 MB asset SRAM by 860,920 bytes** — the art
ceiling with the current map is byte 2,961,408. No RTL change can fix
capacity. Fixes (HTML/tools side): mint-time LOUD refuse when art top >
art ceiling (the documented compile check did not fire — third silent
over-capacity mint after PACFAST and the extended-PACMAN test image),
and shrink sheet 2 (mirror-at-author-time if both facings are stored).
Until then, the red player blurs on every present-carrying build — that
is expected, not a regression.

## Recurring bug classes

<a id="recurring-bug-classes--read-this-before-debugging-anything"></a>

Five patterns produced almost every ID in this file. If glass is wrong,
ask which class it is first.

**parent** = `jmr_js_vm.sv` (heap, paint, events). **exec** =
`jmr_js_vm_exec64.sv` (the only decoder since 2026-08-21). They talk
through `hs_*`. **Port A** = address this clock, data next clock.

### 1. One heap / generation / parent–exec dual-copy

There is **one** JS heap. A handle is `(generation, index)`. If gen does
not match, that object was recycled — report it. Do not skip the check so
a private copy “still looks alive.” Do not give exec its own `vvars` /
`venv_*` / `vobj_*` / `stack` / `name_mem` while the parent still has the
real tables (will not fit leftover BRAM; goes stale: black PACMAN, stuck
rAF, “four title bugs”).

```systemverilog
// BAD
if (vobj_alloc[i] == 2'd1) mark = 1;
// GOOD
if (vobj_alloc[i] == 2'd1 && vobj_gen[i] == handle[43:32]) mark = 1;
```

exec64 owns registers; the parent mirrors them through `hs_*`. Anything
that reads a parent FF **outside** the `hs64` mux is stale.

*Tells:* right inside the opcode, wrong one state later; checkpoint hash
differs while the heap matches.
*Examples:* **#77** listener tables (exec compacted, parent walked the
old list); **#69** rAF snapshot vs listener scan sharing `bind_k`.
*Fix shape:* one table; seed from `e64_*_q` at use; poke the parent FF
**and** its mask.

### 2. Registered raddr → registered rdata: two beats, not one

Port A: address this clock, data **next** clock. Gating the address mux
on a flag set with `<=` adds a third beat of lag.

*Tells:* every element of a walk is the same wrong value, or one row behind.
*Examples:* `join` interned `"1100"` as `"0000"`; **#58** WIN_FILL.
*Fix shape:* consume `*_rdata` when the arm is already high, or add a
settle beat. Never combo-index BRAM.

### 3. Exec-entered parent state with no first-entry guard (and last-exit)

When exec sets `state_n` to a parent state, seeds may live only in exec
FFs. Walks start on garbage, or the parent jumps back to `S_V64_EXEC`
with stale `code_rdata` / stack window (**#78** bunkers).

*Fix shape:* first-entry copy from `e64_*_q`; leave through
`hs_ip` + `hs_code` + `S_FETCH_WAIT`, never a direct jump to EXEC.

### 4. Shared scratch registers with no owner

`bind_k`, `*_rd_arm`, `jn_slot_arm`, … are reused. An interrupt of a
multi-beat walk destroys its cursor (**#69** killed rAF by finishing a
keyup listener instead of the snapshot).

*Fix shape:* each walk resets its own cursor on first entry; a mid-frame
dispatch resets what it clobbered.

### 5. A test/harness artifact that looks like an RTL bug

Stale intern table from a reused sim; `DIR` full of probe files;
sampling mid-frame where `raf=0` is correct; suite vs live play.

*Rule:* reproduce in a **fresh sim with a fresh card** (`JMR_CARD_IMG`
scratch). Caps live in five places: parent, pkg, HM, `jsb_format`,
`sim_main.cpp` — keep them twins (**#75**).

### Retracted theories (do not re-derive these)

| Idea | Why it was wrong |
|---|---|
| **#46** “one timer per frame” | `bind_k` is zeroed on every callback dispatch. The scan restarts; all due timers drain. |
| **#50** compiler slot aliasing | Locals are **name-keyed**. `a1` is only a scan hint (**#55** later made the hint verified). |
| Skip gen-match to hide dual-copy | Forbidden. Hides class 1; corrupts handles across GC. |
| Extract JOIN/JSON/GC/HEAP into modules that own arrays | That is a second heap. |

---

## Fixed — what it was, cause, how

Play / silicon (F9). Oldest IDs first. “How” is the actual close, not the
first theory.

| ID | Was | Cause | How |
|---|---|---|---|
| **5** | rAF callback ip 0 | oid 0 → cbip 0 | Parent marker `dbg_cb_ip <= 1`. |
| **6** | PACMAN `forEach` died | implicit RET `0xfffc` → GC before FOREACH continue | Guarded continue-walk arm ahead of GC_CLEAR. |
| **10** | tagged `restore()` collapse | exec32 `saved_*` had no reset | Reset `saved_*`. exec32 later **deleted**. |
| **14** | wasted `.now` ALLOC | GET_PROP `.now` allocated a native | Arm removed; `Date.now()` is CALL_METH. |
| **15** | tagged WASD keys | `w`/`s`/`p` missing from key-type list | Added 87/83/80. Value64 already interned them. |
| **18** | live objects recycled | nursery rewind `n_obj_keep` | Mark/sweep. Never skip gen. |
| **19** | array id alias 1024→0 | 10-bit aid decode | `{aid[10:0], slot}`. |
| **22** | `replace` FIND restart | missed Port A wait | Extra beat kept. |
| **25** | HEAP miss hung | miss restarted `cls_scan` | Miss → undefined + FETCH. |
| **31** | FRAME cut the callback | present-exit during EXEC/GC | Host waits `S_WAIT_FRAME`. |
| **36** | `measureText` trunc | `name_blen[7:0]` | Full u16. Font **scale** still #45. |
| **37** | `textBaseline` | neither model had it | Latch + `txt_y0` (2026-08-20). |
| **38** | `quadraticCurveTo` no-op | no exec64 arm | `id_quadcurve` → path op 2. |
| **39–41** | `reduce` / `slice` / `sort` | no exec64 arms | Parent walks (2026-08-20). |
| **47** | nested forEach GC | parent nest stack never written | Mirror exec push into parent on FOREACH entry. |
| **49** | paths painted nothing | parent `pc_*` had no writer | exec `pc_we` → parent; PWALK first-entry latch. |
| **51** | `drawImage` hit = 0 px | `S_BLIT` never latched exec scalars | First-entry latch from `e64_*_q`. |
| **52** | `new` + prototype methods invisible | NEW_OBJ class hit did not link proto | Link proto on class hit. |
| **53** | `push` / `a[i]=` garbage | HEAP_AWR no first-entry | Latch + Port A. |
| **54** | JSON / ImageData | more unguarded entries | Same first-entry class. |
| **55** | wrong local | env hint skipped prefix | Scan from 0; later verified hint. |
| **56** | `join` undefined | exec `vst_we` freeze | Register the write enable. |
| **57** | arrays >32 halt | promote return ignored under Value64 | `vprom_ret_eff` from exec. |
| **58** | PACMAN / promote corrupt | WIN_FILL / stack window | Port A settle + promote copy. |
| **61** | PACMAN killer | post-GC alloc clobbered a **live** slot | Alloc only free/recycled with gen. |
| **62** | DONKEY Space fault | class-method alloc stale kind | Kind from exec on first entry. |
| **63–67** | titles halted / keys / BIND / timers / SET_PROP | empty RET, n=0 key objects, stale vcsp, two `vtimer_n`, SET_PROP aimed at VALUE | Closed 2026-08-20 morning. |
| **68** | second `filter`/`map` | `S_FREE_ARR` no first-entry / not in hs64 | Guard + handshake. |
| **66b** | `setTimeout` pile-up | slot scan vs `vtimer_n` | Compare vs allocated slots. |
| **60** | listeners added mid-dispatch ran now | walk saw new entries | Snapshot / skip new. |
| **69** | rAF died after a key | FRAME left snapshot half-done; dispatch reused `bind_k` | Reset snapshot cursor; class 4. |
| **73** | PACMAN froze after splash | `imgd_pend` cleared every beat (strobe leftover) | Handshake flag stays until `sram_ack`. |
| **74** | DONKEY Mario→Luigi | KEYBITS edge with no KEYEVT twin | KEYEVT enqueue clears edges. |
| **75** | `obj=772` on a 768 heap | `sim_main` caps lagged RTL | Sync the fifth cap copy. |
| **76** | bunker cell / silent READY | slice-width writes OOB after cap shrink | Physical depth = 2^slice; logical cap smaller. |
| **77** | DONKEY still flipped char | `removeEventListener` compacted **exec** only | Parent compacts its table on the repl beat. |
| **78** | INVADERS bunker hole at cells[32] | promote resumed EXEC on stale window | Resume via `S_FETCH_WAIT`. |
| **81** | `for (var i…)` in a method-called fn looped forever | compiler emitted STORE_VAR (caller’s binding) | Emit LET_VAR; note for-init locals. FM==RTL were both wrong. |
| **83** | DONKEY platforms, **no characters** | class-method scan re-issued one index; last method of 3+ never found | Issue the read one entry ahead. PYTHON dict never saw it. |
| **84** | PACMAN HDMI freeze; then eyes never home | `finder` cloned 31×28 + objects every ghost cell (`MAX_OBJ` 960, ~676 live). Empty `finder` stopped the freeze; greedy `_ghostStep` could not go around the house wall. | Chase = `_ghostStep`. Eyes = in-place `_ghostHome` (no clone). Do not restore `finder`. |

MRDO “stuck splash” was KEYEVT down+up in one Verilator frame — **sim_main**
defers same-window keyup (real HDMI is real-time). DONKEY Luigi→splash was
stale back-buffer after swap — **S_FB_SYNC** copies front→back.

---

## Slow vs hang

Extra `*_rdata` beats and 1 px/clock fills are **slow**, not leftover
junk. Combo-peek, `mem[i] <=` in the big FSM, skip-gen, and a second heap
are illegal. FRAME cap is a **host timeout**, not a speed knob.

Live caps (bisect-proven; do not restore 1024/512): `MAX_OBJ=960`,
`ENV_DEPTH=384`, `MAX_ARR_LONG=12`, `CODE_WORDS=20480`.

---

## Monitor (READY)

Same verbs on PYTHON and FPGA-SIM. FPGA-SIM debug RPCs are not console
verbs. **in** = the verb exists, not “every title is proven.”

**V1.0 product:** `DIR` / `LOAD` / `LIST` / `RUN` / `ESC` (and `CLS` /
`HELP` / `MEM` / `REMOVE`). `LIST` is to **read**. Edit verbs below do
not make a title until **V1.5 compile-on-RUN**.

| Command | PYTHON | FPGA-SIM / board RTL | V1.0? | Open |
|---|---|---|---|---|
| `DIR` | in | in (`C_DIR*`) | view | **#82** extra MORE |
| `LOAD "NAME.HTML"` | in (FAT `card.img`) | in (`C_LD_*`) | view | — |
| `RUN` | minted `.JSH` from `card.img` | same `.JSH`. No on-chip compiler. `?NH` / `?NB` | play | V1.5 compile-on-RUN |
| `LIST` / MORE | in | in | **view / learn** | **#82** |
| `EDIT n` | in | in | **no** — buffer change, `RUN` still `.JSH` | V1.5 |
| `INSERT n` | in | **NOT** (`?SN`) | **no** | **#42** V1.5 (no verb) |
| `DELETE n` | editor | **NOT** (file `REMOVE` only) | **no** | **#43** V1.5 (no verb) |
| `REMOVE "NAME"` | file alias | in | card file | — |
| `SAVE` / `NEW` | in | in | **no** as authoring (`RUN` still `.JSH`) | V1.5 |
| `CLS` / `HELP` / `MEM` / `ESC` | in | in | yes | HELP omits INSERT/DELETE |

Host builtins, language methods, and Canvas **Complete** rows:
[JMR_JS_COMPATIBILITY.md](JMR_JS_COMPATIBILITY.md). Do not use the old
2026-08-19 snapshot in git as current silicon status.

## Compatibility command map (inspection only) — superseded

The old per-API table here mixed **open** with rows that later landed
(#49 paths, #51 blit, #37 baseline, #39–41 arrays). Current map:
[JMR_JS_COMPATIBILITY.md](JMR_JS_COMPATIBILITY.md). Holes that are still
real: [Open now](#open-now). Monitor verbs: [above](#monitor-ready).


---

## Short case notes (class 1 / 5)

**#77 / #78 together:** DONKEY char-flip and INVADERS bunker hole both
looked like title bugs. Both were class 1 — two listener tables, then a
promote that skipped `S_FETCH_WAIT`. Verify with the user’s actual
in-game key, not an idle probe.

**#83:** PYTHON dict vs RTL table scan. Parity cannot catch a
scan-index fault. `dihit=0 dimiss=0` with `spr=6` meant dispatch never
ran, not a blit miss.

**#79 suite reds** (`enter_paints_maze`, `keeps_raf`) were **bad tests**
(sub-pixel DONKEY; mid-frame `raf=0` sample), not the chip.

Full dated write-ups: `git log -p -- "docs/potential bugs.md"`.
