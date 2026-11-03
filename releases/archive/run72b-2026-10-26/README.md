# Run72b — first rollback choice

This was the October 26, 2026 standard, reported working on the board before run73o. It uses a 14.286 MHz JavaScript VM and preserves full game features. Original timing: setup +0.238 ns / hold +0.050 ns; 92,273 LUTs / 28,583 slices / 353.5 BRAM.

From the repository root, try it until power-off:

```bash
openFPGALoader -b nexysVideo 'releases/archive/run72b-2026-10-26/run72b_game_speedup_WNS+0.238.bit'
```

For a persistent rollback, flash it and reload the application:

```bash
openFPGALoader -b nexysVideo -f 'releases/archive/run72b-2026-10-26/run72b_game_speedup_WNS+0.238.bit'
openFPGALoader -b nexysVideo 'releases/archive/run72b-2026-10-26/run72b_game_speedup_WNS+0.238.bit'
```

JP4 = QSPI. Keep your existing compatible card; `run72b_card.img` is the original matching disk if you need to restore a fresh card. Do not burn a disk image merely to change the FPGA version. Continue loading `.HTML` then `RUN`.

[standard.json](standard.json) and `run72b_reports.zip` preserve the original release evidence. `ORIGINAL_RELEASE_NOTES.md` keeps the longer historical notes. Verify this folder with `sha256sum -c SHA256SUMS`.
Return to the latest version using [../../current/README.md](../../current/README.md).
