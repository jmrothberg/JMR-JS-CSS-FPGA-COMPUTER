# Place and route <run>/optimized.dcp with the directives that closed Run78.
# The only floorplan is the SRAM-bridge pblock from constraints/nexys_video.xdc.
# usage: -tclargs <run dir> [place directive] [output dir]
# A second placement of the same netlist goes in its own output dir.
set SRC [file normalize [lindex $argv 0]]
set place [expr {[llength $argv] > 1 ? [lindex $argv 1] : "Explore"}]
set B [expr {[llength $argv] > 2 ? [file normalize [lindex $argv 2]] : $SRC}]
file mkdir $B
set ROOT [file normalize [file dirname [info script]]/../..]
set_param general.maxThreads 8
open_checkpoint $SRC/optimized.dcp
source $ROOT/tools/board_flow/build_gates.tcl
set ::env(JMR_MAX_LUTS) 106500; set ::env(JMR_MAX_BRAM) 365; set ::env(JMR_MAX_SLICES) 32900
if {[lsort [get_pblocks -quiet]] ne {pb_sram_br}} {error "expected only the bridge pblock"}

place_design -directive $place
write_checkpoint -force $B/placed.dcp
jmr_resource_gate place [report_utilization -return_string]
phys_opt_design -directive Explore
route_design -directive Explore
if {[get_property SLACK [get_timing_paths -setup -max_paths 1]] < 0} {
  phys_opt_design -directive AlternateReplication
}
write_checkpoint -force $B/routed.dcp
set audio_audit_out $B
source $ROOT/tools/board_flow/audit_audio_reset.tcl
report_timing_summary -report_unconstrained -file $B/routed_timing.rpt
report_timing -max_paths 50 -input_pins -file $B/routed_paths.rpt
report_route_status -file $B/route_status.rpt
report_utilization -file $B/routed_utilization.rpt
jmr_resource_gate final [report_utilization -return_string]
puts "ROUTED_SETUP=[get_property SLACK [get_timing_paths -setup -max_paths 1]]"
puts "ROUTED_HOLD=[get_property SLACK [get_timing_paths -hold -max_paths 1]]"
exit
