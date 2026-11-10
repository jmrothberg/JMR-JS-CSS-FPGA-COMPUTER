# rtl/

The synthesizable computer. The simulator and the board build compile these same files.

| Path | What it is |
|---|---|
| `jmr_js_core.sv` | The machine. Top module of the simulator. |
| `top_nexys_video.sv` | Nexys Video board shell around the core. |
| `engines/` | VM, loader, storage, graphics, Toolbox primitives. |
| `video/` | HDMI scanout and overlays. |
| `phys/` | Keyboard, mouse, joystick, SD card and audio interfaces. |

- Every module, one line each: [docs/RTL_REORG.md](../docs/RTL_REORG.md)
- Coding rules: [docs/RTL_DESIGN_PRINCIPLES.md](../docs/RTL_DESIGN_PRINCIPLES.md)
- Pins and timing constraints: [constraints/README.md](../constraints/README.md)
- Simulator: [sim/README.md](../sim/README.md). Board build: [docs/FPGA_FIT.md](../docs/FPGA_FIT.md)
