# Agent paste

You get three docs. Do not duplicate them.

| Doc | Job |
|---|---|
| Plan | Steps. PYTHON glass first, then FPGA-SIM. |
| `docs/SESSION_HANDOFF.md` | What the user actually saw. |
| `docs/JMR_JS_COMPATIBILITY.md` | Value ABI + Complete/TBD surface. Chrome does not count. |

Also: `CONSTITUTION.md`, `.cursor/rules/`.

## Now

User F9 PYTHON: INVADERS, PACMAN, DONKEY play. Lockstep FPGA-SIM RTL toward that Python (same ProgramImage). Rebuild the RTL sim binary before F9 FPGA-SIM. No `.bit`/`.bin`. Never declare BOARD/ASIC done yourself.

## Rules

- HTML RUN = serialized `FLAG_VALUE64` words on `JsHwVm`. Not dukpy, not `JMR_SIM_HOST=1`, not Chunk `VM.run()`.
- Missing JS → port from `functional_model/bytecode.py` into `hardware_model/js_vm.py`. General language, no title `if`s.
- Python vs RTL → fix RTL. Headless title checks must include **pixels**, not only fields/`raf`.
- Traces first (`traces/*_PYTHON.log`, start at the **end**). Do not relaunch the GUI to rediscover a blank screen.
- `RUN` compiles loaded HTML. No `.JSH` as product input. Full ASET. No `.bit`/`.bin`. No deletes. No title HTML rewrites. Surgical edits. Keep comments.
- **SRAM RTL:** FPGA-SIM is the same `.sv` as the chip. No 2-D combo heaps
  (`for (k) vobj_key[h][k]` in `always_ff` unrolls — not N clocks). 1-D,
  address / we / rdata-next-cycle, 1–2 ports. **Depth must fit leftover BRAM**
  after dual FB (~1 MB class). Legal: `MAX_OBJ=1024` / `MAX_ARR=512` /
  `ARR_CAP=128` / `ENV_DEPTH=512` as 1-D `venv_slot` (PYTHON matches). Not
  7 MB sim-sized depths.   No 2-D `venv_val[h][k]`. No nested `bus[a:b][c:d]`. No
  `for (i = j; i < N)` (Synth 8-3380) and no task `for` over `ENV_DEPTH`
  (1024×1024 unroll). `vstack` is 1W1R like `vobj_slot`, not combo LUTRAM
  (Synth 8-7186). No `function automatic` peek from the unique case
  (Synth 8-660). Asset SRAM 4 MB is art, not JS heap. ~30 MHz class. See
  `docs/FPGA_FIT.md`.

## Stop

Nursery keep/delay/rewind. Silent `sp` reset. Title-name gates. Vivado/UART. Host twin. Claiming pytest or a snippet means the game works. Combo 2-D heaps / reset-for fill / `ifdef SYNTHESIS` smaller RAM. Sim-sized BRAM depths / nested `bus[a:b][c:d]` / JS heap in the 4 MB asset bank.

When you stop: what the glass did, tests that checked **pixels**, confirm no bits / no deletes / no host twin. If you need the user, it is F9 PYTHON (then later F9 FPGA-SIM `(RTL)`).
