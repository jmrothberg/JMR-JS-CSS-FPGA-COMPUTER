# Run73o: finish the saved whole-board route without changing RTL or clocks.
# Args: repository root, input routed DCP, fresh output directory.
set root [lindex $argv 0]
set input [lindex $argv 1]
set out [lindex $argv 2]
if {[file exists $out] && [llength [glob -nocomplain -directory $out *]]} {error "Choose a fresh output directory; completed work is preserved"}
file mkdir $out
set_param general.maxThreads 8
source $root/tools/board_flow/build_gates.tcl
open_checkpoint $input
read_xdc $root/constraints/native_argument_pipeline.xdc
set regs [get_cells -quiet -hierarchical -filter {NAME =~ *call_arg_q_reg* && IS_SEQUENTIAL}]
if {[llength $regs] == 0 || [llength [get_clocks -quiet vm_clk]] != 1} {error "Missing native operand timing objects"}
puts "CHECKED_NATIVE_ARGUMENT_REGISTERS=[llength $regs]"
report_clocks -file $out/clocks.rpt
report_exceptions -file $out/exceptions.rpt
report_timing_summary -report_unconstrained -file $out/before_timing.rpt
report_timing -max_paths 100 -unique_pins -file $out/before_paths.rpt
phys_opt_design -directive AggressiveExplore
source $root/tools/board_flow/run73o_repair_cascade.tcl
write_checkpoint -force $out/post_phys_opt.dcp
report_timing_summary -report_unconstrained -file $out/after_phys_timing.rpt
route_design -preserve
write_checkpoint -force $out/post_route.dcp
report_timing_summary -report_unconstrained -file $out/timing.rpt
report_timing -max_paths 100 -unique_pins -file $out/paths.rpt
report_utilization -file $out/utilization.rpt
set util [report_utilization -return_string]
jmr_resource_gate route $util
report_route_status -file $out/route_status.rpt
report_drc -file $out/drc.rpt
set wns [get_property SLACK [get_timing_paths -setup -max_paths 1]]
set whs [get_property SLACK [get_timing_paths -hold -max_paths 1]]
puts "TIMING WNS=$wns WHS=$whs"
if {$wns eq "" || $whs eq "" || $wns < 0 || $whs < 0} {error "Timing failed; no release bit"}
set errs [get_drc_violations -quiet -filter {SEVERITY == Error}]
if {[llength $errs]} {error "DRC errors; no release bit"}
puts "FINALIZED_DCP=$out/post_route.dcp; run qualify_routed_bit.tcl to generate a gated bitstream"
exit
