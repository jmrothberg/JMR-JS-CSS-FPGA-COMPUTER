# RTL design rules

The one place for RTL coding rules. Read it before writing RTL. Where modules live: [RTL_REORG.md](RTL_REORG.md). Resource limits, build commands and build lessons: [FPGA_FIT.md](FPGA_FIT.md). Terms: [WORDS.md](WORDS.md).

## Never do this

### Memory

| Never | What breaks |
|---|---|
| Write `mem[i] <= x` on a large array inside the big VM state machine | The array becomes flip-flops. Synthesis can run out of memory. Use the write tasks (`stack_wr`, `vobj_alloc_wr`, …), which only set strobes. |
| Trust `ram_style = "block"` | It is a request. If the code shape does not fit a RAM, the tool builds flip-flops or LUT RAM and the tests still pass. Read the synthesis memory report. |
| Write one RAM from two statements, or twice in one clock | Not a single write port. Merge to one write with muxed address, data and enable, or take an extra clock. |
| Use a registered RAM read in the same clock as its address | You get the previous word. Address this clock, data the next. An address gated by a flag set on that same beat also reads the old word. |
| Reset or clear a whole RAM in one clock, or put a reset inside the RAM process | Block RAM inference fails. Clear with a strobe, one word per clock. |
| Mix blocking `=` and non-blocking `<=` in one clocked block | Bad inference. |
| Index big unpacked arrays combinationally from a `unique case` | Every arm becomes a read port: a giant mux. |
| Give a submodule its own copy of a heap array (`vvars`, `stack`, `vobj_*`, …) | A second heap. It does not fit and it goes stale. A control-only submodule is allowed in the `u_exec64` shape: no arrays, scalar ports, data back on the next clock. |
| Split `jmr_js_vm.sv`, or `` `include `` arms of its `always_ff` | Splitting JOIN, JSON, GC or the heap makes a second heap or an illegal RAM port. An include hides the one-process RAM shape and saves nothing. |
| Skip the generation check on an object handle | Silent use of a recycled object. |
| Move the heap or the draw canvas to external memory | Each access then pays the DDR3 round trip. Only the front image and cold data live there. |
| Raise the capacity constants in `jmr_js_vm_pkg.sv` without a measured plan | Does not fit. Some are language contracts: operand window depth bounds expression nesting. |

### Logic and timing

| Never | What breaks |
|---|---|
| Leave a declared net undriven | Synthesis treats it as don't-care and can prune live logic. Simulation reads it as zero, so the tests pass. Vivado warning `Synth 8-3848` must be zero. |
| Pass a signal between modules on the 100 MHz clock without a register | The path crosses the chip through both modules' logic and misses 10 ns. Register it at the boundary. |
| Feed a state decode from a wide compare or reduction | The compare lands in front of the whole next-state cone. Take the compare from a register. |
| Let a 100 MHz register reach a VM register through logic | The path gets 10 ns, not the VM's 30 ns. Land the signal in a plain register first and use it on the next beat. |
| Slow the 100 MHz clock to fix a path inside the VM | Scanout and DDR3 need 100 MHz. The VM has its own divided clock (`VM_CLK_DIV`). |
| Write a loop whose test depends on the previous iteration's result | It cannot be flattened: one logic level per iteration. Use a priority encoder plus one barrel shift. A loop that tests fixed bits of an unchanging input is fine. |
| Write `/` or a wide `*` outside a registered stage | A combinational divide is one of the deepest structures there is. Make it sequential. Hoist a per-row value out of the per-pixel path. |
| Wait on an external response with no timeout | One dropped reply freezes everything above it. |
| Assume a `for` loop is sequential | It unrolls into parallel hardware. Sixteen iterations writing an array are sixteen write ports. |

### State machines

| Never | What breaks |
|---|---|
| Enter a parent VM state from `u_exec64` without a first-entry beat | The arm reads registers nothing wrote, or a RAM word still at the previous address. Latch the seeds on arrival, stay one beat. |
| Share a cursor or scratch register (`bind_k`, `*_arm`) between unrelated multi-beat walks | One walk wipes the other's place. The symptom depends on an earlier frame. Each walk resets its own cursor on entry. |
| Renumber a state enum | Telemetry and the simulator decode by number. Leave a hole. See [RTL_REORG.md](RTL_REORG.md#state-names). |
| Judge a signal live or dead by its name (`e32_` prefix) | Some serve Value64, some have no driver. Check drivers and consumers one by one. |
| Turn a same-cycle operation into a multi-cycle one without a purpose-built test | A consumer that still reads immediately gets a stale value with no fault. Write the test first and pass it on the unchanged tree. |

### Machine

| Never | What breaks |
|---|---|
| Add a soft CPU, a JavaScript interpreter, or a gate on a program's name | Not this machine. One bytecode VM; no title-specific hardware. |
| Add a file to only one of the two file lists | Simulator and board stop being the same machine. |
| Lower `SD_RUN_DIV` to load faster | The simulator's card model misses the data and every load fails. |
| Transmit on the J15 keyboard lines | [The keyboard stops](USB_KEYBOARD_PMOD_MICE.md#what-j15-cannot-do). |

## The RAM template

```systemverilog
// One dedicated process. One write port. Registered read. No reset.
always_ff @(posedge clk) begin
    if (we) mem[waddr] <= wdata;
    rdata <= mem[raddr];
