# RTL reorganization — maintain and find bugs

## JUDGMENT (2026-08-21, written after a full debugging cycle)

**Do NOT do the file-move reorg. Not now, and probably not ever.**

This recommendation comes from actually working the code: one session that
fixed ~15 real RTL bugs (#69 rAF snapshot clobber, dispatchEvent, findIndex,
join, ctx.font, drawImage scaling, replace, indexOf, halt-sync, KEYBITS,
the DONKEY phantom arrow, …) plus the exec32 cut and the Port A pass. In
all of that, **not one bug took longer because two files were big.** Every
expensive bug came from one of four things, none of which a directory
layout touches:

| What actually cost hours | Example from this session |
|---|---|
| **Shared scratch registers with no owner** | `bind_k` is used by the rAF snapshot loop, the FRAME_KEY listener scan, FRAME_TIMER, and the ctor pad. An event dispatch clobbered a half-finished rAF snapshot's cursor → the walk "called the rAF callback" but ran the keyup **listener**, and the game loop died (**#69**). Nothing in the file says who owns `bind_k`. |
| **Registered-raddr → registered-rdata lag consumed a beat early** | `join` gated its name-hash raddr on `jn_name_arm`, which reads 0 during its own set beat → every string digit read one row stale and `"1100"` interned as `"0000"`. Same class: #58, `replace`'s replacement char, `S_IMGD`. |
| **Parent/exec dual copies** | Parent FFs vs `e64_*_q`: the halt path hashed a stale `vsp`/`vcsp`/`vthis`/`venv`; `vkey_ln` latched the parent's stale listener count; S_FONTPX/S_SQRT needed first-entry seeds because the values only ever lived in exec FFs. |
| **A state entered from exec with no first-entry guard** | S_SQRT (splash hang), and every new state I added needed the same guard by construction. |

A file move fixes **none** of those and risks all of them. It also burns
the one thing this codebase has going for it: the current tree is
**verified** — five titles, a green suite, and a netlist that is currently
surviving synthesis. Trading that for tidiness is a bad trade.

