# Current FPGA: run73o — November 2, 2026

**Use `releases/current/fpga.bit`.** It points to `run73o_native_js_speed_WNS+0.000.bit`.
The owner flashed this version to QSPI with openFPGALoader and reports that it runs fine on the Nexys Video board. No extra flash is needed because files were reorganized.

From the repository root, load it until power-off:

```bash
openFPGALoader -b nexysVideo releases/current/fpga.bit
```

To keep it after power-off, write QSPI and then load the application immediately:

```bash
openFPGALoader -b nexysVideo -f releases/current/fpga.bit
openFPGALoader -b nexysVideo releases/current/fpga.bit
```

Set JP4 to QSPI for boot from flash. The flash helper can leave a blank screen until the second command, PROG, or a restart. Use `sudo` for these commands only if USB permissions require it.

**Keep your existing card.** At READY, use `LOAD "PACFAST.HTML"` then `RUN`, or load your other existing `.HTML` files the same way. The FPGA loads `.bit`; the computer loads `.HTML`. No ZIP or new Donkey Kong package is required.

This release improves the general JavaScript engine: 33.333 MHz VM instead of 14.286 MHz, pipelined exact arithmetic, corrected method caching and more efficient graphics/memory transfers. The benchmark games were unchanged. Simulated median processing gains over run72b are 2.005× Pac-Man and 2.307–2.356× Donkey Kong; gains vary by program/frame. HDMI remains 60 Hz; numeric board FPS is not measured.

579 distinct tests pass. Final routing, setup/hold/pulse timing and DRC-error gates pass: setup 0.000 ns rounded (no extra setup margin), hold +0.040 ns. Utilization is 87,876 LUTs / 28,045 slices / 353.5 BRAM / 128 DSP. Full reports retain remaining warnings.

- `run73o_sources_and_evidence.zip`: frozen build inputs/tests; its historical paths and README predate this folder cleanup. The live repository's README is the current loading guide.
- `run73o_qualification_reports.zip`: full final timing, routing, memory-mode and DRC reports.
- [evidence/build_manifest.json](evidence/build_manifest.json): immutable build-time record. Its original "not programmed / standard unchanged" fields describe creation time, before the owner's board test and this promotion.
- `SHA256SUMS`: run `cd releases/current && sha256sum -c SHA256SUMS` from the root to verify the files.
- **Revert:** [previous run72b instructions](../archive/run72b-2026-10-26/README.md).