end
```

The state machine sets `we`, `waddr`, `wdata` and reads `rdata` one clock later. It never touches `mem[...]`. Copy `jmr_mini_fb.sv`.

## Designing for area

- **Sequential beats parallel.** Hardware sized for one step, reused, is far smaller than hardware sized for the whole job. Prefer it unless the operation is in a per-clock hot path.
- **Wide N-to-1 funnels are the most expensive shape.** Many results converging on one register cost more than any array. Give a small hot set the direct path; send the rest down a narrower multi-cycle path.
- **Write each operation once.** One width-parameterized leading-bit finder, one RAM template, one hold-and-serve handshake. Each hand-rolled copy is more logic and another place for a bug.
- **Sharing concentrates wires.** One shared structure replaces many, and all their connections now meet in one place. After a consolidation, check congestion, not only utilization.
- **Track the scarce pool.** LUTs, LUT-as-memory, memory-capable slices, block RAM and DSPs are separate budgets. The headline percentage hides a shortage in one of them.

## Designing for speed

- **Depth and area are different.** A long carry chain is slow and small. A big array can be fast. Measure both.
- **Delay is logic plus routing.** Roughly half and half means too many logic levels: only RTL fixes it. Two logic levels and almost all routing means no room: move or shrink the crowded region, which is often a different module from the one that fails.
- **Fix the cone, not the path.** When many endpoints fail at about the same slack, they share an upstream cone. Trace fan-in from several endpoints and fix what they share. Do not diagnose from generated cell names.
- **Check what the tool built.** Read the real critical path. An area directive can turn a multiply into a ripple chain while DSP blocks sit idle.
- **Re-time after an area change.** Moving arithmetic out of a `case` saves the mux and lengthens the path.
- **A design that routes is not a design that works.** The router trades timing for legality. A bit that misses timing gives unpredictable behaviour; diagnose from the timing report, not from the board.

## Testing

- **A passing suite does not prove a structural change.** Match the test to how this change can fail.
- **Anything the simulator replaces with a model is untested.** The simulator uses `jmr_sram_model`; the DDR3 bridge, the keyboard and mouse receivers and the tether never run there. Read vendor handshakes against the specification by hand.
- **A model with a different algorithm cannot check yours.** The Python model looks names up in a dictionary; the RTL scans a table. Test the scan itself: first entry, last entry, full table.
- **Measure before and after.** Source reading ranks candidates. Only the netlist says a change worked. Check the date inside a report before acting on it.
- **One change per experiment.**

## Related

- [FPGA_FIT.md](FPGA_FIT.md) — limits, build commands, build lessons
- [RTL_REORG.md](RTL_REORG.md) — module map
- [ARCHITECTURE.md](ARCHITECTURE.md) — what the machine is
- [CONSTITUTION.md](../CONSTITUTION.md) — wins on conflict
- `.cursor/rules/never-fake-fpga-sim.mdc`, `one-heap-keep-gen.mdc`, `no-game-hardwire.mdc`
