# NOT FPGA-SIM. NOT tools/board_flow. LED-only project → build/pmod_input_test.
# Tiny Pmod PS/2 + I2C joystick LED bit. Separate project dir so this cannot
# clobber the JS Vivado run.
# Usage: vivado -mode batch -source vivado_build.tcl -tclargs ROOT OUTDIR

set ROOT [lindex $argv 0]
set OUT  [lindex $argv 1]
file mkdir $OUT

if {[llength [get_parts -quiet xc7a200tsbg484-1]] == 0} {
  puts "ERROR: xc7a200tsbg484-1 not installed — enable Artix-7 in xsetup"
  exit 1
}

create_project pmod_input_test $OUT/vivado -part xc7a200tsbg484-1 -force
set_property target_language Verilog [current_project]

add_files $ROOT/rtl/phys/ps2_rx.sv
add_files $ROOT/rtl/phys/ps2_decode.sv
add_files $ROOT/tools/pmod_input_test/jmr_i2c_master.sv
add_files $ROOT/tools/pmod_input_test/jmr_i2c_joy.sv
add_files $ROOT/tools/pmod_input_test/usb_ps2_try.sv
add_files $ROOT/tools/pmod_input_test/top_pmod_input_test.sv
add_files -fileset constrs_1 $ROOT/tools/pmod_input_test/pmod_input_test.xdc

set_property top top_pmod_input_test [current_fileset]
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
  [get_property DIRECTORY [get_runs impl_1]]/top_pmod_input_test.bit \
  $OUT/pmod_input_test.bit
if {[file exists [get_property DIRECTORY [get_runs impl_1]]/top_pmod_input_test.bin]} {
  file copy -force \
    [get_property DIRECTORY [get_runs impl_1]]/top_pmod_input_test.bin \
    $OUT/pmod_input_test.bin
}

puts "OK wrote $OUT/pmod_input_test.bit"
exit 0
