# Requalify a completed routed checkpoint; never changes clocks or routing.
set root [lindex $argv 0]
set input [lindex $argv 1]
set out [lindex $argv 2]
set stem [lindex $argv 3]
file mkdir $out
if {[file exists $out/$stem.bit]} {error "Refusing to replace an existing release bit"}
set_param general.maxThreads 8
source $root/tools/board_flow/build_gates.tcl
open_checkpoint $input
read_xdc $root/constraints/native_argument_pipeline.xdc
set regs [get_cells -quiet -hierarchical -filter {NAME =~ *call_arg_q_reg* && IS_SEQUENTIAL}]
set vm [get_clocks -quiet vm_clk]
if {[llength $regs] == 0 || [llength $vm] != 1} {error "Missing native operand timing objects"}
if {[get_property PERIOD $vm] != 30.000 || [get_property WAVEFORM $vm] ne "0.000 5.000"} {
 error "VM clock must have its actual 30 ns period and 5 ns high pulse"
}
set fast [get_clocks -of_objects [get_pins u_core/g_vmclk_div.u_vm_bufgce/I]]
if {[get_property PERIOD $fast] != 10.000} {error "Fast clock must remain 100 MHz"}
puts "CHECKED_NATIVE_ARGUMENT_REGISTERS=[llength $regs] VM_PERIOD=30 VM_HIGH=5 FAST_PERIOD=10"
# Dirty comparison needs the previous byte on a write/read collision.
set fb_brams [get_cells -hierarchical -filter {NAME =~ *u_fb/* && REF_NAME =~ RAMB*}]
if {[llength $fb_brams] == 0} {error "Framebuffer BRAMs not found"}
set fd [open $out/framebuffer_bram_modes.rpt w]
foreach c $fb_brams {
 set a [get_property WRITE_MODE_A $c]
 puts $fd "$c [get_property REF_NAME $c] WRITE_MODE_A=$a WRITE_MODE_B=[get_property WRITE_MODE_B $c]"
 if {$a ne "READ_FIRST"} {error "Dirty comparison requires READ_FIRST Port A: $c"}
}
close $fd
puts "CHECKED_FRAMEBUFFER_READ_FIRST_BRAMS=[llength $fb_brams]"
report_clocks -file $out/clocks.rpt
report_exceptions -file $out/exceptions.rpt
report_pulse_width -file $out/pulse_width.rpt
set timing [report_timing_summary -report_unconstrained -return_string]
set fd [open $out/timing.rpt w]; puts $fd $timing; close $fd
report_timing -max_paths 100 -unique_pins -file $out/paths.rpt
report_timing -from $vm -to $vm -max_paths 100 -unique_pins -file $out/vm_paths.rpt
report_timing -from $fast -to $vm -max_paths 30 -file $out/fast_vm_paths.rpt
report_timing -from $vm -to $fast -max_paths 30 -file $out/vm_fast_paths.rpt
set util [report_utilization -return_string]
set fd [open $out/utilization.rpt w]; puts $fd $util; close $fd
jmr_resource_gate release $util
set route [report_route_status -return_string]
set fd [open $out/route_status.rpt w]; puts $fd $route; close $fd
report_drc -file $out/drc.rpt
set wns [get_property SLACK [get_timing_paths -setup -max_paths 1]]
set whs [get_property SLACK [get_timing_paths -hold -max_paths 1]]
puts "TIMING WNS=$wns WHS=$whs"
if {$wns eq "" || $whs eq "" || $wns < 0 || $whs < 0} {error "Timing failed; no release bit"}
if {![regexp {All user specified timing constraints are met} $timing]} {error "Timing summary (including pulse width) failed; no release bit"}
if {![regexp {# of nets with routing errors\.+\s*:\s*0\s} $route]} {error "Routing errors or unrecognized route report"}
if {[llength [get_drc_violations -quiet -filter {SEVERITY == Error}]]} {error "DRC errors; no release bit"}
write_checkpoint -force $out/qualified_post_route.dcp
write_bitstream -force $out/$stem.bit
puts "QUALIFIED_BIT=$out/$stem.bit WNS=$wns WHS=$whs"
exit
