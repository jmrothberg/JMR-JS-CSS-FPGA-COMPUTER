# constraints/

Vivado constraints for the Nexys Video board build. `tools/board_flow/vivado_build.tcl` adds both files. The simulator does not use them.

| File | What it is |
|---|---|
| `nexys_video.xdc` | Pins, clocks, timing exceptions and placement for `top_nexys_video`. |
| `native_argument_pipeline.xdc` | One timing rule for the VM: native-call argument registers get two VM clock periods. Applied after synthesis only, last in order. |

What `nexys_video.xdc` contains:

| Section | Content |
|---|---|
| Clock and reset | 100 MHz board clock (R4), CPU RESET (G4), BTNC (B22) |
| PROG tether | FT245 data and control pins |
| LEDs | LD0–LD7 |
| HDMI | Source jack pins; clock-generator placement |
| Keyboard, mice, joystick | J15, Pmod JA, JC, JB — see [docs/USB_KEYBOARD_PMOD_MICE.md](../docs/USB_KEYBOARD_PMOD_MICE.md) |
| Audio | Codec pins; the rules for the VM-to-audio clock crossing and the audio reset |
| µSD | Card pins |
| VM clock | `vm_clk` declared as a generated clock: 100 MHz divided by 3 |
| DDR3 | Calibration-done false path; the memory bridge held in one clock region. DDR3 pins come from `tools/board_flow/mig_a.prj`. |
| Synthesis strategy | Loader, Toolbox primitives and storage are mapped for timing; the rest for area |

A pin must match the port name in `rtl/top_nexys_video.sv`. Probe designs under `tools/` have their own `.xdc` files.
