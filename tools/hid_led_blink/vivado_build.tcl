# Tiny HID→LED bit. Separate project dir so this cannot clobber the JS Vivado run.
# Usage: vivado -mode batch -source vivado_build.tcl -tclargs ROOT OUTDIR

set ROOT [lindex $argv 0]
set OUT  [lindex $argv 1]
file mkdir $OUT

if {[llength [get_parts -quiet xc7a200tsbg484-1]] == 0} {
  puts "ERROR: xc7a200tsbg484-1 not installed — enable Artix-7 in xsetup"
  exit 1
}

create_project hid_led_blink $OUT/vivado -part xc7a200tsbg484-1 -force
set_property target_language Verilog [current_project]

add_files $ROOT/rtl/phys/ps2_rx.sv
add_files $ROOT/tools/hid_led_blink/top_hid_led_blink.sv
add_files -fileset constrs_1 $ROOT/tools/hid_led_blink/hid_led_blink.xdc

set_property top top_hid_led_blink [current_fileset]
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
  [get_property DIRECTORY [get_runs impl_1]]/top_hid_led_blink.bit \
  $OUT/hid_led_blink.bit
if {[file exists [get_property DIRECTORY [get_runs impl_1]]/top_hid_led_blink.bin]} {
  file copy -force \
    [get_property DIRECTORY [get_runs impl_1]]/top_hid_led_blink.bin \
    $OUT/hid_led_blink.bin
}

puts "OK wrote $OUT/hid_led_blink.bit"
exit 0
