# Agent paste

You get three docs. Do not duplicate them.

| Doc | Job |
|---|---|
| Plan | Steps. PYTHON glass first, then FPGA-SIM. File: `/home/jonathan/.cursor/plans/working_html_fpga-sim_a719ac28.plan.md` — open and follow it. |
| `docs/SESSION_HANDOFF.md` | What the user actually saw. |
| `docs/JMR_JS_COMPATIBILITY.md` | Value ABI + Complete/TBD surface. Chrome does not count. |

Also: `CONSTITUTION.md`, `.cursor/rules/`.

## Now

User F9 PYTHON: INVADERS, PACMAN, DONKEY play. Lockstep FPGA-SIM RTL toward that Python (same ProgramImage). Rebuild the RTL sim binary before F9 FPGA-SIM. No `.bit`/`.bin`. Never declare BOARD/ASIC done yourself.

## FPGA-SIM must stay `.bin`-legal

FPGA-SIM and `make -C tools/board_flow bit` compile the **same** `rtl/*.sv`.
Debugging a title in Verilator must **never** add a pattern that Vivado cannot
turn into a `.bin` (combo megabit mux, sim-only heap, `unique case` on the
opcode switch). Details: `docs/FPGA_FIT.md` and `.cursor/rules/never-fake-fpga-sim.mdc`.

**Do not (these are what blow the bitstream):**
- 2-D heaps / `for (k) if (mem[h][k]==key)` inside `always_ff` (unrolls; Synth 8-4556 / LUTRAM / WNS)
- Reset `for` that writes every SRAM cell in one cycle
- `` `ifdef SYNTHESIS `` smaller heap, combo sim vs BRAM board, Xilinx `RAMB36` inside the VM
- Sim-sized depths (`MAX_OBJ=8192` class ≈ 7 MB). Legal leftover-BRAM: `MAX_OBJ=1024`, arrays `1536×32`+`128×128`, `ENV_DEPTH=512`. Same caps in PYTHON. Overflow loud.
- JS heap in the 4 MB ASET SRAM, or bumping that bank to hide the heap
- Nested part-select `bus[a:b][c:d]` (Synth 8-2599)
- `for (i = j; i < N)` (Synth 8-3380); nested `for` over `ENV_DEPTH`
- Combo/multi-port `vstack` (Synth 8-7186); `function automatic` TOS peek (Synth 8-660)
- **`unique case` on the giant opcode switch or `nat_id`/`nid` switch** — Vivado builds every arm in parallel (~100 GB, hours, no `.bin`). Those two are plain `case`. Small `unique case`s (`state`, `trail_ph`, …) stay.

**Do:** 1-D memories, address / we / registered rdata, 1 write + 1–2 reads, slot scans over clocks. Extra GET_PROP clocks are real silicon. Host twin (`JMR_SIM_HOST=1`) is not FPGA-SIM.

Do **not** run `make -C tools/board_flow bit` until the user F9-approves FPGA-SIM. That is not permission to write unsynthesizable RTL in the meantime.

## Rules

- HTML RUN = serialized `FLAG_VALUE64` words on `JsHwVm`. Not dukpy, not `JMR_SIM_HOST=1`, not Chunk `VM.run()`.
- Missing JS → port from `functional_model/bytecode.py` into `hardware_model/js_vm.py`. General language, no title `if`s.
- Python vs RTL → fix RTL. Headless title checks must include **pixels**, not only fields/`raf`.
- Traces first (`traces/*_PYTHON.log`, start at the **end**). Do not relaunch the GUI to rediscover a blank screen.
- `RUN` compiles loaded HTML. No `.JSH` as product input. Full ASET. No `.bit`/`.bin` until F9. No deletes. No title HTML rewrites. Surgical edits. Keep comments.
- FPGA-SIM RTL **is** the `.bin` RTL. Never “fix” a title with Verilator-only memories, combo heaps, sim-sized depths, heap-in-ASET, or `unique case` on the opcode/`nat_id` switches. See **FPGA-SIM must stay `.bin`-legal** above.

## Stop

Nursery keep/delay/rewind. Silent `sp` reset. Title-name gates. Vivado/UART. Host twin. Claiming pytest or a snippet means the game works. Combo 2-D heaps / reset-for fill / `ifdef SYNTHESIS` smaller RAM. Sim-sized BRAM depths / nested `bus[a:b][c:d]` / JS heap in the 4 MB asset bank.

When you stop: what the glass did, tests that checked **pixels**, confirm no bits / no deletes / no host twin. If you need the user, it is F9 PYTHON (then later F9 FPGA-SIM `(RTL)`).
