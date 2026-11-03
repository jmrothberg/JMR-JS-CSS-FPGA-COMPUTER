# J15 keyboard / mouse mode switch

Handoff for the operating-system bitstream. The probe below proved the
switch on a Nexys Video. It is not the JS computer. Do not copy the probe
into `CORE_SRCS` or `tools/board_flow`.

Owner request: a menu item that enters keyboard mode, and **F10** that
returns to mouse mode. One mode at a time. J15 still forwards one USB
device. This does not make a keyboard-with-trackball send both. That
limit is [NEXYS_USB_KEYBOARD_MOUSE_FAILED.md](NEXYS_USB_KEYBOARD_MOUSE_FAILED.md).

## What was proved (2026-11-02)

Bitstream programmed that night:
`/home/jonathan/JMR-JS-CSS-FPGA-COMPUTER/build/mouse_probe/mouse_probe.bit`

Mouse-only on J15 worked first (cursor, left button, right button, wheel).
The mode switch was added after that and programmed the same night.

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
    sample-rate magic, then `F4`, and parses 3-byte or 4-byte packets.
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
*   A mouse packet is not a key. Bytes inside one packet arrive about
    1 ms apart. A key is one byte, then a gap. In `LISTEN`, a byte whose
    bit 3 is set is held for `KEY_GAP_CYCLES` (3 ms). If another byte
    arrives first, the held byte was a mouse status (a move of 9 counts
    is byte `09`, which is also F10) and the whole packet is dropped.
    If the gap expires, the byte is a key and is emitted on `scan_stb`.
    The typed line in `top_mouse_probe.sv` (`typed`, `ntyped`) shows the
    last 32 of those keys. Mouse motion must not clear `key_mode`.
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
    inside a packet whose bytes are about 1 ms apart. The probe holds a
    bit-3 byte for 3 ms and drops the group when another byte arrives
    (`mouse_probe_host.sv`, `KEY_GAP_CYCLES`). Copy that before the
    desktop honors F10, or moving the mouse leaves keyboard mode.
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
*   JA Pmod PS/2 (`u_pmod_ps2_rx`) is a second keyboard and stays
    listen-only. This switch is J15.
