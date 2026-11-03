# run71c — historical keeper

Earlier run71c: CSR-read and LIST-parser timing work with big-file transfer support. The filename records +0.311 ns setup; this cleanup did not requalify it.
Use this only to investigate behavior specific to that old version. The preferred rollback is [run72b](../run72b-2026-10-26/README.md); current disk/protocol compatibility is not established for this earlier keeper.

To try this historical bit until power-off, from the repository root:

```bash
openFPGALoader -b nexysVideo 'releases/archive/run71c-earlier/run71c_csr_parser_cones_bigput_WNS+0.311.bit'
```

The matching `.bin` is preserved for history. Use `.bit`, not `.bin`, for programming. `SHA256SUMS` verifies unchanged original bytes. Original engineering notes remain under `build/archive/older-implementation-runs/`.
[Current version](../../current/README.md).
