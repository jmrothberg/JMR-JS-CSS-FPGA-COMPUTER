# Retired tests

`test_desktop_system.py` drove the built-in (RTL) Finder desktop that commit
a831a5e retired: it booted a bare card with no Toolbox or `FINDER.JSH` and
compared pixels with `functional_model/desktop.py`. The machine now boots the
Finder program, so on that card it stops with `?NH` (no program image) and both
tests failed on build 94 and build 96 alike.

Coverage for the Finder program lives in `tests/test_finder_program.py` and the
simulator gates in [sim/README.md](../../sim/README.md): `user_loop.py`,
`alert_check.py`, `document_check.py`, `esc_check.py` and `macwrite_check.py`.
