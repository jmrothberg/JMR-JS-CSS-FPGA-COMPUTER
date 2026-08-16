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

## Stop

Nursery keep/delay/rewind. Silent `sp` reset. Title-name gates. Vivado/UART. Host twin. Claiming pytest or a snippet means the game works.

When you stop: what the glass did, tests that checked **pixels**, confirm no bits / no deletes / no host twin. If you need the user, it is F9 PYTHON (then later F9 FPGA-SIM `(RTL)`).
