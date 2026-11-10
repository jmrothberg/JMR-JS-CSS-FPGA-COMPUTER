# Keyboard, mice and joystick

Which plug goes where, and what each jack can and cannot do. Pins are set in `constraints/nexys_video.xdc` and wired in `rtl/top_nexys_video.sv`. Turn the board off before moving a plug. A pin change needs a new board build.

## Plugs

| Jack | Device | FPGA pins |
|---|---|---|
| **J15** (USB Host) | USB keyboard | clock `W17`, data `N13` |
| **JA** (Pmod) | PS/2 mouse | data pin 1 `AB22`, clock pin 3 `AB20` |
| **JC** (Pmod) | Second PS/2 mouse | data pin 1 `Y6`, clock pin 3 `AA8` |
| **JB** (Pmod) | I2C joystick, address `0x5A` | SCL pin 1 `V9`, SDA pin 2 `V8` |

On every Pmod, pin 5 is ground and pin 6 is 3.3 V. Looking into the socket, the top row is pins 1–6 with pin 1 at the right and pin 6 at the far left. The bottom row is pins 7–12.

All these pins have pull-ups. The FPGA only pulls a mouse line low or lets it float; it never drives one high. It never drives the J15 lines at all.

Never put 5 V on an FPGA pin. Do not use the JXADC header.

A Pmod PS/2 adapter takes its power with the jumper on **VB to VCC** (3.3 V from the board). Wire the joystick by its labels (G, V, SDA, SCL), not by wire colour.

## Build options

`top_nexys_video` has two parameters. The defaults are the plugs above.

| Parameter | Default | Effect |
|---|---|---|
| `USB_MOUSE` | 0 | 1 swaps them: mouse on J15, keyboard on JA. |
| `JC_MOUSE` | 1 when `USB_MOUSE=0` | 0 removes the second mouse. |

## How the inputs reach the machine

- **Keyboard.** `ps2_rx` receives bytes from J15 and `ps2_decode` turns them into ASCII and key up/down events. Keys typed in the host GUI arrive over the PROG cable and join the same path.
- **Mice.** JA and JC each have their own `jmr_ps2_mouse_host` (plain three-byte mouse, no wheel). `jmr_mouse_packet_merge` applies movement from both and ORs the buttons, so an idle mouse cannot release a button the other is holding. `jmr_pointer_accumulator` makes one pointer.
- **Joystick.** `jmr_i2c_joy` polls the stick. Its six direction and fire bits are ORed with joystick bits sent from the host GUI. Up and down are swapped in the top level because this stick reports them reversed. The analog axes and five extra buttons go to the core separately. With no stick plugged in, the bits stay 0.

`ps2_rx.parity_err` is **1 when the byte is good**. The name is backwards. The machine uses the strobe and the scancode and ignores it.

## What J15 cannot do

J15 is not a general USB port. A microcontroller on the board turns one USB device into PS/2 signals. The FPGA sees PS/2, never USB.

| Situation | Result |
|---|---|
| Wired boot-protocol keyboard | Works. |
| Wireless keyboard dongle | Usually one letter, then nothing. Use a wired keyboard. |
| Hub or splitter | Does not add a second device. |
| One USB device that is both keyboard and mouse | Does not work. |
| Passive USB-to-PS/2 adapter on a Pmod | Works only if the mouse itself speaks PS/2. |
| Caps Lock light | Stays off. Lighting it needs the host to transmit, and this path only listens. |
| FPGA transmits on the J15 lines, or holds the clock low | The keyboard stops. Never put a transmitter on J15. |

## Keyboard does not type

LD7 toggles on every scancode byte. If it never moves:

1. Unplug HDMI, then power-cycle with the keyboard already in J15. An HDMI monitor feeds 5 V back into the board, so the keyboard never resets and is not detected again.
2. Check the keyboard is in the USB Host jack, not PROG or UART.
3. Use a wired keyboard, no hub.
4. Load the bitstream after power-up. The USB bridge starts only once the FPGA is configured.
5. Watch LD14 (BUSY). Fast blinks on a key press mean the bridge received the key. LD14 active with LD6 steady means a device the bridge does not translate.
6. Load the [`hid_led_blink` probe](FPGA_BRINGUP.md#hid_led_blink). If LD7 toggles there, the fault is in the machine bit.

JP4 selects the FPGA boot source. Moving it does not fix a keyboard.

## Checking a new machine bit

The host GUI injects keys and pointer below these jacks, so it cannot prove them. On the board: type; drag with the JA mouse; drag with the JC mouse with JA empty; hold a button on one mouse while moving the other; move the JB stick; quit a program back to Finder.

Probe bits that test one jack at a time: [FPGA_BRINGUP.md](FPGA_BRINGUP.md#probe-bits).
