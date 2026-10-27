# Nexys USB keyboard and built-in mouse: failed approach

Recorded 2026-10-26. **The combined keyboard/mouse requirement is not working
on Nexys Video. Do not repeat the mouse-only build as a solution.**

## Required behavior

Plug a USB keyboard with a built-in mouse or trackball into the usual USB
HOST connector, **J15**, and use both functions. Keep the normal USB keyboard
and existing joystick working. A PC tether or moving the keyboard to a Pmod
connector does not meet this requirement.

The owner confirmed that the ordinary USB keyboard worked in prior builds
with its usual connection. The owner's custom Macintosh motherboard also
supports a combined keyboard/trackball; that is a different USB host path.

## What failed

The experimental `USB_MOUSE=1` build,
`build/mouse_usb_20261026/jmr_nexys_video_usb_mouse.bit`, **replaced the J15
keyboard decoder with a PS/2 mouse host**. It explicitly tied the J15
keyboard ASCII and key-event outputs to zero. The owner reported that the
previously working keyboard stopped working on this build.

This was a configuration regression introduced by the build, not evidence
that the owner's keyboard or its normal connection was faulty. Keeping a
keyboard decoder on JA did not preserve the requested J15 keyboard setup.
The normal `USB_MOUSE=0` path retains J15 keyboard decoding, but does not
implement the combined-device requirement either.

The experiment passed routing and timing (+0.038 ns setup, +0.022 ns hold)
and mouse RTL tests. **Those checks did not establish combined USB-device
support.** Physical USB mouse operation was not confirmed. The owner also
reported that the GUI could not see the board while the display was running;
that connection issue was not diagnosed and must not be attributed to the
keyboard decoder without evidence.

The previous keyboard-working bitstream was preserved and its recorded
SHA-256 checked. The mouse-only experiment is not the standard release;
see [STANDARD_RELEASE.md](STANDARD_RELEASE.md) for the accepted release.

## Why the custom-board solution does not transfer directly

On Nexys Video, J15 connects to a **PIC24 USB host controller**, which
forwards a shared PS/2 interface to the FPGA. The [Digilent reference manual,
sections 8 and 8.1](https://digilent.com/reference/_media/reference/programmable-logic/nexys-video/nexys-video_rm.pdf)
documents one keyboard or one mouse; the FPGA does not receive raw USB HID
reports. A new FPGA bitstream cannot by itself make that firmware forward
both functions of a combined device.

The custom Macintosh motherboard uses a **CH9350L USB host and Lattice U3
report forwarder**. Its working keyboard/trackball image forwards both report
types. That U3 image is not firmware for the Nexys PIC24.

## Before attempting another solution

Establish a USB-controller path that forwards both keyboard and mouse reports
from the combined device. Keep the J15 keyboard path intact. Do not claim
that enabling two decoders, switching to mouse-only mode, or passing synthetic
mouse/keyboard tests proves that both reports reach the FPGA.

Acceptance requires the actual combined keyboard/mouse on J15: typing,
movement, clicks and releases, existing joystick input, and game play without
a PC tether. Preserve the accepted bitstream throughout. There is currently
no verified combined-input Nexys replacement bitstream.
