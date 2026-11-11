# Tether framebuffer pixel dump (removed in build 96)

## What it did

Up to build 95, `jmr_uart_link` sent a 160×120, 4-bit preview of the
640×480 framebuffer over the USB tether (PROG cable, FT245) while a program
was in front (`game_mode`): one line per row, `P<rr>:` + 160 hex nibbles +
`\n`, sampling every fourth pixel of every fourth row. `runtime/board_backend.py`
parsed the lines, scaled them ×4 and painted them in the GUI. The `S<row>:`
text rows, `K/D/E/V/H/F/T/G` telemetry and `Q` Finder replies were and are
separate and are unchanged. File transfer (0xFA Finder requests, 0xFB/0xFC/0xFD
PUT/RUN streams) never used the pixel dump.

## Why it was removed

Timing. The link drove an address into the shared framebuffer read port
(`u_fb.dump_raddr`, the Port-A of the 75-bank `jmr_mini_fb`) and read the byte
back. Its address joined the Toolbox/VM address mux in `jmr_js_core`, and the
byte from the 75-bank read mux had to reach the link, which sits next to the
FT245 pins across the chip. In build 95b this was one of the worst path groups
(−0.367 ns overall WNS). The picture is on HDMI; the preview was not
colour-exact anyway.

The framebuffer read port itself stays: the Toolbox (`tb_fb_req`) and the VM
`getImageData` path (`vm_dump_addr`) still use it.

## Files here

| File | Content |
|---|---|
| `jmr_uart_link.build95.sv` | `rtl/engines/jmr_uart_link.sv` as it was before the removal |
| `fb_dump_removal.patch` | Unified diff of the removal (RTL + `runtime/board_backend.py`) |

## How to restore

From the repository root: `patch -R -p1 < archive/rtl/fb_dump/fb_dump_removal.patch`
(may need hand-merging if those files changed since). By hand:

1. `rtl/engines/jmr_uart_link.sv`: add the ports
   `output logic [18:0] dump_fb_raddr`, `input logic [7:0] dump_fb_rdata`,
   `input logic game_mode = 1'b0`; restore the `dump_game`, `fb_row`, `fb_col`,
   `dump_fb_nib_q` registers, the `dump_fb_nib_q <= dump_fb_rdata[3:0]` /
   `hex_digit(dump_fb_nib_q)` sample, and the `dump_game` arms of `HB_HDR`,
   `HB_ROW`, `HB_ROW2`, `HB_BYTE`, `HB_NL` (`HB_ROW2` is still in the enum).
2. `rtl/jmr_js_core.sv`: add the ports `input logic [18:0] dump_fb_raddr = 19'd0`
   and `output logic [7:0] dump_fb_rdata` (remove the internal
   `logic [7:0] dump_fb_rdata`), and make the `u_fb` address
   `tb_fb_req ? tb_fb_raddr : vm_dump_sel ? vm_dump_addr : dump_fb_raddr`.
3. `rtl/top_nexys_video.sv`: declare `dump_fb_raddr`/`dump_fb_rdata` and connect
   them on both `u_link` and `u_core`; connect `.game_mode(game_mode)` on `u_link`.
4. `runtime/board_backend.py`: restore `_FB_W/_FB_H/_FB_SCALE`, `_FB_RE`, the
   `P` line parse into `self._fb`, `_paint_fb_scaled()`, and the
   `self._have_fb` branch of `_paint_mirror()` and `hdmi_mode`.
5. `docs/ARCH_MONITOR.md`: restore the `P<row>` row in the BOARD line table.

Expect the timing path `u_fb` bank read → `u_link/dump_fb_nib_q` to return.
