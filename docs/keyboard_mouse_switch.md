# J15 keyboard / mouse mode switch

Handoff for the operating-system bitstream. The probe below proved the
switch on a Nexys Video. It is not the JS computer. Do not copy the probe
into `CORE_SRCS` or `tools/board_flow`.

Owner request: a menu item that enters keyboard mode, and **F10** that
returns to mouse mode. One mode at a time. J15 still forwards one USB
device. This does not make a keyboard-with-trackball send both. That
limit is [NEXYS_USB_KEYBOARD_MOUSE_FAILED.md](NEXYS_USB_KEYBOARD_MOUSE_FAILED.md).

## UPDATE 2026-11-03: the switch is not needed for the owner's setup

Read this first. The owner got **wireless mouse on J15 and a wired PS/2
keyboard on a Pmod, both at the same time, no switching** (probe bit saved
as `/home/jonathan/JMR-JS-CSS-FPGA-COMPUTER/build/mouse_probe/mouse_probe_J15mouse_PMODkbd_PASS_2026-11-03.bit`;
details and wiring in
[FPGA_BRINGUP.md](FPGA_BRINGUP.md), "Keyboard on a Pmod, mouse on J15").
The JS board top already has both paths live at once with `USB_MOUSE=1`:
`u_mouse_host` on J15 and `u_pmod_ps2_rx` / `u_pmod_ps2_dec` on **JA**
(`AB22` data, `AB20` clock, never reset by `desktop_keyboard_mode`). So
for integration the first job is to **check the JS bit with the keyboard
on JA**, not to build the menu switch below.

What the next agent needs to know:

*   The keyboard has only been proven on **JB**, which is where the owner's
    I2C joystick normally sits (`JB1` SCL `V9`, `JB2` SDA `V8`). JA is the
    JS bit's keyboard port and is **unproven with a working receiver**.
    Proof needs no build: load the saved probe bit, put the keyboard on JA
    (data `JA1`, clock `JA3`, jumper `VB` to `VCC`), type.
*   Do **not** move the keyboard to JB in the JS bit. It collides with the
    joystick.
*   The probe's "nothing typed" was a probe bug, not the port:
    `ps2_rx.parity_err` is **1 on valid parity**. The probe rejected
    `parity_err==1`. The JS top ignores it. Use it as "parity OK = 1".
*   Pmod PS/2 power: jumper `VB` to `VCC` (3.3 V). `VE` needs a 5 V wire.
*   The production `jmr_ps2_mouse_host` is 3-byte only. The probe host
    (`mouse_probe_host.sv`) adds the IntelliMouse wheel and frames packets
    on the gap between bytes. A wheel notch down is byte `FF`; it must not
    be read as a new packet status. Port that if the JS bit needs the wheel.
*   The menu + F10 text below is the single-port fallback and is **not
    implemented** in `jmr_desktop.sv`. Do it only if a user has just J15.

## What was proved (2026-11-02, the switching probe, git `97f30e9`)

Bitstream programmed that night:
`/home/jonathan/JMR-JS-CSS-FPGA-COMPUTER/build/mouse_probe/mouse_probe.bit`

Mouse-only on J15 worked first (cursor, left button, right button, wheel),
including a wireless mouse. A wireless keyboard on the same probe produced
no Set-2 bytes. The mode switch was added after the wired-mouse pass and
programmed the same night.

Probe sources, full paths:

| File | Role |
|---|---|
| `/home/jonathan/JMR-JS-CSS-FPGA-COMPUTER/tools/mouse_probe/top_mouse_probe.sv` | Screen, click target, F10, 3 second arming |
| `/home/jonathan/JMR-JS-CSS-FPGA-COMPUTER/tools/mouse_probe/mouse_probe_host.sv` | Mouse host plus `listen_keys` |
| `/home/jonathan/JMR-JS-CSS-FPGA-COMPUTER/tools/mouse_probe/mouse_probe.xdc` | Pins. `CLOCK_DEDICATED_ROUTE BACKBONE` on `clk100_IBUF` is required |
| `/home/jonathan/JMR-JS-CSS-FPGA-COMPUTER/tools/mouse_probe/vivado_build.tcl` | Own project under `build/mouse_probe/` |
| `/home/jonathan/JMR-JS-CSS-FPGA-COMPUTER/tools/mouse_probe/Makefile` | `source scripts/vivado_env.sh && make -C tools/mouse_probe bit flash` |

Rebuild from `tools/mouse_probe/`. The license is node-locked and uncounted,
so this project may run beside another Vivado. It must not write
`build/nexys_video`.

## Probe behavior to copy

