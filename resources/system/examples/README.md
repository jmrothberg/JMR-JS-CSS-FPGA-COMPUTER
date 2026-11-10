# Resource examples

Optional variants of `resources/system/system.json`. Nothing here is on the
card or in a release.

`macintosh-save.json` is a complete configuration that differs from
`system.json` in three values: the Save As prompt (label 147) and the
positions of the two `save_as` dialog buttons, which put Cancel on the left
and Save on the right.

Validate it and build a separate bundle, from the repository root:

```sh
.venv/bin/python tools/build_system_resources.py resources/system/examples/macintosh-save.json --output /tmp/macintosh-save.SYS
```

To adopt it, make the same three edits in `resources/system/system.json` and
publish with `--image card.img`. Restart the GUI, then test Save, Cancel and
the mouse hit areas. Details: `docs/SYSTEM_RESOURCES.md`.