**Do these instead** (each is small, testable, and attacks a measured bug
class): the [Maintenance backlog](#maintenance-backlog-do-these-instead)
below. The single highest-value item is the **scratch-register ownership
table**, because that is the #69 class and it is pure documentation +
assertions, zero silicon risk.

**When a reorg WOULD be justified:** if `jmr_js_vm.sv` grows past ~20k
lines, or if a second product decoder is ever genuinely needed (it is not
— see [REMOVING_EXEC32.md](REMOVING_EXEC32.md)), or if Vivado elaboration
memory becomes the binding constraint again *and* a hierarchy boundary is
proven to reduce it. None of those is true today.

---

**Plan only.** Written 2026-08-20; refreshed 2026-08-21. **No RTL was
moved or edited for this document.** Do not start a file-move or enum-unify
pass in the same job as glass, FIND, Port A, or `make bit`.

**Superseded since it was written:** its Phase 1 (cut exec32) is **done** —
the file is deleted and the line counts below have changed accordingly
(parent 14.5k, exec64 7.5k, ~22k for the two, ~29.4k all `rtl/*.sv`).
What remains valid is everything about *how to navigate* the two big
files: the state/handshake/`*_rdata` discipline, the leftover-file labels,
and the "do not extract JOIN/JSON/GC/HEAP" law.

FPGA-SIM **is** the synthesis RTL (`never-fake-fpga-sim`). The goal of a
reorg is: an agent (or human) can land on the right clock, the right SRAM
port, and the right handshake without cloning the heap or inventing a second
VM. Architecture stays [ARCHITECTURE.md](ARCHITECTURE.md). Fit/synth law
stays [FPGA_FIT.md](FPGA_FIT.md) and `.cursor/rules/never-fake-fpga-sim.mdc`.

---

## Why this is hard today

The folder split (`rtl/engines/`, `rtl/video/`, `rtl/phys/`) is already
right. The pain is **three files** that are the chip:

| File | Lines (2026-08-21) | Role |
|---|---:|---|
| `rtl/engines/jmr_js_vm.sv` | 14,479 | Parent: one JS heap, Port A SRAMs, `case (casestate)` |
| `rtl/engines/jmr_js_vm_exec64.sv` | 7,544 | Value64 opcode/native decoder — **the only decoder** |
| ~~`rtl/engines/jmr_js_vm_exec32.sv`~~ | — | **deleted 2026-08-21** (was 5,179 lines of tagged Q16) |
| **Those two** | **~22.0k** | **~75% of all `rtl/*.sv`** |
| Rest of `rtl/` | ~7.4k | Console, storage, video, PHY, tops — already modules |

Bugs are found by **state + handshake + `*_rdata` lag**, not by “which
directory.” Splitting JOIN / JSON / GC / HEAP into new modules was already
tried as an idea and **must not happen** — that is a second heap
(`one-heap-keep-gen`, [VIVADO_FLATTEN_HUNT.md](VIVADO_FLATTEN_HUNT.md)).

The useful reorg is: **one source of truth for numbers**, **searchable
sections inside the parent**, **unhook dead decoder**, **label leftover
files**. Not a new architecture.

---

## Silicon law (do not “organize” past these)

These are not style. They are why previous “clean” splits blew synth or
skewed glass.

1. **One JS heap in the parent.** Exec may **address** SRAM this clock and
   consume `*_rdata` next. It must not own `vvars` / `venv_*` / `vobj_*` /
   `name_mem` / `vstack` / `json_mem` copies.
2. **Do not extract JOIN / JSON / GC / HEAP** into new modules. Extra
   clocks inside the parent are fine.
3. **Big arrays: Port A only.** FSM pulses `stack_wr` / `vobj_alloc_wr` /
   `varr_len_wr` / `vvars_wr` / `json_putc` / `imgd_we`. Never
   `mem[i] <=` in the 7k-line `always_ff`. Recipe: [FPGA_FIT.md](FPGA_FIT.md).
4. **`st_t` is append-only.** New states go at the **end**. `sim/sim_main.cpp`
   `vm_sname[]` and debug RPCs index by **number**. `S_FB_SYNC` must stay last
   in the parent enum (comment in `jmr_js_vm.sv`).
5. **Do not delete files** *without asking*. Leftovers get a header comment
   and stay out of the FPGA-SIM / Vivado file list. (The user waived this
   for `jmr_js_vm_exec32.sv` on 2026-08-21 so Vivado could not compile it;
   git history keeps it. Removing a file from both file lists is what
   actually stops synthesis — deletion is only tidiness on top.)
6. **Do not `\`include` case arms** out of the parent `always_ff`. That hides
   the one-process Port A audit and does not shrink the netlist.
7. **Do not merge engines.** Console, storage, mini-FB, HDMI, SPI stay
   separate — they already are.

---

## Current hierarchy (what FPGA-SIM actually builds)

```
FPGA-SIM top = jmr_js_core          (sim/Makefile CORE_SRCS)
Board top    = top_nexys_video      (PHY shell; instantiates same core)

jmr_js_core
  ├─ jmr_keyboard_fifo
  ├─ jmr_video_vram          ← console glyph RAM (Port A template)
  ├─ jmr_console_engine      ← READY / LOAD / RUN / LIST
  │     └─ talks to storage_engine + VM code_we + ASET SRAM write
  ├─ storage_engine + sd_spi_master
  ├─ jmr_mini_fb             ← dual 640×480 (Port A template)
  ├─ jmr_rectdemo_engine     ← leftover RECTDEMO native path (still wired)
  ├─ jmr_palette_bram
  ├─ jmr_sram_model          ← SIM only (SRAM_INTERNAL=1)
  └─ jmr_js_vm               ← THE machine
        └─ jmr_js_vm_exec64  ← the only decoder (exec32 deleted 2026-08-21)
```

Board-only (not in `CORE_SRCS`): `top_nexys_video`, HDMI (`rtl/video/`),
`jmr_ddr3_sram_bridge`, `jmr_uart_link`, `jmr_ft245_async`, PS/2 + I2C
under `rtl/phys/`.

**LED input tests are not FPGA-SIM and not the JS `.bit`.** They live under
`tools/pmod_input_test/` and `tools/hid_led_blink/`, build into
`build/pmod_input_test/` / `build/hid_led_blink/`, and must never be added
to `CORE_SRCS` or `tools/board_flow`. Same JA/JB **plugs** as the board
top; different tops, different file lists. See
[Board LED input tests](#board-led-input-tests--never-fpga-sim).

**Stub, not the sim top:** `rtl/jmr_js_top.sv` (palette + `jmr_fb_mem` +
`jmr_input_engine`). FPGA-SIM never instantiates it. Easy to “fix” the
wrong file.

Two file lists must stay twins if anything moves:

- `sim/Makefile` `CORE_SRCS`
- `tools/board_flow/vivado_build.tcl` `jmr_add_sources`

`$readmemh` paths are **relative to the `.sv`**. `font_rom.hex` and
`invaders_jsb.hex` are copied next to the VM and into `sim/` by Make /
Vivado. Product titles are compile-on-RUN HTML — the hex is a BRAM
placeholder, not a sidecar game.

---

## Parent file map (`jmr_js_vm.sv`)

Line numbers drift. Search the **banner** (Phase 0) or the symbol. Measured
2026-08-20:

| Region | ~lines | What you are looking for |
|---|---|---|
| Ports + `code_mem` Port A | 14–110 | ProgramImage write from console |
| Heap / FB / timer decls | 111–1024 | Caps, `vst_win`, `hp_*`, `valloc_*` |
| **Local `st_t` enum** | 1025–1121 | Must match pkg + `vm_sname` + exec64 |
| Slot SRAMs + `varr_slot_addr` | 1127–1360 | 1-D object/array/env words |
| Value64 / GC / stack **tasks** | 1372–2435 | `stack_wr`, `hs_*`, `json_putc` |
| Dedicated Port A `always_ff` | 1837, 2435+, 5143–5950 | Legal SRAM. Copy this shape. |
| `u_exec32` port map | 2913–3971 | ~1,059 lines — dies with Cut A |
| `u_exec64` port map | 3972–~4850 | Handshake: `hs_m_*` in, `e64_*_q` out |
| Main FSM `always_ff` | 5951–end | Reset, exec write-apply, then case |
| `case (casestate)` | 6640–end | **Glass lives here** |
| Load / trail | 6641–7800 | JSB header, names |
| `S_FB_SYNC` | 7803 | Front→back present copy (must stay last enum) |
| JOIN / strings | 8132+ | Intern scan — do not extract |
| JSON | 9377+ | Same |
| `S_V64_ALLOC` | 10657 | First-entry guard pattern |
| `S_V64_GC_*` | 11538+ | Mark/sweep — do not extract |

Header comment at the top of the file lists boot/raster/strings only — it
**does not** mention HEAP / V64 / `S_FB_SYNC`. That stale map is why people
open the wrong third of the file.

**The bug pattern that keeps returning** (already in
[SESSION_HANDOFF.md](SESSION_HANDOFF.md)): exec64 sets `state_n = S_*`
into a parent arm. That arm needs the first-entry guard:

```
if (casestate_q != X) begin
    hs_st(X);
    // latch seeds from e64_*_q
    hs_ip(e64_ip_q);
    hs_vsp(e64_vsp_q);
end
```

Without `hs_st`, write-enables gated on `state` never fire. Without the
seed copy, the arm reads parent FFs nothing wrote. Without `hs_ip`,
completion re-fetches a stale opcode. **Audit any new `state_n = S_*` in
exec64 against this.** Reorg does not replace that checklist.

---

## Four copies of the same numbers (this is the org bug)

Opcodes and `st_t` are declared in **more than one place**. Drift here
looks like a title bug (`VMSTAT sname=?`, wrong overlay, exec64 enum
mismatch).

| Truth | Where | Drift seen 2026-08-20 |
|---|---|---|
| `OP_*` 1–34 | `jmr_js_vm_pkg.sv` | Canonical for exec64 (`import`) |
| `OP_*` 1–34 **again** | `jmr_js_vm.sv` lines 65–98 | Parent does **not** `import jmr_js_vm_pkg` |
| `Op` IntEnum | `functional_model/bytecode.py` | PYTHON compiler |
| `st_t` | `jmr_js_vm.sv` | 112 states, `S_V64_DISPATCH` last |
| `st_t` | `jmr_js_vm_pkg.sv` | **in sync** (verified 2026-08-21) |
| `vm_sname()` | `sim/sim_main.cpp` | **in sync** — was missing 4 tail states (`sname=?` on SLICE/SORT/FB_SYNC/DISPATCH); fixed 2026-08-21 |

Parent is the silicon enum; pkg is what exec64 imports; the C++ table is
what every trace prints. All three were verified equal on 2026-08-21 with
the snippet below — **run it after touching the enum**, because a silent
drift here prints `sname=?` and sends you hunting a title bug that does
not exist:

```bash
python3 - <<'EOF'
import re
def enum(p):
    L=open(p).read().split("\n"); k=next(i for i,l in enumerate(L) if "typedef enum logic [6:0]" in l)
    o=[]
    for l in L[k+1:]:
        if "st_t" in l and "}" in l: break
        o+=[t.strip() for t in re.sub(r"//.*","",l).split(",") if t.strip().startswith("S_")]
    return o
par=enum("rtl/engines/jmr_js_vm.sv"); pkg=enum("rtl/engines/jmr_js_vm_pkg.sv")
c=open("sim/sim_main.cpp").read(); i=c.index("static const char* vm_sname")
cpp=[n for n in re.findall(r'"([^"]+)"', c[i:i+3000]) if n.startswith("S_")]
print("parent",len(par),"pkg",len(pkg),"c++",len(cpp),"| all equal:",par==pkg==cpp)
EOF
```

Caps (`MAX_OBJ`, array tiers, `ENV_DEPTH`) are also repeated: pkg, parent
locals, `hardware_model/js_vm.py`, `jsb_format.py`. Those must stay equal
— a check script is cheaper than a module split.

---

## Leftover / confusing files (label, do not delete)

| File | Status | Trap |
|---|---|---|
| ~~`jmr_js_vm_exec32.sv`~~ | **Deleted** 2026-08-21 ([REMOVING_EXEC32.md](REMOVING_EXEC32.md)) | Gone from `CORE_SRCS` and `vivado_build.tcl`. The 74 parent-owned `e32_*`-named signals are **not** exec32 — see that file's naming trap |
| `jmr_rectdemo_engine.sv` | Still instantiated in `jmr_js_core` | Native RECTDEMO, not HTML RUN |
| `jmr_js_top.sv` | Stub | Not FPGA-SIM |
| `jmr_fb_mem.sv` / `jmr_input_engine.sv` | Only that stub | Real path is `jmr_mini_fb` + core `joy_in` |
| `jmr_ps2_host.sv` | Kept; **off** the board build | TX 0xFF/0xF4 killed J15 scan |
| `jmr_ps2_simple.sv` | Not in `CORE_SRCS` / Vivado list | `ps2_rx` + `ps2_decode` are the live PHY |
| `jmr_hdmi_scanout.sv` / `jmr_hdmi_colorbar.sv` | Early HDMI | Live glass is `jmr_text_hdmi_scanout` |
| `invaders_jsb.hex` (engines + sim + vectors) | `$readmemh` placeholder | Not a title sidecar |
| `tools/pmod_input_test/` | LED bit only (`build/pmod_input_test/`) | Own copies of `jmr_i2c_*` + `usb_ps2_try` (F4 TX). **Never** `CORE_SRCS` |
| `tools/hid_led_blink/` | J15 LED bit only (`build/hid_led_blink/`) | No VM. Shares `rtl/phys/ps2_rx.sv` with the JS **board** top only |

---

## Board LED input tests — never FPGA-SIM

Old bring-up bits that light LEDs for J15 / JA keyboard and JB joystick.
**Not** the machine. **Not** F9 FPGA-SIM. Do not merge them into
`jmr_js_core` / `jmr_js_vm` / `sim/Makefile`.

| | FPGA-SIM (`make -C sim sim_server_synth`) | JS board (`make -C tools/board_flow bit`) | LED tests |
|---|---|---|---|
| Top | `jmr_js_core` | `top_nexys_video` → same core | `top_pmod_input_test` / `top_hid_led_blink` |
| Keyboard | `key_evt_*` from GUI / `sim_main` | `ps2_rx` + `ps2_decode` in the **PHY shell**, then those ports | LEDs only |
| Joystick | `joy_in` from GUI KEYBITS | `rtl/phys/jmr_i2c_joy.sv` ORed with tether | LEDs only |
| Build dir | `sim/sim_build_synth/` | `build/nexys_video/` | `build/pmod_input_test/` · `build/hid_led_blink/` |
| VM / HDMI / FAT | yes | yes | **no** |

**Name collision:** `jmr_i2c_joy` / `jmr_i2c_master` exist twice — live
copy in `rtl/phys/` (JS board), snapshot in `tools/pmod_input_test/`
(LED bit). Edit the live copy for the machine. Do not add the snapshot
to FPGA-SIM.

**`usb_ps2_try.sv` drives PS/2 clock (retry `0xF4`).** That class of TX
is why `jmr_ps2_host` was pulled off the JS top. Never instantiate it in
`jmr_js_core`, `top_nexys_video`, or `CORE_SRCS`.

**One file, two board bits — not a copy.** The LED Makefiles do **not**
have their own `ps2_rx.sv`. They compile the same path the JS machine
uses:

`rtl/phys/ps2_rx.sv`  (hid blinker + pmod LED test + JS `top_nexys_video`)
`rtl/phys/ps2_decode.sv`  (pmod LED test + JS `top_nexys_video`)

Three products, three builds:

| If you edit `rtl/phys/ps2_rx.sv` then… | Effect |
|---|---|
| `make -C tools/hid_led_blink bit` | LED blinker changes (expected) |
| `make -C tools/pmod_input_test bit` | LED test changes (expected) |
| `make -C tools/board_flow bit` | **JS machine `.bit` also changes** — same source file |
| `make -C sim sim_server_synth` | **No change.** FPGA-SIM never compiles this file. Keys come from the GUI (`key_evt_*`). |

So: tweaking debounce in `ps2_rx.sv` “for the LED test” is also a keyboard
change on the next flashed JS bitstream. It will not show up in F9 FPGA-SIM.
The I2C joystick files are the opposite setup — LED test has a **snapshot**
under `tools/pmod_input_test/`; the machine uses `rtl/phys/jmr_i2c_*.sv`.

How to run the LED bits (board only): [FPGA_BRINGUP.md](FPGA_BRINGUP.md#pmod-input-led-test-ps2-keyboard--i2c-joystick--j15-usb).

---

## Maintenance backlog (do these instead)

Ordered by (measured pain removed) ÷ (risk). Each is independently
landable and none of them moves a file. Written 2026-08-21 from the bug
classes that actually cost time — see the JUDGMENT at the top.

### 1. Scratch-register ownership table — **highest value, zero silicon risk**

The parent reuses a handful of general-purpose registers across states
that know nothing about each other. This produced **#69**, the worst bug
of the cycle: an event dispatch ran the FRAME_KEY listener scan, which
reuses `bind_k`, which silently destroyed a half-finished rAF snapshot's
cursor — the machine then "ran the rAF callback" and executed a keyup
listener instead, and the game loop stopped. It took a purpose-built
beat-level trace (`RAFTRACE`) to see it.

Known shared scratch: `bind_k`, `bind_rd_arm`, `vfe_rd_arm`,
`jn_slot_arm`, `jn_rd_arm`, `jn_name_arm`, `hp_proto_arm`,
`valloc_rd_arm`, `tfn_rd_arm`, `vgc_rd_arm`, `txt_ph`, `fpx_acc`.

Do:
1. A table in `jmr_js_vm.sv` next to the declarations: **register → every
   state that writes it → who must reset it on entry.**
2. A one-line rule adopted for new code: *a multi-beat walk owns its
   cursor and must reset it in its own first-entry guard*, never trust
   what a previous state left.
3. A `sim_main.cpp` assertion for the specific #69 shape: if `jn_slot_arm`
   is high while the state changes to one that is not part of the rAF
   snapshot, print a loud line. Cheap, catches the whole class.

### 2. Rename the 74 parent-owned `e32_*` signals to `p_*`

The prefix **lies**: of ~376 `e32_*` names, 74 are parent silicon (shared
Port-A read-result and poke buses) read by Value64 states. This trap has
already cost one near-miss during the unhook. Mechanical rename, do it
inside the Phase 3b sweep ([REMOVING_EXEC32.md](REMOVING_EXEC32.md)) while
those files are already open.

### 3. Assert the two-beat SRAM read contract in simulation

Bug class: **registered raddr → registered rdata consumed one beat early.**
Seen this cycle in `join` (digits all read `"0"`), `replace` (junk
replacement char), and historically in #58 / `S_IMGD`. The tell is always
a mux term gated on an arm flag that reads 0 during its own set beat.

Do: in `sim_main.cpp`, for the handful of hot registered reads
(`name_hash_rdata`, `name_blen_rdata`, `varr_rdata`, `vobj_rdata`,
`venv_rdata`), record the beat the address last changed and warn when a
consumer state samples the data fewer than 2 beats later. This is a
simulation-only guard — no RTL, no fit cost — and it turns a multi-hour
hunt into a printed line.

### 4. Keep the probe-RPC toolkit healthy — it is the crown jewel

`STATEHIST?`, `IPTRACE`, `VVWATCH`, `BEATLOG`, `RAFTRACE`, `NAMEPEEK`,
`OBJPEEK`, `VARRPEEK`, `FBHIST?`, `FBBOX`, `JSONMEM`. Nearly every bug
this cycle was solved by adding or reading one of these, usually in
minutes. Rules learned:
- Adding an RPC is ~5 minutes and almost always cheaper than reasoning.
- A probe **must** name what it reads: `OBJPEEK` reads `obj_cls` (the
  32-bit twin) not `vobj_cls`, and that mislabel cost a wrong diagnosis.
- Verilator needs `/*verilator public_flat_rd*/` on anything a probe
  touches; add it when you add the signal, not when you need it at 2am.

### 5. First-entry guard as a checklist item for every exec-entered state

Bug class: a parent state entered from exec whose seeds live only in exec
FFs (S_SQRT's splash hang; S_FONTPX and S_V64_DISPATCH needed one by
construction). The guard shape is always:

```systemverilog
if (state != S_X && jsb_flags[3] && e64_leave_hold) begin
    hs_st(S_X);
    /* copy the seeds from e64_*_q here */
    hs_ip(e64_ip_q); hs_vsp(e64_vsp_q);
end else begin /* the walk */ end
```

Put that snippet in the file header next to the state map so it is copied,
not rediscovered.

### 6. Faster feedback tier

`tests/test_rtl_snippets.py` is ~75 minutes because each test spawns a
Verilator sim and the title tests run real frames. That length pushed work
toward single-test reruns and background batches, which is where two
false conclusions came from this cycle (a probe that shared a sim session
and looked like a bug; a suite run that raced a rebuild and skipped 139
tests). Do: mark a **smoke tier** (`-m smoke`, ~5 minutes: probe ladder +
one frame per title) that is the pre-commit gate, and keep the full suite
for pre-synthesis. Also: the harness now copies `card.img` to a scratch
per session — keep it that way; tests writing the user's card produced a
"DIR is broken" report that was really 40 leftover probe files.

### 7. Numbers in one place (the original org bug, still true)

Caps are repeated in `jmr_js_vm_pkg.sv`, parent locals,
`hardware_model/js_vm.py`, `jsb_format.py`. The enum drift check above is
the pattern: a tiny script in CI beats a module split. Extend it to
`MAX_OBJ` / `MAX_ARR` / `ENV_DEPTH` / `OBJ_SLOTS` / native-id count.

---

## How to reorganize (phases) — DEFERRED, see JUDGMENT

Kept because the analysis is sound *if* a reorg is ever justified. Phase 0
(navigation banners) and Phase 2 (one enum / one opcode table) are the only
parts worth doing on their own; both are covered more concretely by the
Maintenance backlog above.

Do these **in order**. Each phase is one dedicated agent. Tests / probes
before claiming done. Do not `make bit` unless the user asks.

### Phase 0 — navigation only (no netlist)

Safe any time. Does not move logic.

1. Searchable banners in the parent `always_ff` and exec64 opcode `always_comb`,
   e.g. `// === VM:HEAP ===` `// === VM:GC ===` `// === EXEC:GET_PROP ===`.
2. Replace the stale header “section map” in `jmr_js_vm.sv` with the table
   above (HEAP / V64 / FB_SYNC included).
3. One comment at each leftover file: “not in FPGA-SIM core” or “board PHY
   only” or “exec32 leftover — see REMOVING_EXEC32.md”.
4. Keep this document’s line map honest when the file moves a lot.

### Phase 1 — unhook exec32 ✅ DONE 2026-08-21

Already specified: [REMOVING_EXEC32.md](REMOVING_EXEC32.md) Cut A.
**Largest maintainability win.** Removes ~5k lines, ~1k-line port map,
~379 `e32_*` signals, and the tagged LUTRAM that mapping OOMs on.

Do not run Phase 2–4 in parallel with that cut. Do not bundle Cut B
(console `.JS` sidecar tidy).

### Phase 2 — one enum, one opcode table

After exec32 is gone (or at least after its port map is not being edited):

1. Parent `import jmr_js_vm_pkg::*;` — delete the local `OP_*` block and
   the **duplicate** `typedef enum … st_t` (keep one type).
2. Put `S_FB_SYNC` on the pkg enum (last). Then `vm_sname[]` in
   `sim_main.cpp` **in the same commit**.
3. Small checker (Python is fine): pkg enum names/order vs parent (until
   unified) vs `vm_sname[]` vs `functional_model/bytecode.py` `Op`. Fail
   CI / `check_runtime_parity` if they diverge.
4. Caps: prefer pkg + `jsb_format.py` as the two poles; parent should
   use the pkg constants, not a second `localparam` copy.

This is the reorg that **finds bugs**. A missing `sname` today already
proves it.

### Phases 3–5 — cut 2026-08-21

Removed: leftover-engine rewiring, folder moves, and the handshake-card /
struct plan. All three were "if we reorganize" work, and the JUDGMENT at
the top says we are not. The parts that carried real information are
already elsewhere: leftover-file labels in the table above,
[FPGA_FIT.md](FPGA_FIT.md) for the Port A recipe, and the
[Maintenance backlog](#maintenance-backlog-do-these-instead) for the
handshake / first-entry-guard discipline (item 5) and the secondary
Python/C++/test organization notes (items 3, 4, 6).

If someone revives a folder move, the two rules that matter are: update
`sim/Makefile` `CORE_SRCS` and `tools/board_flow/vivado_build.tcl`
**together**, and remember `$readmemh` paths are relative to the `.sv`.

---


## Related

- [ARCHITECTURE.md](ARCHITECTURE.md) — blocks ↔ FM ↔ RTL
- [FPGA_FIT.md](FPGA_FIT.md) — Port A / LUTRAM / do not extract HEAP
- [REMOVING_EXEC32.md](REMOVING_EXEC32.md) — Cut A (do that before folder moves)
- [VIVADO_FLATTEN_HUNT.md](VIVADO_FLATTEN_HUNT.md) — why extracts failed
- [SESSION_HANDOFF.md](SESSION_HANDOFF.md) — live glass / first-entry guard
- [JMR_JS_COMPATIBILITY.md](JMR_JS_COMPATIBILITY.md) — opcodes 1–34, natives 0–40
