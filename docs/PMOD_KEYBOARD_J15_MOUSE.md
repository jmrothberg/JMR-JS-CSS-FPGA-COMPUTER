# Keyboard on JA, mouse on J15, stick on JB

Decided 2026-11-03 (owner). **Proven on the Nexys Video with the probe bit
in this repo.** The full JS `.bit` has not been loaded with this wiring in
the same session. Read the warning before touching any PS/2 code.

| Device | Where | Why |
|---|---|---|
| **Mouse** (wired or wireless) | **J15** USB host | PIC24 forwards one device as PS/2 on `W17` (clock) / `N13` (data). Mouse only. |
| **Keyboard** (wired PS/2) | **Pmod JA**, top row, through a Pmod PS/2 module | Its own two pins, so it never competes with J15. |
| **I2C joystick** (optional) | **Pmod JB** | `JB1` SCL `V9`, `JB2` SDA `V8`. Unchanged. |

Nothing switches modes. Do not build the menu + F10 switch for this
setup. A USB splitter or hub does not help (the PIC24 has no hub driver).
A **wireless keyboard through J15 still does not work**; see the end.

## WARNING: the mistake that stopped the keyboard from typing

**`ps2_rx.parity_err` is 1 when the byte is valid.** The name is backwards.
`rtl/phys/ps2_rx.sv` sets `parity_err <= ^{shift[10], shift[9:2]}`; that is
the XOR of the parity bit and the eight data bits, which is **1 for good odd
parity**.

The probe accepted a byte only when `parity_err == 0` (`st && !pe`). That
threw away **every valid key on every port**. The keyboard powered up and
flashed its LEDs, so it looked like wiring or power, and a lot of time went
into JB / JA / JC / 3.3 V vs 5 V. None of those was the cause. The fix was
one character: `st && pe`.

Rules for whoever integrates this:

1. **Do not gate keys on `parity_err`.** The JS top
   (`/home/jonathan/JMR-JS-CSS-FPGA-COMPUTER/rtl/top_nexys_video.sv`,
   `u_pmod_ps2_rx`) ignores it and uses only `strobe` + `scancode`. Keep it
   that way. If you add a parity check, **valid = 1**, and prove it by
   typing on the glass.
2. **Do not read "nothing typed" as a pin or power problem first.** A
   keyboard LED flash at power-on only proves power. Check that `strobe`
   pulses before moving wires.
3. **Do not use JB for the keyboard in the JS bit.** It was only proven on
   JB because that is where the probe was wired. JB is the joystick.
4. **Do not pull `ps2_clk` low on the keyboard path.** That inhibits the
   PIC24 and silences the device. No host transmit on the keyboard port.
   (The JS top already has this rule.)
5. **Caps Lock will not light** on a listen-only port. A PS/2 keyboard
   lights its LEDs only when the host sends `ED` plus a mask. A letter on
   the glass is the test, not an LED.
6. **Pmod PS/2 power jumper = `VB` to `VCC`** (3.3 V from the socket). `VE`
   to `VCC` leaves the keyboard dark unless 5 V is fed to `VE`. 3.3 V is
   enough. Never put 5 V on an FPGA pin.

### Two mouse-side mistakes found in the same session

These are in the **probe's mouse host**. The JS top uses
`rtl/phys/jmr_ps2_mouse_host.sv`, which does not have them, but anyone
porting the wheel code must not copy them.

* **Wheel byte `FF` is not a new packet.** One notch down is byte `FF`,
  which has bit 3 set, like a mouse status byte. A parser that treats any
  bit-3 byte as the start of a packet reads it as a new position: the
  cursor jumps and the wheel never moves. Frame a packet by the gap between
  bytes, or count the fourth byte once the wheel ID `03` was read.
* **Never let the mouse stream time out while idle.** The probe briefly
  lost `if (packet_index == 0 || rx_valid) timer <= 0;` in `STREAM`. A still
  mouse then hit the 2 s timeout, the host pulled the clock low and reset
  the mouse again and again, and the PIC24 got wedged. Reset on the FPGA
  did not clear it; unplugging the USB device or power-cycling the board
  did. The production host keeps that line. Keep it.

## What to do in the new full `.bit`

The JS top already has this layout. Leave it alone:

* `USB_MOUSE = 1` (the default). `u_mouse_host` runs on J15; the J15
  keyboard decoder is held in reset.
