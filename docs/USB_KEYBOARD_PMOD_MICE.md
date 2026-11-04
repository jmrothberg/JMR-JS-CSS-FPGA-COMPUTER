# Keyboard, mice, and the joystick

Current plugs. `rtl/top_nexys_video.sv` uses them when `USB_MOUSE=0`. Turn the board off before moving a plug.

| Plug | Device |
|---|---|
| **J15** | USB keyboard. The PIC24 forwards one device, listen-only. The FPGA pins are clock `W17` and data `N13`. |
| **JA** | PS/2 mouse. Data is pin 1 (`AB22`). Clock is pin 3 (`AB20`). Ground is pin 5. 3.3 V is pin 6. |
| **JC** | Second PS/2 mouse. Data is pin 1 (`Y6`). Clock is pin 3 (`AA8`). Same power pins. |
| **JB** | I2C joystick. SCL is pin 1 (`V9`). SDA is pin 2 (`V8`). With no stick the read NACKs and those bits stay 0. |

A keyboard on JA uses the same two signal pins as the mouse, 1 and 3. An earlier keyboard sat on pins 1 and 2. Do not put a keyboard on JB.

Looking into a Pmod socket, the top row is holes 1–6 with hole 6 at the far left: hole 6 is 3.3 V, hole 5 is ground, hole 1 is at the right. The bottom row is holes 7–12. The other signal pins, from the Nexys Video XDC, are JA2 `AB21`, JA4 `AB18`, JB3 `V7`, JB4 `W7`, JC2 `AA6`, JC4 `AB8`.

Power a Pmod PS/2 adapter with the jumper **VB to VCC** (3.3 V from the board). **VE to VCC** leaves the keyboard dark unless something else feeds 5 V to VE. Match the stick's labels (G, V, SDA, SCL), not the wire colors. Do not use JXADC. Never put 5 V on an FPGA pin.

`USB_MOUSE=1` is the older bitstream: mouse on J15, keyboard on JA, second mouse off. `JC_MOUSE=0` removes the JC mouse. A pin change needs a new board build.

## Two mice, one pointer

JA and JC each start on their own. Either mouse moves the pointer. Movements from both are applied. Buttons are combined, so a quiet second mouse cannot release a button the first mouse is holding. Mouse lines are driven low or left to float. The FPGA never drives the USB keyboard lines. In this configuration the JA keyboard decoder stays in reset.

The product uses the three-byte mouse host. The probe's wheel parser is not copied in. Both hosts share the existing pointer FIFO. The mouse does not feed `joy()`.

`ps2_rx.parity_err` is **1 when the byte is valid**. The name is backwards. The product top uses the strobe and the scancode. Accepting a byte only when `parity_err` is 0 throws away every good byte. That is why an early probe looked dead on every port.

## What J15 cannot do

The PIC24 turns one USB device into PS/2. The FPGA does not receive raw HID reports. The reports it does translate are a 3-byte boot mouse, the common 4-byte wheel mouse, and an 8-byte boot keyboard (modifiers plus six keys). Digilent documents one keyboard or one mouse. Nexys 4's manual states the same limit: boot HID only. The PIC24 enumerates when it enters application mode after DONE. Power-cycle with the dongle already in J15 and HDMI unplugged, then program the FPGA.

- A **wireless keyboard** dongle usually stays in a vendor report. This PIC24 never sends `SET_PROTOCOL`, so it cannot ask for the 8-byte boot report. The usual result is one letter, then silence. A wireless **mouse** dongle that still speaks the boot mouse does move the cursor. Digilent's reply on a Logitech K400r is [forum 5060](https://forum.digilent.com/topic/5060-trying-to-interface-wireless-keyboard-nexys4/). A keyboard's own BIOS / 6KRO chord, set before it is plugged in, is the only lever. The FPGA cannot send that chord. Do not pull `ps2_clk` low while listening. That silences this PIC24.
- A **hub or splitter** does not add a second device. The PIC24 has no hub driver.
- **One USB device that is both a keyboard and a mouse does not work.** On 2026-10-26, `USB_MOUSE=1` (`build/mouse_usb_20261026/jmr_nexys_video_usb_mouse.bit`) replaced the J15 keyboard decoder with a mouse host and tied the keyboard outputs to zero. The keyboard that had been working stopped. The build met timing. That did not prove a combined device. A mouse by itself on J15 does work: on 2026-11-02 the probe showed the cursor, both buttons, and the wheel.
- The custom Macintosh board forwards both reports with a CH9350L and a Lattice image. That image is not firmware for this PIC24. A new bitstream cannot make the PIC24 forward both functions. Keep the J15 keyboard decoder. Two decoders, or a test that injects keys in the GUI, does not show that both reports arrived.
- A **passive USB-to-PS/2 adapter** works only when that mouse itself speaks PS/2.
- **Caps Lock stays dark.** The keyboard lights that LED only after the host sends `ED` and a mask. This path only listens. A letter on the glass is the test.
- **Unplug HDMI** before power-cycling the keyboard. HDMI back-feeds 5 V, so the keyboard never resets and the PIC24 does not enumerate it again. LD14 blinking fast means the PIC24 saw HID. LD14 on with no PS/2 clock means a device this PIC24 does not translate. Use a wired boot-protocol keyboard, plugged in before power, in the USB Host jack (not PROG, not UART).

A key on the wire is PS/2 Set 2, device to host: start `0`, eight data bits LSB first, odd parity, stop `1`. A is `1C`, then B `32` through Z `1A`. Digits 0–9 are `45 16 1E 26 25 2E 36 3D 3E 46`. `F0` then that byte is the break. `E0` marks an extended key (arrows are `E0 6B/75/74/72`). `E0 F0` is an extended break. `FA`, `AA`, `AB`, `83` are keyboard ack and ID. A mouse sends `FA`, `AA`, `00`. A wheel mouse then answers `03`. A wheel notch is byte `FF`. Frame a packet on the gap between bytes, or `FF` is read as a new position.

## Probes

These bits only check a jack. They are not the machine. Do not add `tools/mouse_probe/`, `tools/hid_led_blink/`, or `tools/pmod_input_test/` to the JS source list. Build them only while the JS Vivado run is idle. Screen legends and LED maps are in [FPGA_BRINGUP.md](FPGA_BRINGUP.md).

```bash
source scripts/vivado_env.sh
make -C tools/mouse_probe bit flash
```

| Bit | What it proved |
|---|---|
| `build/mouse_probe/mouse_probe_J15kbd_JAmouse.bit` | Keyboard on J15, mouse on JA pins 1 and 3. Owner confirmed. |
| `build/mouse_probe/mouse_probe_J15mouse_PMODkbd_PASS_2026-11-03.bit` | The opposite: mouse on J15, keyboard on JA. |
| Older unnamed probe bits | `build/mouse_probe/To_delete/` |

The F10 / GO TO KEY switch is git `97f30e9`. It is a one-port fallback. It is not needed when the keyboard and the mouse have their own jacks.

The GUI injects the keyboard and the pointer below these ports. It cannot prove J15, JA, or JC. On a machine bit, check typing in Terminal and in a menu, a drag on JA, the same drag on JC with JA empty, both mice without one releasing the other's button, the JB stick, and File → Quit back to Finder.
