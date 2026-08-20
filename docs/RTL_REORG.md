# RTL reorganization — maintain and find bugs

**Plan only.** Written 2026-08-20 from the tree as it sits. **No RTL was
moved or edited for this document.** Do not start a file-move or enum-unify
pass in the same job as glass, FIND, Port A, or `make bit`.

FPGA-SIM **is** the synthesis RTL (`never-fake-fpga-sim`). The goal of a
reorg is: an agent (or human) can land on the right clock, the right SRAM
port, and the right handshake without cloning the heap or inventing a second
VM. Architecture stays [ARCHITECTURE.md](ARCHITECTURE.md). Fit/synth law
stays [FPGA_FIT.md](FPGA_FIT.md) and `.cursor/rules/never-fake-fpga-sim.mdc`.

---

## Why this is hard today

The folder split (`rtl/engines/`, `rtl/video/`, `rtl/phys/`) is already
right. The pain is **three files** that are the chip:

| File | Lines (2026-08-20) | Role |
|---|---:|---|
| `rtl/engines/jmr_js_vm.sv` | 14,963 | Parent: one JS heap, Port A SRAMs, `case (casestate)` |
| `rtl/engines/jmr_js_vm_exec64.sv` | 7,361 | Value64 opcode/native decoder (product titles) |
| `rtl/engines/jmr_js_vm_exec32.sv` | 5,179 | Tagged Q16 leftover — still synthesized |
| **Those three** | **~27.5k** | **~72% of all `rtl/*.sv`** |
| Rest of `rtl/` | ~10.7k | Console, storage, video, PHY, tops — already modules |

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
5. **Do not delete files.** Leftovers get a header comment and stay out of
   the FPGA-SIM / Vivado file list. User rule.
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
        ├─ jmr_js_vm_exec32  ← leftover; enable !jsb_flags[3]
        └─ jmr_js_vm_exec64  ← product; jsb_flags[3]
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
| `st_t` | `jmr_js_vm.sv` 1025–1121 | **Has `S_FB_SYNC` last** |
| `st_t` | `jmr_js_vm_pkg.sv` 89–185 | **Stops at `S_V64_SORT` — no `S_FB_SYNC`** |
| `vm_sname[]` | `sim/sim_main.cpp` 382–407 | **Stops at `S_HEAP_CLR` — missing SLICE, SORT, FB_SYNC** |

So today: parent is the silicon enum; pkg is what exec64 thinks; C++ names
are one more beat behind. That is harder to debug than a 15k-line file.

Caps (`MAX_OBJ`, array tiers, `ENV_DEPTH`) are also repeated: pkg, parent
locals, `hardware_model/js_vm.py`, `jsb_format.py`. Those must stay equal
— a check script is cheaper than a module split.

---

## Leftover / confusing files (label, do not delete)

| File | Status | Trap |
|---|---|---|
| `jmr_js_vm_exec32.sv` | Live in synth until [REMOVING_EXEC32.md](REMOVING_EXEC32.md) | Titles never enable it; Vivado still cannot fold it |
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

## How to reorganize (phases)

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

### Phase 1 — unhook exec32

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

### Phase 3 — leftover engines (wiring, not deletes)

After Phase 1, decide in a **separate** pass:

- `jmr_rectdemo_engine`: still muxed onto the FB in `jmr_js_core`. Either
  keep as a debug native path or stop instantiating it. Do not delete the
  file.
- Stub `jmr_js_top` / `jmr_fb_mem` / `jmr_input_engine`: leave on disk;
  do not add them to `CORE_SRCS`.
- PHY leftovers stay under `rtl/phys/` / `rtl/video/` with headers.

### Phase 4 — folder moves (optional, one commit)

Only after Phase 1–2. **No logic change.** Update `CORE_SRCS`,
`vivado_build.tcl`, and hex copy paths together. Suggested grouping
(names are folders, not new modules):

```
rtl/
  jmr_js_core.sv              # SIM + board shared core
  top_nexys_video.sv          # board PHY shell only
  jmr_js_top.sv               # stub — keep, do not use
  vm/                         # already-separate VM files, same instances
    jmr_js_vm.sv
    jmr_js_vm_exec64.sv
    jmr_js_vm_pkg.sv
    jmr_value.sv
    jmr_js_vm_exec32.sv       # until Phase 1 lands, then leftover header
  console/                    # READY machine (already separate)
    jmr_console_engine.sv
    storage_engine.sv
  mem/                        # Port A templates — copy these, do not invent
    jmr_mini_fb.sv
    jmr_video_vram.sv
    jmr_palette_bram.sv
    jmr_sram_model.sv
    jmr_ddr3_sram_bridge.sv
  video/                      # already exists
  phys/                       # already exists
  leftover/                   # optional: move stubs here so they are obvious
```

**Do not** put JOIN/JSON/GC/HEAP `.sv` files in `vm/`. That is Phase-forbidden
extract, not a move.

### Phase 5 — handshake card (docs first, structs later)

The exec64 port list is a wall of `hs_m_*` / `e64_*_q`. That wall is why
write-enable-on-leave_hold bugs hide.

1. First: a comment block in `jmr_js_vm_pkg.sv` listing each handshake
   pair (parent FF ↔ exec `_q` / `_n`) and the first-entry rule.
2. Later, **maybe** a SystemVerilog `interface` or packed struct to shrink
   the instance. Treat that as a **netlist-risk** change: Vivado + Verilator
   both have to agree. Do not do it to “look cleaner” during a glass hunt.