* `u_pmod_ps2_rx` / `u_pmod_ps2_dec` run on JA all the time and feed
  `key_evt_*`. Pins in `constraints/nexys_video.xdc`:
  `pmod_ps2_data` = `AB22` (JA1), `pmod_ps2_clk` = `AB20` (JA3).
* The I2C stick on JB. With no stick the read gets no reply and its bits
  stay 0. The keyboard's arrow-key events (`pmod_kev_*`) still drive
  games. The mouse is the desktop pointer only; it does not feed `joy()`.

Plug the Pmod PS/2 module into the **top row of JA** (data hole 1, clock
hole 3). Holes 1 to 6 are all on the top row: hole 6 = 3.3 V (far left),
hole 5 = GND, holes 4,3,2,1 = signals 4,3,2,1 with hole 1 at the right.

**Acceptance on the new bit** (all at once, no PC tether):
1. Mouse on J15 moves the pointer, both buttons work.
2. Keyboard on JA types at READY and arrow keys play a game.
3. Stick on JB works, and the machine still works with the stick unplugged.

If the probe types on JA but the JS bit does not, the adapter is wired on a
pairing other than data = JA1 / clock = JA3. The probe accepts six pairings
per Pmod, so it hides that. Then add the pairing; do not change the parity
rule.

Optional: the wheel. The production host is 3-byte only. The probe host
adds the IntelliMouse magic and the wheel byte.

## The code (full paths)

| File | Role |
|---|---|
| `/home/jonathan/JMR-JS-CSS-FPGA-COMPUTER/tools/mouse_probe/top_mouse_probe.sv` | Probe top: J15 mouse + Pmod keyboard receivers on JA, JB, JC, the screen |
| `/home/jonathan/JMR-JS-CSS-FPGA-COMPUTER/tools/mouse_probe/mouse_probe_host.sv` | Mouse host with wheel and gap framing |
| `/home/jonathan/JMR-JS-CSS-FPGA-COMPUTER/tools/mouse_probe/mouse_probe.xdc` | Pins; `CLOCK_DEDICATED_ROUTE BACKBONE` on `clk100_IBUF` is required |
| `/home/jonathan/JMR-JS-CSS-FPGA-COMPUTER/tools/mouse_probe/vivado_build.tcl` | Own Vivado project under `build/mouse_probe/` |
| `/home/jonathan/JMR-JS-CSS-FPGA-COMPUTER/rtl/phys/ps2_rx.sv` | Shared receiver. Read the `parity_err` line |
| `/home/jonathan/JMR-JS-CSS-FPGA-COMPUTER/rtl/phys/jmr_ps2_mouse_host.sv` | Production 3-byte mouse host |
| `/home/jonathan/JMR-JS-CSS-FPGA-COMPUTER/rtl/top_nexys_video.sv` | JS top: `USB_MOUSE`, `u_pmod_ps2_rx`, `i2c_joy` |

Do **not** add `tools/mouse_probe/` to `CORE_SRCS` or the board-flow file
list.

Saved passing bitstream (`build/` is git-ignored, so it is not in git):
`/home/jonathan/JMR-JS-CSS-FPGA-COMPUTER/build/mouse_probe/mouse_probe_J15mouse_PMODkbd_PASS_2026-11-03.bit`
(and `.bin`). Program: `openFPGALoader -b nexysVideo <that .bit>`. Rebuild:
`source scripts/vivado_env.sh && make -C tools/mouse_probe bit flash`.

Wiring log, and what each screen item proves:
[FPGA_BRINGUP.md](FPGA_BRINGUP.md), "HDMI mouse probe". The older
single-port menu + F10 design is [keyboard_mouse_switch.md](keyboard_mouse_switch.md)
(git `97f30e9`), kept only as a fallback for a user with just J15.

## Still unsolved

* **Wireless keyboard through J15.** The PIC24 translates only boot-protocol
  mice and keyboards. Wireless keyboard dongles usually send a vendor report
  and never get a Set-2 byte onto `W17`/`N13`. The FPGA cannot send the
  USB `SET_PROTOCOL` request. The parity bug above existed only in the
  Pmod build, so it does not explain this. A wireless **mouse** works.
* **One USB device that is both keyboard and mouse on J15.** See
  [NEXYS_USB_KEYBOARD_MOUSE_FAILED.md](NEXYS_USB_KEYBOARD_MOUSE_FAILED.md).
  Splitting the two onto two ports (this document) is the working answer.
