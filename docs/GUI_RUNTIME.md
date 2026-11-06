# One matched GUI runtime

Start the normal GUI with `python3 gui_jmr_js.py`. Its active selection is recorded
in `runtime/active_gui.json`; `tools/gui_runtime.py` checks the selected Python
model, Toolbox resources and RTL simulator before starting. A mismatch is an
error, not a silent fallback to older code.

PYTHON executes the same serialized `.JSH` programs and resident Toolbox used by
FPGA-SIM. F9 switches backends. Both use the same selected writable disk.
`JMR_CARD_IMG` can explicitly select another image, but its ROM, linker and system
resources must match. Existing disks and user saves are never replaced by the
GUI launcher. `storage/` is the disk-builder seed, not a second runtime library.

The Python model reproduces program-visible behavior; it is not cycle-accurate
and its wall-clock speed or audio scheduling is not FPGA timing evidence. The
RTL simulator exercises the hardware implementation. Board acceptance additionally
requires the matching qualified bitstream and physical testing. An older bitstream
does not acquire new native operations merely by receiving a new disk.

Current GUI verification is recorded under
`build/run81_mac_native/gui_parity/`: actual Tk startup, exact serialized native
fixture results, framebuffer/scanout comparisons and matched-input hashes.
