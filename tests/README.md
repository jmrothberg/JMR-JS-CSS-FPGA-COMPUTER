# tests/

`pytest` suite for the compiler, the Python model, the tools, and some RTL
modules through Verilator. Run from the repository root:

```sh
.venv/bin/python -m pytest -q
```

The full-machine check on the RTL is `python3 sim/user_loop.py`, not a pytest.