Duplicated **tasks** (`v64_add_task`, `json_putc`, clip helpers) in parent
and exec64: after Phase 1, move **pure functions** into `jmr_value.sv`
(already the Number/tag package). Tasks that pulse Port A strobes stay in
the parent.

---

## What “easier to find bugs” looks like when this is done

| Job | Today | After |
|---|---|---|
| Add a parent state | Edit enum in **three** places + hope `sname` matches | Edit pkg once; checker fails if C++/Python lag |
| Glass: black / hung FRAME | Scroll 8k-line case; stale header map | Banner `=== VM:WAIT_FRAME ===` / `=== VM:FB_SYNC ===` |
| New exec→parent overlay | Miss `hs_st` / `hs_ip` | Same code, but handshake card + first-entry comment at every `S_V64_*` |
| Synth OOM / LUTRAM | Hunt `e32_*` and tagged `stack` in the same file as Value64 | exec32 gone; Port A leftovers listed in FPGA_FIT |
| “Fix the top” | Open `jmr_js_top.sv` | Header says stub; real top is `jmr_js_core` |

Traces still win first: [use-existing-traces](../.cursor/rules/use-existing-traces.mdc).
`VMSTAT?` / `STATEHIST?` only help if `sname` matches silicon.

---

## Other repo areas (secondary — only if they unblock RTL)

The RTL is the product. These are easier **organization** wins that make
RTL bugs cheaper to prove. Do not restructure them instead of Phase 1–2.

### Worth it (mirrors the chip)

| Area | Size now | Why org helps RTL |
|---|---|---|
| `hardware_model/js_vm.py` | 4,630 | PYTHON twin of the **serialized** ProgramImage + heap caps. README still says “later” — it is already the load/memory twin. Grouping it like the parent (load / heap / natives / GC) finds PYTHON↔RTL skew without touching SV. |
| `sim/sim_main.cpp` | 2,835 | Card model + RPC + `vm_sname` + Verilator peeks in one file. Split **names table** (Phase 2) first; optional later: RPC vs SD model. Hierarchy paths (`u_vm__DOT__…`) break if you rename instances — keep `u_vm` / `u_exec64`. |
| `tests/test_rtl_snippets.py` | 5,795 | FPGA-SIM probes. Splitting by feature (`heap`, `canvas`, `string`, `gc`) makes a glass regression visible. Do not invent random programs (`python-first-parity`). |
| `tests/test_bytecode_js.py` | 4,026 | PYTHON / `JsHwVm`. Same split. Keep titles as the battery. |

### Already fine — do not “organize”

| Area | Why leave it |
|---|---|
| `functional_model/` (compiler, canvas, storage, html_loader) | Already one file per engine. Matches ARCHITECTURE table. |
| `tools/compile_js.py` | 277 lines. HTML → ProgramImage. Keep it the thin CLI. |
| `rtl/video/`, `rtl/phys/` | Correct split. PHY bugs stay off the VM. |
| `tools/pmod_input_test/`, `tools/hid_led_blink/` | **Leave them.** LED-only; never fold into FPGA-SIM ([above](#board-led-input-tests--never-fpga-sim)). |
| `storage/*.HTML` | Titles, not ISA. Do not hardwire. |
| `docs/` ledgers (FIT, flatten hunt, potential bugs) | Different jobs. Do not merge into one mega-doc. |

### Tempting and wrong

| Idea | Why not |
|---|---|
| Make `hardware_model` a cycle-accurate second RTL | PYTHON is **results** parity, not wall-clock. |
| Grow `functional_model/bytecode.py` VM as the chip | Product path is `JsHwVm` + serialized image. Tagged leftover dies with exec32. |
| Split `gui_jmr_js.py` to debug glass | Glass bugs are in the VM / traces. GUI is the mirror. |
| New engines for JOIN/JSON/GC to “match Python files” | Forbidden extract. |

---

## Suggested work order (when someone is asked to do this)

1. **Phase 0** banners + leftover headers (hours, no risk).
2. **Phase 1** exec32 — [REMOVING_EXEC32.md](REMOVING_EXEC32.md) (the real cut).
3. **Phase 2** unify `st_t` / `OP_*` / `vm_sname` + a checker (this is the
   bug-finding reorg).
4. Only then: Phase 3 wiring, Phase 4 moves, Phase 5 handshake card.
5. Secondary: split `test_rtl_snippets.py` and tidy `js_vm.py` **sections**
   (not a rewrite) so a probe name points at one heap behavior.

Until Phase 1–2, **do not** move `jmr_js_vm.sv` between folders. Search and
the two file lists are enough.

---

## Related

- [ARCHITECTURE.md](ARCHITECTURE.md) — blocks ↔ FM ↔ RTL
- [FPGA_FIT.md](FPGA_FIT.md) — Port A / LUTRAM / do not extract HEAP
- [REMOVING_EXEC32.md](REMOVING_EXEC32.md) — Cut A (do that before folder moves)
- [VIVADO_FLATTEN_HUNT.md](VIVADO_FLATTEN_HUNT.md) — why extracts failed
- [SESSION_HANDOFF.md](SESSION_HANDOFF.md) — live glass / first-entry guard
- [JMR_JS_COMPATIBILITY.md](JMR_JS_COMPATIBILITY.md) — opcodes 1–34, natives 0–40
