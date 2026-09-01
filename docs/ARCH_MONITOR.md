# Architecture Monitor — watching the machine while it runs

Words: [README.md — Words used](../README.md#words-used-in-this-project).

**F10** in the GUI opens the Architecture Monitor (`gui_arch_monitor.py`); it
reads `backend.arch_snapshot()` every frame. The Inspector windows (REGS /
VMSTAT, obj, arr, stack, sram, raf, ring) pull through
`backend.arch_peek(name, *args)`.

Every runtime fills the same snapshot from a different place. **BOARD is the
newest tier and the one with the least bandwidth** — read
[§ BOARD](#board--live-watching-real-silicon) before trusting any field you
see while the board is running.

---

## Why this document exists

On silicon there is no debugger. Either the design reports its own state or
the failure is a black box. Decode tables are under [BOARD](#board--live-watching-real-silicon).
PACMAN `fault 3` / stale-card case: [below](#case-stale-card-looks-like-a-vm-bug).

---

## Data sources per runtime

### PYTHON

While an HTML title runs, `Machine.vm` is the *loader's* VM and stops updating.
Live state is on `Machine._hw_vm` (a `JsHwVm`): `_value_last_ip`,
`_value_last_op`, `_value_stack`, `_value_objects`, `_value_arrays`,
`_value_envs`, `_value_raf`, `_value_timers`, `_value_listeners`. Reading
`Machine.vm` reports ip 0 / empty heap forever.

### FPGA-SIM

`VMSTAT?` carries `sname` + `ip`, no opcode byte — decode the op from the
compiled image at that ip (`decode_op_at`); the RTL runs the same image, so it
is exact. `VMSTAT?` sampled at the frame beat reads `S_WAIT_FRAME` ~99% of the
time, so a single `sname` cannot show which engines ran; `PROF?` / `PROFCLR`
give the RTL's own per-state cycle histogram, which is the real answer.

Observer RPCs are effectively free — a simulated FRAME is ~1739 ms while
`VMSTAT?` / `VRING?` / `IPTRACE?` / `PROF?` are ~0.01 ms each. Read them every
frame; throttle only the flight-log writes.

### The frozen-IP trap (both sim runtimes)

The GUI can only sample between frames, and there the VM is always parked at
the same rAF return — 30 consecutive samples during play showed the identical
IP. Both runtimes therefore hand the monitor an **executed-IP ring**
(`ip_ring` in the snapshot, resolved via `backend.arch_decode(ip)`). FPGA-SIM
uses `IPTRACE <n>` armed before each FRAME; PYTHON samples every **251st** op —
a *prime* period, because a power of two aliases against loop bodies and pinned
the replay to two hot IPs.

---

## BOARD — live watching real silicon

The tether is the **PROG cable**, same USB cable as JTAG: Nexys Video's FT2232
**channel A** is an FT245 FIFO (DPTI), which Linux exposes as the `/dev/ttyUSB*`
whose USB location ends in **`.0`**. Channel B (`.1`) is JTAG and is never the
tether. `JMR_JS_SERIAL` overrides autodetect.

The bitstream emits four line types (`runtime/board_backend.py`):

| Line | Payload | Meaning |
|---|---|---|
| `S<rowhex>:<64 chars>` | text console row | 64×16 glass, letterboxed like HDMI |
| `P<rr>:<160 hex nibbles>` | mini-FB row | 160×120, scaled ×4 to 640×480 |
| `K` | keystrobe | PS/2 scancode proof (J15) |
| `D<hh>` | `stor_state` | **storage stall telemetry** (during a qualifying stall) |
| `E<hh>` | `stor_state` | **free-running state beat** — always on, incl. idle |
| `V<st2><fault2><ip4>` | `{casestate, fault, ip}` | **VM heartbeat / fault** |
| `G<12 hex>` | `{fault_site16, fault_arg32}` | **fault site + the value it refused (run 68+)** |

### The V-line — VM heartbeat

Added 2026-08-26 (`2b0f1f3`). Three arms: once per completed S/P glass dump, on
every `machine_fault` rising edge, and — since `eb93865` — on a free-running
~0.67 s beat.

That third arm matters: with only the dump-edge trigger the heartbeat was
lively during games (where FB rows stream continuously) and **silent at the
console**, because a static glass produces no dumps. The Architecture Monitor
looked dead whenever the machine was at READY, which is exactly when you most
want to watch it. Parsed by `_parse_vm_v_line`; a torn or short
line returns `None` and is ignored, never raised.

**This is the whole payload: state, fault code, ip.** Three fields.

> ### The `—` trap — read this before reading the Inspector
>
> The REGS/VMSTAT window has rows for `fsite`, `ecode`, `efault`, `bad state`,
> `HTML line`, `source`, and an `overflow:` row covering heap / json / stack /
> call / timer / str / path. **On BOARD every one of those renders `—`, and
> `—` means NOT TRANSMITTED — it does not mean zero.**
>
> Reading `overflow: heap —` as "heap is fine" is a wrong conclusion the panel
> invites. Those fields exist for PYTHON and FPGA-SIM, where the whole VM is
> visible. The V-line itself is three numbers — run 60+ bits add the H/F/T
> lines below, which fill in live pool counts and fault forensics, but every
> field NOT carried by one of those four line types still renders `—` on
> BOARD, and it still means "not transmitted".

Fault codes (`fault_code` in `rtl/engines/jmr_js_vm.sv`):

| Code | Meaning | Site(s) in `jmr_js_vm.sv` |
|---:|---|---|
| 2 | call-stack overflow (`vcsp >= CSTK`) | 10540 |
| **3** | **capacity — allocator found no free slot** | 9554 / 10141 / 10227 (runtime, `vfree_ok` false); 6657 (load-time, image exceeds `CODE_WORDS`) |
| 4 | bad/stale env handle (depth, valid bit, or generation mismatch) | 10596 |
| 5 | swept JSON walker path reached | 9490, 9503 |
| 9 | tagged image refused | 6644 |

All three runtime fault-3 sites share one shape, and it is worth recognising
on sight:

```systemverilog
if (vfree_ok) begin ... vobj_next <= valloc_i + 14'd1; ... end
else begin machine_fault <= 1'b1; fault_code <= 8'd3;
           running <= 1'b0; hs_st(S_DONE); end
```

`running <= 1'b0` is the point. **A fault is a deliberate halt, not a hang** —
from the glass the two look identical, and the V-line is the only thing that
tells them apart. `MAX_OBJ = 960` (`jmr_js_vm.sv:457`).

### H / F / T lines — heap gauge and fault forensics (run 60+)

Three observation-only additions (zero execution cost — background
scanner on dedicated LUTRAM read ports, shadow latches on the fault
edge; proof of harmlessness is a digit-identical fclk profile):

| Line | Payload (hex nibbles after the letter) | When |
|---|---|---|
| `H<8>` | `{env[9:0], arr[10:0], obj[10:0]}` live counts (background scan, ~20 µs refresh) | beside every V heartbeat |
| `F<16>` | `{kind[1:0], retried, state[6:0], vcsp[7:0], vsp[11:0], 00}` then `{env10, arr11, obj11}` at-fault pools | once per machine_fault rise |
| `T<32>` | last 8 committed ips, newest first (16 bits each) | once per machine_fault rise |

The F-line kills the frozen-IP trap: `kind` names WHICH allocator
faulted (0=obj 1=arr 2=fn 3=env), `retried` says whether forced GC
already ran, and the pool counts show what was actually full. The
T-line shows the real approach path instead of one in-flight ip.
The H-line makes slow pool growth (the INVFAST grids-leak class)
visible as a stair-step long before any fault.

**First hardware capture (2026-08-30, INVFAST saucer kill):** one F/T
pair named a bug three days of theory-testing hadn't — `kind=env` with
4/384 slots live (allocator refused a ~99 %-empty pool, no GC retry),
and the T-line walked the entire `Saucer.points()` body to the
`CALL_METHOD` return seam. Two reading notes from that capture:
**jump-class ops do not commit T-line entries** (the body's `JUMP` was
absent from the trail), and the newest trail entry can be the op
*after* the fault ip — the fault latches mid-op while the ring has
already committed the successor.

### Where the run-60 telemetry appears in the GUI

**Main window — no clicks needed:**
- **OBJECT/HEAP** core block and **HEAP STATS** block captions show
  live `obj` / `arr` / `env` counts (H-line). Before run 60 these were
  `—` on BOARD.
- The bottom status line on a fault names the failing allocator and
  the at-fault pools inline:
  `FAULT 3 at IP 1531 (L—) [env alloc — pools env 4 arr 21 obj 689] — click REGISTERS`.
- The **Keyboard** connector block blinks on every real keystroke
  (see Traps below — GUI keys on all runtimes, tether K-lines on
  BOARD).

**Inspectors (click a block):**
- **REGISTERS** or **1 PROGRAM SEQUENCER** → the `!! FAULT` block adds
  "BOARD run-60+ fault forensics (F-line)" (kind / retried / state /
  vcsp / vsp / pools) and "BOARD approach path (T-line, newest
  first)" — the last 8 committed ips.
- **OBJECT/HEAP** or **HEAP STATS** → live `obj n/960`-style capacity
  rows (H-line). Slot peeks still say "(not available on BOARD)" —
  counts are transmitted, contents are not.

**Flight log (`traces/session_*_BOARD.log`):** every parsed line
leaves a note — `VM st=… fault=… ip=…`, `FAULT kind=… pools…`,
`TRAIL <8 hex ips>`, `KEY DOWN/UP … repeat=…` — so a session is
reconstructable after the fact and a held-key storm can be lined up
against a fault by timestamp.

### The G-line — fault site + faulting value (run 68+)

Added 2026-09-01 (`ef0ca22`), latched on the same `machine_fault` edge as
F/T. Twelve hex chars: `{fault_site[15:0], fault_arg[31:0]}`. `fault_site`
is the RTL source-line stamp of the assignment that faulted — and as of the
same commit the VM finally adopts exec64's site (before this, every exec64
fault reported a stale parent `fsite`, on every runtime). `fault_arg` is
the value the faulting site refused: the out-of-range index for the
stgWrite/srcWrite/artWrite2/srcSetLen bound traps (sites 4460/4497/4480/
4523), or the unknown native id at site 4183. Parsed by `_parse_g_line`;
appears in the flight log as `GSITE fsite=… arg=…` and fills the
Inspector's `fsite` slot on BOARD.

Reading `fault_arg`: a value of EXACTLY a region's size (e.g. 380,928 =
CSTG arena end) means an incrementing writer ran off the end — the guard
fires on the first illegal index of a runaway loop, not on a poisoned
scalar. A small negative value points at sentinel arithmetic (an unset
`-1` index); huge positives at a corrupted count.

### Content-level diagnostics beat RTL telemetry for compile bugs

The 2026-09-01 board-compile hunt (see memory: board-compile-bringup)
closed with a lesson: for CHAIN-PROGRAM faults, instrument the HTML first.
COMPILER.HTML's `dgFail()` prints ASCII numbers through the ?CE message
path (`MSG_OFF = 128` — it was 0 since birth, which made every ?CE mute);
one card re-mint per iteration, no synthesis. The RTL G-line is the
backstop for faults the content cannot see coming.

### The STOR-BEAT cons field decodes the console FSM

`STOR-BEAT stor=0xSS cons=0xCC` (flight-log NOTE lines): `cons` is the
console state, positional in `jmr_console_engine.sv`'s `cstate_t` enum —
dump the enum and index by the hex value. This walked the whole COMPILE
chain during the run-66/67 forensics (C_JSB_OPENW 0x69 → C_JSB_GBW 0x6B →
C_CMP_WAIT 0x30 → C_IDLE 0x03). The `ps2_strobe` NOTE lines reconstruct
the user's full keystroke history (set-2 make/break decode).

### The D-line — storage stall telemetry

Fires after **~0.67 s of continuous storage busy**, then repeats every ~0.17 s
carrying `stor_state`, for as long as the stall lasts. Normal operations idle
between console strobes and never accumulate enough busy to trigger.

Storage state codes (`storage_engine.sv`, 103 states):

| Codes | States | Stuck in |
|---|---|---|
| `0x00` | `S_IDLE` | not busy |
| `0x02` | `S_ERR` | errored |
| `0x09` | `S_SD_WAIT` | waiting on `sd_ack` — an SD read/write in flight |
| `0x0B`–`0x13` | `S_MNT0`…`S_MNT3C` | **mounting the card** |
| `0x16`–`0x1C`, `0x66` | `S_DS_*`, `S_DS_CHAIN` | **root-directory scan** |
| `0x5F`–`0x65` | `S_DIR0`…`S_DIR_ADV` | **DIR itself** |

**No D-lines during a failure is itself a reading**: storage was never
continuously busy, so the fault is not a storage-side stall.

### The E-line — free-running storage-state beat

`E<state2>`, emitted every ~1.34 s **plus** on any state change (rate-capped at
10 ms so churn cannot flood TX), **regardless of dwell or busy** — including
`E00` at idle. Host logs it change-only as `STOR-BEAT`.

This is the one to reach for first. The D-line only speaks during a qualifying
stall; the E-line always says where storage is, so it answers "where is it
parked" without requiring the failure to match the stall heuristic.

### Two defects this telemetry has already had — check the emit before trusting silence

Both were found only by running a real stall with a capture attached. Neither
was visible in normal use.

1. **Pre-`5968932`: could never fire.** The dwell test compared for equality on
   a *saturating* counter. Zero D-lines in any board log older than that commit
   proves nothing at all.
2. **`5968932` → `eb93865`: fired four times, then went silent forever.**
   `d_dwell` is 27 bits and saturated at `0x7FFFFFF` (1.342 s) while the emit
   needed `d_dwell[23:0] == 0`, so a stall got **exactly four lines between
   0.671 s and 1.174 s** and nothing after — despite a comment claiming "every
   ~0.17 s". Fixed in `eb93865`: the dwell re-arms at saturation.

**And the silence has been observed on silicon with the RTL proven good.** On
run 47 a real DIR stall (21.5 s, storage continuously non-idle — `op_wd[31]`
fired, and `op_wd` hard-resets on `S_IDLE`) produced **zero** D-lines with the
GUI attached and the link demonstrably live (13 keystrokes captured, including
the `D`-`I`-`R`-`Enter` scancodes `23/43/2D/5A`). A `tb_uart_link` test then
emitted exactly the four predicted `D09` lines from the *same* RTL. So the
board-side silence is downstream of `jmr_uart_link`, and as of run 48 remains
unexplained; the leading suspect is a TX-stream freeze during the stall.

**Operational rule: prove the instrument before trusting a reading from it.**
At an idle READY prompt you should see `STOR-BEAT state=0x00` and periodic
V-lines. If those are absent, the telemetry is dead and any conclusion drawn
from its silence is worthless. That single check would have saved most of
2026-08-27.

### What BOARD still cannot do

No `VMSTAT`, no heap/object slot peeks (counts yes — H-line; contents no), no
per-state profile, no live executed-IP replay (the T-line ring is 8 entries,
latched only at fault). Run 60 moved "why" a long way onto the board — the
F-line names the allocator and shows the pools — but anything needing slot
*contents*, `vobj_next`, or `vfree_ok` must still be reproduced in **FPGA-SIM**;
`functional_model/machine.py` has no object pool and no fault handling at all,
so PYTHON cannot reproduce a capacity fault by construction.

Widening the V-line is an RTL change and costs a full rebuild (~1h50m). Decide
that deliberately, not reflexively.

---

## Case: stale card looks like a VM bug

On 2026-08-26 a PACMAN bug that had survived timing closure, a DDR3 cache A/B,
and three bitstreams was identified in one reading of the board's own
telemetry: **`fault 3` at `ip 263`**. Before the V-line existed the same bug
presented as "the screen stops and nothing happens."

That is the entire case for this tier. On silicon there is no debugger, no
`printf`, and no waveform. Either the design reports its own state or the
failure is a black box. Everything below is what the machine can currently say
about itself, and — just as important — what it **cannot**.

**How that case closed (2026-08-27).** `fault 3` was correct and led straight
to the answer: PACMAN's old `Map.prototype.finder` allocated ~36 heap objects
per call (a `Array(31).fill(0).map(...)` grid plus an `Object.assign` options
object), four ghosts per frame, against 284 free object slots. The fix — a
non-allocating one-step chase writing into a single reused `_gs` object — was
already committed, but **`card.img` had been minted 18 minutes earlier**, so
the board kept running the unfixed program. Rebuilding the card resolved it.
See [GAME_DESIGN.md § rule 5](GAME_DESIGN.md) for the allocation numbers and
[FPGA_BRINGUP.md](FPGA_BRINGUP.md) for the stale-card check.

Two lessons worth carrying, because both cost real time here:

- **The fault code told the truth immediately.** Every hour spent on timing
  closure, the DDR3 read cache and the flash path was spent *before* anyone
  read it, and none of those were the cause.
- **Telemetry cannot see a stale artifact.** The board faithfully reported a
  genuine `fault 3` in a program that had already been fixed. Verify what the
  board is actually running before trusting any comparison against sim.

---

## Traps that made the monitor lie

- **VM capacities must be imported** from `hardware_model.js_vm` (which mirrors
  `rtl/engines/jmr_js_vm_pkg.sv`), never typed in — the T200 fit moved
  `MAX_OBJ`, `ENV_DEPTH`, and `CODE_WORDS`, and every hardcoded copy went stale.
- **`CALL_NATIVE` arg0 is a name-table index in a Chunk / decoded
  `ProgramImage`, but a `NATIVE_IDS` id in the packed word image.** Resolving a
  Chunk arg0 through `NATIVE_IDS` prints the wrong native. Likewise
  `LOAD_VAR`/`STORE_VAR`/`LET_VAR` arg0 indexes `names` in a Chunk but
  `var_names` in the word image; `CALL_USER`/`MAKE_FN`/`JUMP` arg0 is a code
  address.
- **New sim probes must be listed in `sim_backend._OPTIONAL_VERBS`.**
  `sim/sim_main.cpp` ends its command loop with a bare `ERR`, so an unknown verb
  costs one line and never hangs — but an unlisted verb makes `_rpc` fault-log
  every refusal and buries the real fault in the flight log.
- **The Keyboard (`PHY_PS2`) block never blinked** (2026-08-29) because its
  only heat source was `_reg_states` matching the RTL's `S_KEYEV`/
  `S_FRAME_KEY` dispatch state — a single-cycle state a ~0.67s board V-line
  heartbeat is very unlikely to ever sample. On PYTHON/FPGA-SIM the same gap
  existed, just less visibly (per-op VMSTAT samples faster, but still not
  every cycle). Fixed with two stamps that merge, because no single side
  sees all keyboards:
  - **GUI side** (`gui_jmr_js.py`): `self._kbd_last_t` on every key
    press/release except GUI chrome (F9/F10) — same semantic as the
    board's K-line, connector-level activity. Deliberately NOT gated on
    `backend.key_event` existing: `BoardBackend` has no `key_event`, so
    that gate would have left BOARD dark — the very runtime the gap was
    reported on.
  - **BOARD side** (`runtime/board_backend.py`): the tether `K`-line
    stamps `_kbd_last_t` and `arch_snapshot()` reports it — the board's
    own keyboard never passes through the GUI, so GUI events can't see it.
  `_update_arch_monitor` merges the two (newest wins) into
  `snap["kbd_last_t"]`; `ArchitectureView.update()` feeds it into the same
  `_heat_stamp`/decay every other block uses, refusing to move the stamp
  backwards (a stale feeder must never regress live heat). Verified
  end-to-end headless (fake-serial K/H/F/T/V/S/P streams + real Tk App
  under xvfb): 60 checks, plus the 222-test fast gate.

---

## Related

- [FPGA_BRINGUP.md](FPGA_BRINGUP.md) — the tether cable, ports, and board tiers
- [ARCHITECTURE.md](ARCHITECTURE.md) — what the monitor is looking at
- [TIMING_WALL.md](TIMING_WALL.md) — run ledger; run 46 is the clean-timing bit
