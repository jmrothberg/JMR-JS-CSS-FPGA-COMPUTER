# Resource examples

`macintosh-save.json` is a complete run75 configuration with a Macintosh-inspired
Save As prompt and Cancel-left / Save-right arrangement. It retains Chicago,
rounded buttons and the default-button outline. This is an optional example;
it has not replaced the current disk or release resources.

From the repository root, validate and create a separate bundle:

```sh
.venv/bin/python tools/build_system_resources.py resources/system/examples/macintosh-save.json --output /tmp/macintosh-save.SYS
```

To adopt it, make the three corresponding edits in `resources/system/system.json`
(prompt 147 and the two save_as button positions), then publish normally with
`--image card.img`. Reopen Python/FPGA-SIM. Test Save, Cancel and mouse hit areas.
See `docs/SYSTEM_RESOURCES.md`. Which bit is loaded is `docs/FPGA_FIT.md`.
