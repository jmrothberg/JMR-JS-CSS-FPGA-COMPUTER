# Older FPGA versions — rollback only

**Use [run72b](run72b-2026-10-26/README.md) first if you need to revert.** It was the October 26 board-proven standard before run73o.

- [run72b-2026-10-26/](run72b-2026-10-26/README.md): previous standard, matching card image, original manifest and reports.
- [run71c-earlier/](run71c-earlier/README.md): earlier CSR/parser and storage fixes; older than run72b.
- [run71b-earlier/](run71b-earlier/README.md): earlier thin build; retained for a specific historical regression.

Each folder keeps the original binary bytes and its own `SHA256SUMS`. `.bin` files are secondary history; use `.bit` with openFPGALoader. Filenames alone do not freshly qualify an older build.
The [current version](../current/README.md) remains separate. Failed development candidates and Vivado checkpoints are preserved under [build/archive/](../../build/archive/README.md), not offered here as working releases.
