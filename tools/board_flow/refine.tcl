# Post-route repair for a design that misses setup by a few tenths of a ns:
# physical optimization and re-route, repeated until timing is met or it
# stops improving, then repairs any hold violation the repair introduced.
# Writes <run>/refined.dcp, and continues from it if run again.
# No constraint is changed.
# usage: -tclargs <run dir>
set B [file normalize [lindex $argv 0]]
set_param general.maxThreads 8
open_checkpoint [expr {[file exists $B/refined.dcp] ? "$B/refined.dcp" : "$B/routed.dcp"}]
proc wns {} {get_property SLACK [get_timing_paths -setup -max_paths 1]}
set best [wns]
puts "REFINE start setup=$best"
foreach d {AggressiveExplore AlternateReplication Explore {-placement_opt -routing_opt -rewire -critical_cell_opt} AggressiveFanoutOpt Explore} {
  if {$best >= 0} break
  if {[string index $d 0] eq "-"} {phys_opt_design {*}$d} else {phys_opt_design -directive $d}
  route_design
  set now [wns]
  puts "REFINE $d setup=$now hold=[get_property SLACK [get_timing_paths -hold -max_paths 1]]"
  if {$now > $best} {set best $now; write_checkpoint -force $B/refined.dcp}
}
if {[file exists $B/refined.dcp]} {open_checkpoint $B/refined.dcp}
if {[get_property SLACK [get_timing_paths -hold -max_paths 1]] < 0} {
  phys_opt_design -hold_fix
  route_design
  write_checkpoint -force $B/refined.dcp
}
report_timing_summary -report_unconstrained -file $B/refined_timing.rpt
report_timing -max_paths 50 -input_pins -file $B/refined_paths.rpt
report_route_status -file $B/refined_route_status.rpt
puts "REFINED_SETUP=[wns]"
puts "REFINED_HOLD=[get_property SLACK [get_timing_paths -hold -max_paths 1]]"
exit
