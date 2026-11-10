# Synthesize one module alone with a 10 ns clock and print its deepest paths.
# About four minutes; use it before any full build.
# usage: -tclargs <top module> <clock port> <directive> <file.sv>...
# The full build uses AreaOptimized_high; compare with Default to see what it costs.
set ROOT [file normalize [file dirname [info script]]/../..]
set top [lindex $argv 0]; set ck [lindex $argv 1]
set_param general.maxThreads 4
foreach f {jmr_value.sv jmr_js_vm_pkg.sv jmr_toolbox_rom_pkg.sv jmr_desktop_layout_pkg.sv jmr_system_menu_pkg.sv jmr_classic_ui_pkg.sv} {
  read_verilog -sv $ROOT/rtl/engines/$f
}
foreach f [lrange $argv 3 end] {read_verilog -sv $f}
synth_design -top $top -part xc7a200tsbg484-1 -mode out_of_context -directive [lindex $argv 2] -verilog_define SYNTHESIS=1
create_clock -name clk -period 10.0 [get_ports $ck]
# Time paths that start at input ports too; inputs often arrive through logic.
set_input_delay -clock clk 2.0 [get_ports -filter "DIRECTION == IN && NAME != $ck"]
puts "MODULE $top luts=[llength [get_cells -hier -filter {REF_NAME=~LUT*}]] flops=[llength [get_cells -hier -filter {IS_SEQUENTIAL}]]"
array set seen {}
foreach p [get_timing_paths -max_paths 5000 -nworst 1 -setup] {
  set l [get_property LOGIC_LEVELS $p]
  if {$l < 13} continue
  regsub -all {\[[0-9]+\]} "[get_property STARTPOINT_PIN $p] -> [get_property ENDPOINT_PIN $p]" {} k
  if {![info exists seen($k)]} {set seen($k) $l; puts "DEEP $l $k"}
}
exit