Wires are J15's PIC24 PS/2 pair: clock `W17`, data `N13`. Idle high.
Open-drain. Drive low or Z, never high.

`top_mouse_probe.sv` holds `key_mode`. It is wired to
`mouse_probe_host.listen_keys`.

*   Mouse mode (`key_mode == 0`). The host sends `FF`, the IntelliMouse
    sample-rate magic, then `F4`. A packet is framed by silence. Three
    bytes and a 4 ms gap is a move. A fourth byte inside that gap is
    the wheel, including `FF` (one notch down). That byte has status
    bit 3 set, so it must not start a new packet.
*   Click the on-screen box **GO TO KEY** (x 36–160, y 88–128) with the
    left button. `key_mode` becomes 1. `f10_wait` loads `75_000_000`
    cycles at the 25 MHz pixel clock (3 seconds).
*   Keyboard mode. `listen_keys` forces state `LISTEN`, sets `clock_low`
    and `data_low` to 0, and emits every received byte on `scan_stb` /
    `scan_byte`. The clock stays released, which is what lets the PIC24
    keyboard path talk.
*   F10 is Set-2 make `8'h09`, and only when `key_brk` and `key_ext` are
    clear. Break is `F0 09` and must not count. F10 is ignored while
    `f10_wait != 0`.
*   `LISTEN` emits every byte. A mouse move sends bare bytes (`1A` is
    both `Z` and +26 pixels; `3A` is both `M` and +58 pixels). A real
    key sends its make and then `F0` plus that same byte on release.
    `top_mouse_probe.sv` remembers the last make (`last_make`) and only
    commits a letter or F10 when the matching `F0 <code>` arrives.
    Mouse motion no longer types `M` or `Z` and does not clear `key_mode`.
*   Clearing `listen_keys` leaves `LISTEN`, pulls the clock low, and
    starts the mouse reset at `INHIBIT` with command `FF`.

On-screen note **HIT F10 TO MOUSE** is gray during the wait and yellow
when F10 is armed (`top_mouse_probe.sv`, the `stamp` of `TXT_F10`).

Plug procedure the owner uses: click **GO TO KEY**, wait for the yellow
note, swap the keyboard into J15, type, press F10, plug the mouse back.

## Where the operating system already is

Do not invent a second PS/2 host. The board top already has both modes
and a flag that selects them.

`/home/jonathan/JMR-JS-CSS-FPGA-COMPUTER/rtl/top_nexys_video.sv`

*   Parameter `USB_MOUSE` defaults to 1 (mouse-first).
*   `desktop_keyboard_mode` is the switch.
*   Mouse host: `jmr_ps2_mouse_host` `u_mouse_host`. Its `reset` is
    `!rst_n || desktop_keyboard_mode`. Reset clears `clock_low` and
    `data_low` (`rtl/phys/jmr_ps2_mouse_host.sv`), so the pins go to Z.
    That is the same electrical step as the probe's `LISTEN`.
*   `ps2_rx` / `ps2_decode` (`u_ps2_rx`, `u_ps2_dec`) are held in reset
    unless `desktop_keyboard_mode` is set. Keyboard bytes then become
    `kbd_ascii` / `kbd_push` and `kev_code` / `kev_down` / `kev_stb`.
*   Leaving keyboard mode drops the mouse host's reset. It waits
    `POWER_CYCLES` (1 second at the clock it is given), then sends `FF`
    and `F4`. The production host is 3-byte only. The wheel magic lives
    only in the probe. Do not replace `jmr_ps2_mouse_host` as part of
    this menu work.

The flag is `jmr_desktop.keyboard_mode`, exported as
`jmr_js_core.desktop_keyboard_mode_o` and connected at
`top_nexys_video.sv` (`.desktop_keyboard_mode_o(desktop_keyboard_mode)`).

`/home/jonathan/JMR-JS-CSS-FPGA-COMPUTER/rtl/engines/jmr_desktop.sv`
declares `keyboard_mode` and only assigns `0`. Nothing sets it to `1`.
That is the hole.

## Do not confuse these two "keyboards"

| Name | What it is |
|---|---|
| `jmr_desktop.keyboard_mode` | J15 protocol select. Mouse host held in reset, `ps2_rx` enabled. This is the mode the probe tested. |
| Ship-menu **Keyboard** / `jmr_system_menu.keyboard_open` | On-screen picture of a keyboard (`functional_model/system_menu.py`, `rtl/engines/jmr_system_menu.sv`). It does not release the PS/2 clock. |

The new menu row has to set `jmr_desktop.keyboard_mode <= 1`. It must not
toggle `keyboard_open`.

## What to implement

