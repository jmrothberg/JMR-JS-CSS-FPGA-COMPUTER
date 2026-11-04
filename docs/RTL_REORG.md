# RTL map

Where the SystemVerilog lives, and the mistakes that break a build or a jack if they are repeated. Fit and RAM shape: [FPGA_FIT.md](FPGA_FIT.md). Plugs: [USB_KEYBOARD_PMOD_MICE.md](USB_KEYBOARD_PMOD_MICE.md).

## What builds

FPGA-SIM tops `jmr_js_core`. The file list is `sim/Makefile` `CORE_SRCS`.

The board tops `top_nexys_video`, which instantiates that same core with `SRAM_INTERNAL=0`. Its file list is `tools/board_flow/vivado_build.tcl` `jmr_add_sources`. A file added to only one list is missing on the other machine.

`PROGRAM_FINDER` defaults to 1. Finder is the program on the card. `PROGRAM_FINDER=0` is the old built-in desktop.

The VM clock is the fabric clock divided by `VM_CLK_DIV` (3). Scanout stays on the fabric clock. Do not slow that clock to chase a path inside the VM.

| Folder | What is there |
|---|---|
| `rtl/jmr_js_core.sv` | Shared top |
| `rtl/top_nexys_video.sv` | Board shell: HDMI, DDR, keyboard, mice, joystick, audio |
| `rtl/engines/` | VM, console, Finder, menus, disk, SRAM model |
| `rtl/video/` | HDMI scanout and the menu/mouse overlays |
| `rtl/phys/` | PS/2, mouse hosts, I2C stick, SD card, audio |

Inside the core:

- `jmr_js_vm` holds the one JavaScript heap. `jmr_js_vm_exec64` is the only decoder.
- `jmr_console_engine` and `storage_engine` do READY, LOAD, and RUN. `sd_spi_master` is the card.
- `jmr_mini_fb`, `jmr_fb_present`, `jmr_fb_scanout`, and `jmr_raster_engine` are the picture. `jmr_text_hdmi_scanout` is board-only.
- `jmr_finder_shell`, `jmr_finder_fs`, `jmr_desktop`, `jmr_desktop_disk` are the shell around the Finder program.
- `jmr_classic_ui`, `jmr_system_menu`, `jmr_system_documents`, `jmr_system_actions`, and the overlays are the shared menus and dialogs.
- `jmr_keyboard_fifo` is the key queue. FPGA-SIM pushes keys from the GUI.
- `jmr_sram_model` is the external RAM when `SRAM_INTERNAL=1`. The board uses `jmr_ddr3_sram_bridge` instead.
- `jmr_rectdemo_engine` is still wired. It is the RECTDEMO native path, not an HTML title.

Board-only, not in `CORE_SRCS`: `ps2_rx`, `ps2_decode`, `jmr_ps2_mouse_host`, `jmr_pointer_accumulator`, `jmr_mouse_packet_merge`, `jmr_i2c_joy`, `jmr_i2c_master`, `jmr_ddr3_sram_bridge`, `jmr_uart_link`, `jmr_ft245_async`, `jmr_adau1761_cfg`, `jmr_psg`, `jmr_text_hdmi_scanout`.

`$readmemh` paths are relative to the `.sv` file. `invaders_jsb.hex` is a placeholder the VM reads at build time. A title runs from the minted `.JSH` on `card.img`.

## Do not split the VM

`jmr_js_vm.sv` stays one file. Pulling JOIN, JSON, GC, or the heap into a new module makes a second heap or an illegal RAM port. A control-only submodule is allowed only in the `u_exec64` shape: no arrays of its own, scalar ports, data back on the next clock. [FPGA_FIT.md](FPGA_FIT.md).

