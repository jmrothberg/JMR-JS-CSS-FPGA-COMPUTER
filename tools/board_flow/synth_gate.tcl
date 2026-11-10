# After synthesis: check the VM survived mapping, report logic depth per module,
# run opt_design, and write <run>/optimized.dcp. No placement.
# usage: -tclargs <run dir>
set B [file normalize [lindex $argv 0]]
set ROOT [file normalize [file dirname [info script]]/../..]
set_param general.maxThreads 4
open_checkpoint $B/post_synth.dcp

# Synthesis has silently pruned the VM before. Fail if a block is too small
# or a register the loader depends on is gone.
proc liveness {tag} {
  set bad {}
  foreach {scope min} {u_core/u_vm 15000 u_core/u_vm/u_exec64 5500 u_core/u_cons 2300 u_core/u_toolbox 1900 u_core/u_finder_fs 800} {
    set n [llength [get_cells -quiet -hier -filter "IS_SEQUENTIAL && NAME =~ $scope/*"]]
    if {$n < $min} {lappend bad "$scope has $n flops, expected at least $min"}
  }
  foreach pat {u_core/u_cons/image_code_valid_reg* u_core/u_vm/image_code_valid_reg* u_core/u_vm/running_reg* u_core/u_vm/code_raddr_ff_reg* u_core/u_cons/host_receive_request_reg* u_core/u_rast/* u_core/u_mouse_events/* u_core/u_vm/json_mem_reg*} {
    if {![llength [get_cells -quiet -hier -filter "IS_PRIMITIVE && NAME =~ $pat"]]} {lappend bad "$pat absent"}
  }
  if {[llength $bad]} {error "LIVENESS_FAIL $tag: [join $bad {; }]"}
  puts "LIVENESS_PASS $tag"
}

# Worst logic depth per module on the 100 MHz clock. 13 or more will not route.
proc depth {tag} {
  array set worst {}; array set deep {}
  foreach p [get_timing_paths -setup -max_paths 20000 -nworst 1 -filter {REQUIREMENT > 9.9 && REQUIREMENT < 10.1}] {
    set l [get_property LOGIC_LEVELS $p]
    set e [split [get_property ENDPOINT_PIN $p] /]
    set m [expr {[lindex $e 0] eq "u_core" && [llength $e] > 2 ? "u_core/[lindex $e 1]" : [lindex $e 0]}]
    if {![info exists worst($m)] || $worst($m) < $l} {set worst($m) $l}
    if {$l >= 13} {incr deep($m)}
  }
  foreach m [lsort [array names deep]] {puts "DEPTH $tag $m worst=$worst($m) paths_13_or_more=$deep($m)"}
}

liveness synth
depth synth
set audio_audit_out $B
source $ROOT/tools/board_flow/audit_audio_reset.tcl
opt_design -directive ExploreArea
liveness opt
depth opt
write_checkpoint -force $B/optimized.dcp
report_utilization -hierarchical -hierarchical_depth 3 -file $B/opt_utilization_hier.rpt
report_timing -max_paths 50 -input_pins -file $B/opt_paths.rpt
puts "OPT_SETUP_ESTIMATE=[get_property SLACK [get_timing_paths -setup -max_paths 1]]"
exit