1.  A desktop menu row the pointer can click, labeled so the owner can
    read it as go-to-keyboard. On that click, `keyboard_mode <= 1`.
    The pointer only works in mouse mode, so the click has to be handled
    while `keyboard_mode` is still 0. The menu drawing is in
    `jmr_desktop.sv` (the `case (menu)` click decode around the existing
    rows). Keep the edit in that desktop, not in a title HTML file.
2.  While `keyboard_mode` is 1, watch the J15 decoder only:
    `kev_stb && kev_down && kev_code == 8'd121`. That is F10.
    `rtl/phys/ps2_decode.sv` maps Set-2 `8'h09` to key code 121. On that
    event, `keyboard_mode <= 0`. Do not treat every `09` as F10. A mouse
    that is still streaming sends that byte as a movement of 9 counts,
    inside a packet whose bytes are about 1 ms apart. Honor F10 only
    when `09` is a lone byte: a gap before it and a gap after it. Do
    not drop other bytes to make that decision.
3.  Arm F10 three seconds after entering keyboard mode
    (`75_000_000` cycles if the desktop clock is 25 MHz; scale if
    `jmr_desktop` runs on `core_clk`). A mouse still streaming after the
    click can emit `8'h09` as an ordinary data byte. The wait is what
    stops that from immediately returning to mouse mode.
4.  Ignore F10 break (`F0` then `09`). `ps2_decode` already reports
    `kev_down == 0` for the break. Require `kev_down`.
5.  PC-tether F10 is the Architecture Monitor
    (`README.md`, `docs/ARCH_MONITOR.md`). Do not bind that GUI key to
    this switch. Only the board Set-2 path (`u_ps2_dec`) returns to the
    mouse.

## Wireless mouse, not a wireless keyboard

Owner, 2026-11-02, same probe: a wireless mouse moved, clicked, and
scrolled. A wireless keyboard typed nothing.

The PIC24 translates two USB shapes and nothing else. A boot mouse is the
fixed 3-byte HID report, or the common 4-byte report that adds a wheel.
A boot keyboard is the fixed 8-byte report: modifier bits plus six key
slots. Wireless mouse dongles still present the boot mouse, so the probe
sees normal PS/2 packets. Wireless keyboard dongles usually present a
vendor report instead (NKRO bitmap, extra HID pages, or a private
2.4 GHz payload). The PIC24 can enumerate that dongle and still clock
nothing on `W17`/`N13`. No FPGA decode runs, because no Set-2 byte
arrives. LD14 blinking with an empty letter line is USB at the PIC24
and silence on PS/2. A wired boot keyboard is the keyboard that types.
The descriptors for this dongle were not captured. One letter did
come through (owner, same night). That fits a dongle which emits a
single boot-shaped report and then stays in report protocol. USB HID
powers a keyboard up in report protocol and requires the host to send
`SET_PROTOCOL` for the 8-byte boot report. The PIC24 does not let the
FPGA send that. Nexys 4's manual says only Boot HID devices are
supported. Digilent's reply on a Logitech K400r wireless keyboard was
that the dongle is not this protocol
([forum 5060](https://forum.digilent.com/topic/5060-trying-to-interface-wireless-keyboard-nexys4/)).

Tricks, in order: put the keyboard in its BIOS / 6KRO mode (the chord
is in its own manual; Left Fn+Shift+Esc is one example) and replug the
dongle so enumeration sees that mode. Power-cycle with HDMI unplugged
and the dongle already in J15, then program the FPGA. No hub. Keyboard
listen passes every byte and does not pull the clock. A mouse packet is
framed by silence: three bytes and a gap is a move, a fourth byte inside
the gap is the wheel. `FF` is one notch down and must not be read as a
new position. F10 counts only when `09` is alone. The parity bug above
only existed in the Pmod build, so it does not explain the wireless
keyboard. That stays unsolved.

## What not to do

*   Do not time-slice the two protocols. The PIC24 forwards one USB
    function. Holding the clock for a mouse slice silences the keyboard,
    and a cut packet looks like a key.
*   Do not drive `ps2_clk` high. Do not send `FF` / `F4` while
    `keyboard_mode` is 1. Host transmit is why `jmr_ps2_host` stays off
    the keyboard path (`top_nexys_video.sv` comment above `u_ps2_rx`).
*   Do not title-gate (`if (stem == …)`). This is a machine mode.
*   Do not add `tools/mouse_probe/` to the JS file list. `find rtl` in
    the board flow must not start compiling the probe.
*   JA Pmod PS/2 (`u_pmod_ps2_rx`) is the keyboard that works alongside
    the J15 mouse and stays listen-only. This switch is J15.