Do not `` `include `` arms of the parent `always_ff`. That hides the one-process RAM audit and does not shrink the netlist.

Console, storage, the framebuffer, HDMI, and SPI are already separate. Leave them separate.

## States and the decoder

New `st_t` names go at the end. Today the last name is `S_FS`. Do not insert a name in the middle, and do not move `S_FB_SYNC` to the end. The comment above it says it must stay last. States were added after it. Moving it renumbers every later state.

Three lists must stay the same sequence: the enum in `jmr_js_vm.sv`, the enum in `jmr_js_vm_pkg.sv`, and `vm_sname()` in `sim/sim_main.cpp`. Parent and package match. The C++ table currently stops at `S_UI_PROP` and has no `S_FS`, so a trace of that state prints `?`.

```bash
python3 - <<'EOF'
import re
def enum(p):
    L=open(p).read().split("\n"); k=next(i for i,l in enumerate(L) if "typedef enum logic [6:0]" in l)
    o=[]
    for l in L[k+1:]:
        if "st_t" in l and "}" in l: break
        o+=[t.strip() for t in re.sub(r"//.*","",l).split(",") if t.strip().startswith("S_")]
    return o
def cpp():
    c=open("sim/sim_main.cpp").read(); i=c.index("static const char* vm_sname")
    j=c.index("};", i)
    return re.findall(r'"(S_[^"]+)"', c[i:j])
par, pkg, names = enum("rtl/engines/jmr_js_vm.sv"), enum("rtl/engines/jmr_js_vm_pkg.sv"), cpp()
print("parent", len(par), "pkg", len(pkg), "c++", len(names), "| equal:", par==pkg==names)
if par!=names: print("only in RTL", [n for n in par if n not in names])
EOF
```

Names that start with `e32_` on the parent are parent buses. They are not a second decoder. Do not delete one that the parent still assigns.

## Bugs that come back if the shape is copied wrong

**A parent state entered from exec64 needs a first-entry beat.** Exec64 sets `state_n`. The parent arm must see that it just arrived, latch the seeds from `e64_*_q`, and stay in that state. Without that beat the arm reads parent registers nothing wrote, or it samples a RAM word that is still the previous address. `S_V64_STRIDX` is the pattern: sprites failed to paint while the splash bars still did.

**A multi-beat walk owns its cursor.** `bind_k` and the `*_arm` flags are shared by unrelated states. An event walk that reused `bind_k` wiped a half-finished animation-frame snapshot, and the frame then ran a key listener. Reset the cursor in that walk's own entry. Do not trust the value a previous state left.

**A registered RAM read is two clocks.** Address this clock, data the next. Gating the address on a flag that is still 0 on the beat you set it reads the previous word. `join` interned `"1100"` as `"0000"` that way.

## Files that are not the machine

| File | Why it is still here |
|---|---|
| `rtl/jmr_js_top.sv`, `jmr_fb_mem.sv`, `jmr_input_engine.sv` | Early stub. FPGA-SIM never builds it. The picture is `jmr_mini_fb`. The stick is `joy_in`. |
| `rtl/engines/jmr_ps2_host.sv`, `tools/*/usb_ps2_try.sv` | These drive the PS/2 clock (`0xFF` / `0xF4`). That stopped the PIC24 from scanning. The keyboard path only listens. Do not instantiate either in `jmr_js_core`, `top_nexys_video`, or `CORE_SRCS`. |
| `rtl/phys/jmr_ps2_simple.sv` | Not on a file list. Live PHY is `ps2_rx` plus `ps2_decode`. |
| `rtl/video/jmr_hdmi_scanout.sv`, `jmr_hdmi_colorbar.sv` | Not on a file list. Live HDMI is `jmr_text_hdmi_scanout`. |

`rtl/phys/ps2_rx.sv` is one file used by the JS board bit, `tools/hid_led_blink/`, and `tools/pmod_input_test/`. An edit changes the next flashed machine bit. FPGA-SIM does not compile it, so F9 will not show the change. `ps2_rx.parity_err` is 1 when the byte is valid.

`jmr_i2c_joy` and `jmr_i2c_master` also exist as copies under `tools/pmod_input_test/`. The machine copies are `rtl/phys/`. Do not edit the tool copy and expect the board bit to change.

## Probe bits

`tools/mouse_probe/`, `tools/pmod_input_test/`, `tools/hid_led_blink/`, and `tools/audio_beep_test/` build their own tops. They are not FPGA-SIM and not `make -C tools/board_flow bit`. Do not add them to `CORE_SRCS`. How to run them: [FPGA_BRINGUP.md](FPGA_BRINGUP.md).

Do not lower `SD_RUN_DIV` to make LOAD faster. The simulator's card model then misses MOSI and every LOAD returns `?IO`.
