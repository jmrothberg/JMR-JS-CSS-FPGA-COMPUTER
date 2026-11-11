# resources/system/

| File | Purpose |
|---|---|
| `system.json` | Editable source of `SYSTEM.SYS`: system font, captions |
| `defaults.json` | Source of the fallback built into the hardware. Do not edit for a card update |
| `examples/` | Alternative source files |
| `art/` | The Enterprise picture for Finder's About box. `tools/make_finder_about_art.py` builds it into `storage/FINDER-0.png` |

```sh
python3 tools/build_system_resources.py --image card.img
```

Fields, limits and the binary format:
[docs/SYSTEM_RESOURCES.md](../../docs/SYSTEM_RESOURCES.md).
