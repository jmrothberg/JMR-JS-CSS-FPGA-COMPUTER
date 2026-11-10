# Diagrams

Each diagram is an editable SVG with a PNG beside it for viewing.

| Diagram | Shows | Made by |
|---|---|---|
| [rarchitecture.png](rarchitecture.png) | The layers: Finder and applications, Toolbox calls, system services, FPGA engines | `tools/generate_architecture_diagram.py` |
| [memory-map.png](memory-map.png) | The 8 MiB external memory ranges, and how Toolbox addresses map onto them | `tools/generate_architecture_diagram.py` |
| [system-sys.png](system-sys.png) | How `SYSTEM.SYS` is loaded and used | Not generated; edit the SVG |
| [listener_table.png](listener_table.png) | The 16-slot `addEventListener` table | Not generated; edit the SVG |

To regenerate the first two (SVG and PNG at 2×):

```bash
pip install -r requirements.txt
python3 tools/generate_architecture_diagram.py
```

The text that goes with them: [../lastrun_ARCHITECTURE.md](../lastrun_ARCHITECTURE.md).
