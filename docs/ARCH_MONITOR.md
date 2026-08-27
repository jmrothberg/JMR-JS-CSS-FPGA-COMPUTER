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
| `D<hh>` | `stor_state` | **storage stall telemetry** |
| `V<st2><fault2><ip4>` | `{casestate, fault, ip}` | **VM heartbeat / fault** |

### The V-line — VM heartbeat

Added 2026-08-26 (`2b0f1f3`). Emitted once per dump **and on every
`machine_fault` rising edge**. Parsed by `_parse_vm_v_line`; a torn or short
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

### The D-line — storage stall telemetry

Rewritten 2026-08-26 (`5968932`). Fires after **~0.67 s of CONTINUOUS storage
busy**, then repeats every ~0.17 s carrying `stor_state`. Normal operations
idle between console strobes and never accumulate enough busy to trigger.

The previous version could **never fire** — it compared for equality on a
saturating counter, which is why the board logs showed zero D-lines. If you are
reading an old log, absence of D-lines before this commit proves nothing.

Storage state codes (`storage_engine.sv`, 103 states):

| Codes | States | Stuck in |
|---|---|---|
| `0x00` | `S_IDLE` | not busy |
| `0x02` | `S_ERR` | errored |
| `0x0B`–`0x13` | `S_MNT0`…`S_MNT3C` | **mounting the card** |
| `0x16`–`0x1C`, `0x66` | `S_DS_*`, `S_DS_CHAIN` | **root-directory scan** |
| `0x5F`–`0x65` | `S_DIR0`…`S_DIR_ADV` | **DIR itself** |

**No D-lines during a failure is itself a reading**: storage was never busy, so
the fault is not in the storage engine.

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

---

## Related

- [FPGA_BRINGUP.md](FPGA_BRINGUP.md) — the tether cable, ports, and board tiers
- [ARCHITECTURE.md](ARCHITECTURE.md) — what the monitor is looking at
- [TIMING_WALL.md](TIMING_WALL.md) — run ledger; run 46 is the clean-timing bit
