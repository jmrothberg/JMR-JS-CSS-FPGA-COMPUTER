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
> visible. The board sends three numbers.

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

No `VMSTAT`, no heap/object peeks, no IP ring, no per-state profile. The board
reports *that* it stopped, its state, and *where* — not *why*. Anything needing
`vobj_next`, `vfree_ok`, or the object pool must be reproduced in **FPGA-SIM**;
`functional_model/machine.py` has no object pool and no fault handling at all,
so PYTHON cannot reproduce a capacity fault by construction.

Widening the V-line is an RTL change and costs a full rebuild (~1h50m). Decide
that deliberately, not reflexively.

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
  every cycle). Fixed at the GUI layer instead of the RTL layer: `gui_jmr_js.
  py` now stamps `self._kbd_last_t` on every key that actually reaches
  `backend.key_event(...)`, passes it through `arch_snapshot()`'s consumer as
  `snap["kbd_last_t"]`, and `ArchitectureView.update()` feeds it straight into
  the same `_heat_stamp`/decay mechanism every other block already uses — so
  it blinks on every real keypress, on every runtime, with no RTL change and
  no dependency on catching a fleeting dispatch state.

---

## Related

- [FPGA_BRINGUP.md](FPGA_BRINGUP.md) — the tether cable, ports, and board tiers
- [ARCHITECTURE.md](ARCHITECTURE.md) — what the monitor is looking at
- [TIMING_WALL.md](TIMING_WALL.md) — run ledger; run 46 is the clean-timing bit
