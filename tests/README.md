# tests/

`pytest` suite for the compiler, the Python model, the tools, and some RTL
modules through Verilator. Run from the repository root:

```sh
.venv/bin/python -m pytest -q
```

The full-machine checks on the RTL live in `sim/`, not in pytest. The list is [sim/README.md](../sim/README.md).
