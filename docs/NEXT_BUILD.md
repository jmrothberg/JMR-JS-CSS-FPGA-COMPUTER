# Next build (build 97): items that need a new .bit

Not started. Everything here changes `rtl/` or what is synthesized into the
bitstream. Fixes that only change the card (Toolbox, Finder, programs) go out
with a new `card.img` and do not wait for this list.

| # | Item | Why it needs a .bit |
|---|---|---|
| 1 | Built-in Toolbox bank matches the card again | The card's `TOOLBOX.ROM` (scroll-arrow repeat) replaces the bank at cold start, so the run96 bit works with it. The built-in fallback bank in the run96 bit is the older Toolbox; the next synthesis picks up `vectors/toolbox_code*.hex` automatically. |
| 2 | Larger resident Toolbox bank | 8,189 of 8,191 words are used (after scroll-arrow repeat and multi-line About). Growing it means a bigger bank in `jmr_js_vm.sv` and the linker's `MUTABLE_WORDS`. Waiting on room: (a) per-command file types for Open dialogs, as the Mac's file-type list, e.g. `tbSessionOpenTypes(163,"DAT")`, so TRS-80 BASIC's File > Open lists only `.BAS` and Tape > Open only `.DAT`, and Save As adds `.BAS`; (b) held-button repeat in the chooser list's scroll bar. Either can also ship on a card without a new bit if other Toolbox code is made smaller first. |
| 3 | Timing margin | Build 96 meets timing by +0.005 ns setup. The remaining paths are a flat spread (`docs/FPGA_FIT.md`, known gap 1); aim for +0.1 ns. |
| 4 | Console state decode depth | 22–24 logic levels (`docs/FPGA_FIT.md`, known gap 2). |
| 5 | Ship menu Quit | `quit_pulse` is a constant 0: either add a Force Quit or delete the dead logic. Today the way out of a hung program is three Escs. |
| 6 | Hardware math commands | Deferred by request ("not for now"): faster math natives for games. |
| 7 | Replacing a large file times out | Saving over an existing big file (PRINCE.JSH, 1.5 MB, by tether) fails with `Finder service: IO`; the same file sends cleanly after it is put in the Trash. The console's save (`C_SV_OPEN` in `jmr_console_engine.sv`) frees the old cluster chain as one storage step under the ~21.5 s `cons_prog_wd` watchdog. Free the chain in steps that count as progress (or give the tether a delete operation) so a replace works like a fresh save. Until then `tools/tether_put.py` stops and asks for the Trash first. |

When starting the build: run `python3 -m tools.toolbox_linker` first so the
bit and the card carry the same Toolbox, then follow `docs/FPGA_FIT.md`, then
`python3 tools/update_current_set.py --bit ...` (top-level README).
