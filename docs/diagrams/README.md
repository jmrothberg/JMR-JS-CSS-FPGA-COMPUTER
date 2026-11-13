# Diagrams

Each diagram is an SVG with a 2× PNG beside it. Both are generated; do not edit them by hand.

| Diagram | Shows |
|---|---|
| [architecture.png](architecture.png) | The layers: Finder and applications, Toolbox calls, system services, FPGA engines |
| [memory-map.png](memory-map.png) | The 8 MiB memory map inside the 64 MiB external port, and the on-chip code banks |

Regenerate both after a change to the memory map, the code banks, the Toolbox or the programs on the card:

```bash
python3 tools/generate_architecture_diagram.py
```

Sizes, addresses, the Toolbox bank usage and the program counts are read from `functional_model/jsb_format.py`, `storage/TOOLBOX.ROM` and `storage/`. The script fails if the memory-map rows no longer match the constants. PNG export uses `cairosvg` if installed, otherwise the system librsvg (`gi`, GdkPixbuf).

The Architecture Monitor (F10) is described in [../ARCH_MONITOR.md](../ARCH_MONITOR.md); the text that goes with these diagrams is [../ARCHITECTURE.md](../ARCHITECTURE.md).
