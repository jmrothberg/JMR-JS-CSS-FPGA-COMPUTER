# FPGA versions

- **Load now:** [current/README.md](current/README.md), run73o, November 2, 2026. The owner flashed QSPI and reports that it runs fine.
- **First rollback:** [archive/run72b-2026-10-26/README.md](archive/run72b-2026-10-26/README.md), the previous board-proven standard.
- **Earlier keepers:** [archive/README.md](archive/README.md). Each version has its own explanation and checksums.
- **Optional porting example:** [extras/README.md](extras/README.md). No ZIP is required to use the faster FPGA.

`current/fpga.bit` always points to the selected version. [standard.json](standard.json) records that selection and its exact files. Keep the versioned filename beside the alias.
Your existing card and `LOAD "NAME.HTML"` / `RUN` workflow remain the same.

Use this existing repository on `main`. Save older versions in these folders; do not create branches, extra repositories or worktrees to save a release. Raw failed experiments belong in [build/archive/](../build/archive/README.md), not in `current/`.
[ORGANIZATION.json](ORGANIZATION.json) records file moves and unchanged hashes. Old file paths have compatibility links.
