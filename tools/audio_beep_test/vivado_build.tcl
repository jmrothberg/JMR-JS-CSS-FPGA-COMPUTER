# NOT FPGA-SIM. NOT tools/board_flow. Audio-only project → build/audio_beep_test.
# Phase 0 of the line-out PSG plan: smallest bitstream that can make a sound.
# Separate project dir so this cannot clobber the JS Vivado run.
# Usage: vivado -mode batch -source vivado_build.tcl -tclargs ROOT OUTDIR

set ROOT [lindex $argv 0]
set OUT  [lindex $argv 1]
file mkdir $OUT

if {[llength [get_parts -quiet xc7a200tsbg484-1]] == 0} {
  puts "ERROR: xc7a200tsbg484-1 not installed — enable Artix-7 in xsetup"
  exit 1
}

create_project audio_beep_test $OUT/vivado -part xc7a200tsbg484-1 -force
set_property target_language Verilog [current_project]

add_files $ROOT/tools/audio_beep_test/jmr_adau1761_cfg.sv
add_files $ROOT/tools/audio_beep_test/jmr_i2s_beep.sv
add_files $ROOT/tools/audio_beep_test/top_audio_beep_test.sv
add_files -fileset constrs_1 $ROOT/tools/audio_beep_test/audio_beep_test.xdc

set_property top top_audio_beep_test [current_fileset]
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
  [get_property DIRECTORY [get_runs impl_1]]/top_audio_beep_test.bit \
  $OUT/audio_beep_test.bit
if {[file exists [get_property DIRECTORY [get_runs impl_1]]/top_audio_beep_test.bin]} {
  file copy -force \
    [get_property DIRECTORY [get_runs impl_1]]/top_audio_beep_test.bin \
    $OUT/audio_beep_test.bin
}

puts "OK wrote $OUT/audio_beep_test.bit"
exit 0
