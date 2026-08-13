# Vivado batch build for Digilent Nexys Video (XC7A200T) — standalone console
# Usage: vivado -mode batch -source vivado_build.tcl -tclargs ROOT OUTDIR

set ROOT [lindex $argv 0]
set OUT  [lindex $argv 1]
file mkdir $OUT

if {[llength [get_parts -quiet xc7a200tsbg484-1]] == 0} {
  puts "ERROR: xc7a200tsbg484-1 not installed — enable Artix-7 in xsetup"
  exit 1
}

# Font ROM next to scanout ($readmemh relative to .sv)
file copy -force $ROOT/vectors/font_rom.hex $ROOT/rtl/video/font_rom.hex
# NEW: INVADERS bytecode for jmr_js_vm $readmemh
file copy -force $ROOT/vectors/invaders_jsb.hex $ROOT/rtl/engines/invaders_jsb.hex

create_project jmr_nexys_video $OUT/vivado -part xc7a200tsbg484-1 -force
set_property target_language Verilog [current_project]

set DVI $ROOT/third_party/digilent_rgb2dvi/src
add_files $DVI/DVI_Constants.vhd
add_files $DVI/SyncAsync.vhd
add_files $DVI/SyncAsyncReset.vhd
add_files $DVI/ClockGen.vhd
add_files $DVI/TMDS_Encoder.vhd
add_files $DVI/OutputSERDES.vhd
add_files $DVI/rgb2dvi.vhd
add_files $ROOT/rtl/video/jmr_rgb2dvi_wrap.vhd
add_files $ROOT/rtl/video/jmr_text_hdmi_scanout.sv
add_files $ROOT/rtl/video/font_rom.hex
add_files $ROOT/rtl/engines/jmr_keyboard_fifo.sv
add_files $ROOT/rtl/engines/jmr_video_vram.sv
add_files $ROOT/rtl/engines/jmr_console_engine.sv
add_files $ROOT/rtl/engines/jmr_mini_fb.sv
add_files $ROOT/rtl/engines/jmr_rectdemo_engine.sv
add_files $ROOT/rtl/engines/jmr_js_vm.sv
add_files $ROOT/rtl/engines/invaders_jsb.hex
add_files $ROOT/rtl/engines/jmr_uart_link.sv
add_files $ROOT/rtl/engines/jmr_ft245_async.sv
add_files $ROOT/rtl/engines/storage_engine.sv
# NEW: jmr_ps2_host removed from build — BASIC T100 is RX-only (file kept)
add_files $ROOT/rtl/phys/ps2_rx.sv
add_files $ROOT/rtl/phys/ps2_decode.sv
add_files $ROOT/rtl/phys/sd_spi_master.sv
add_files $ROOT/rtl/jmr_js_core.sv
add_files $ROOT/rtl/top_nexys_video.sv

add_files -fileset constrs_1 $ROOT/constraints/nexys_video.xdc

set_property top top_nexys_video [current_fileset]
set_property verilog_define {SYNTHESIS=1} [current_fileset]
set_property STEPS.WRITE_BITSTREAM.ARGS.BIN_FILE true [get_runs impl_1]

update_compile_order -fileset sources_1

launch_runs synth_1 -jobs 2
wait_on_run synth_1
set st [get_property STATUS [get_runs synth_1]]
if {[get_property PROGRESS [get_runs synth_1]] != "100%" ||
    [string match -nocase "*fail*" $st] ||
    [string match -nocase "*error*" $st]} {
  puts "ERROR: synthesis failed (STATUS=$st)"
  exit 1
}

open_run synth_1
report_utilization -file $OUT/utilization_synth.rpt

launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1
set st [get_property STATUS [get_runs impl_1]]
if {[get_property PROGRESS [get_runs impl_1]] != "100%" ||
    [string match -nocase "*fail*" $st] ||
    [string match -nocase "*error*" $st]} {
  puts "ERROR: implementation failed (STATUS=$st)"
  exit 1
}

open_run impl_1
report_utilization -file $OUT/utilization_impl.rpt

file copy -force \
  [get_property DIRECTORY [get_runs impl_1]]/top_nexys_video.bit \
  $OUT/jmr_nexys_video.bit
if {[file exists [get_property DIRECTORY [get_runs impl_1]]/top_nexys_video.bin]} {
  file copy -force \
    [get_property DIRECTORY [get_runs impl_1]]/top_nexys_video.bin \
    $OUT/jmr_nexys_video.bin
}

puts "OK wrote $OUT/jmr_nexys_video.bit"
exit 0
