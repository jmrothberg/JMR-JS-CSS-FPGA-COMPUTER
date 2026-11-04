# Tiny HDMI mouse probe. Separate project dir so this cannot clobber the JS bit.
# Usage: vivado -mode batch -source vivado_build.tcl -tclargs ROOT OUTDIR

set ROOT [lindex $argv 0]
set OUT  [lindex $argv 1]
# Optional third arg "ja_mouse": wired USB keyboard on J15, PS/2 mouse on JA.
# Default writes the proven J15-mouse / Pmod-keyboard bit and does not
# overwrite a ja_mouse bitstream.
set MODE ""
if {[llength $argv] >= 3} {
  set MODE [lindex $argv 2]
}
file mkdir $OUT

if {[llength [get_parts -quiet xc7a200tsbg484-1]] == 0} {
  puts "ERROR: xc7a200tsbg484-1 not installed — enable Artix-7 in xsetup"
  exit 1
}

create_project mouse_probe $OUT/vivado -part xc7a200tsbg484-1 -force
set_property target_language Verilog [current_project]

set DVI $ROOT/third_party/digilent_rgb2dvi/src
add_files [list \
  $DVI/DVI_Constants.vhd \
  $DVI/SyncAsync.vhd \
  $DVI/SyncAsyncReset.vhd \
  $DVI/ClockGen.vhd \
  $DVI/TMDS_Encoder.vhd \
  $DVI/OutputSERDES.vhd \
  $DVI/rgb2dvi.vhd \
  $ROOT/rtl/video/jmr_rgb2dvi_wrap.vhd \
  $ROOT/rtl/video/jmr_mouse_overlay.sv \
  $ROOT/rtl/phys/ps2_rx.sv \
  $ROOT/rtl/phys/jmr_ps2_mouse_host.sv \
  $ROOT/tools/mouse_probe/mouse_probe_host.sv \
  $ROOT/tools/mouse_probe/top_mouse_probe.sv \
]
add_files -fileset constrs_1 $ROOT/tools/mouse_probe/mouse_probe.xdc

set_property top top_mouse_probe [current_fileset]
set DEFINES {SYNTHESIS=1}
set BITNAME mouse_probe
if {$MODE eq "ja_mouse"} {
  lappend DEFINES PROBE_JA_MOUSE=1
  set BITNAME mouse_probe_J15kbd_JAmouse
}
set_property verilog_define $DEFINES [current_fileset]
set_property STEPS.WRITE_BITSTREAM.ARGS.BIN_FILE true [get_runs impl_1]
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY none [get_runs synth_1]

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

launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1
set st [get_property STATUS [get_runs impl_1]]
if {[get_property PROGRESS [get_runs impl_1]] != "100%" ||
    [string match -nocase "*fail*" $st] ||
    [string match -nocase "*error*" $st]} {
  puts "ERROR: implementation failed (STATUS=$st)"
  exit 1
}

file copy -force \
  [get_property DIRECTORY [get_runs impl_1]]/top_mouse_probe.bit \
  $OUT/$BITNAME.bit
if {[file exists [get_property DIRECTORY [get_runs impl_1]]/top_mouse_probe.bin]} {
  file copy -force \
    [get_property DIRECTORY [get_runs impl_1]]/top_mouse_probe.bin \
    $OUT/$BITNAME.bin
}

puts "OK wrote $OUT/$BITNAME.bit"
exit 0
