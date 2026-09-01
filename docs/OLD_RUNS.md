# Old Vivado deaths (taxonomy, not a diary)

Words: [README.md — Words used](../README.md#words-used-in-this-project).

**Not the agent brief.** Live numbers: [FPGA_FIT.md](FPGA_FIT.md).
Glass / failed-fix: [SESSION_HANDOFF.md](SESSION_HANDOFF.md). Glass
suspects from Port A: [VIVADO_FLATTEN_HUNT.md](VIVADO_FLATTEN_HUNT.md).

**Three different deaths** (do not treat them as one bug):

| Failure | Tell | What to do |
|---|---|---|
| **70 GB hang** | One process, log frozen, RSS climbing toward ~80 GB | `mem[i] <=` in the VM state machine → RAM became flip-flops. **Fixed** (Port A). Do not “fix” glass by putting those writes back |
| **Mapping OOM** | `tcmalloc large alloc`, process killed | Fat netlist and/or too many workers. Synth stays **2** threads |
| **Place UTLZ-1** | synth OK, place DRC fails | BRAM oversub → LUTRAM demotion → LUT blowup. [FPGA_FIT.md](FPGA_FIT.md) |

Do not resume mid-mapping. There is no DCP until `synth_1` is 100%.
**`bit-fresh`:** never after a mapping *crash*; **yes** after a source
file-*list* change. Full hygiene: [SESSION_HANDOFF.md](SESSION_HANDOFF.md)
§ Synthesis.

Hour-by-hour tables are git history (`git log -- docs/OLD_RUNS.md`).
