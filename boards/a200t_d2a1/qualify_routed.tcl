# Requalify the complete routed design with the current interface budgets.
# This does not merge netlists or perform incremental synthesis.
set root [file normalize [lindex $argv 0]]
set out $root/build/a200t_d2a1/application
set board $root/boards/a200t_d2a1
set_param general.maxThreads 8
source $root/tools/board_flow/build_gates.tcl
open_checkpoint $out/routed.dcp
reset_timing -invalid
read_xdc $board/pins.xdc
read_xdc $board/synthesis.xdc
read_xdc $board/timing.xdc
read_xdc $root/constraints/native_argument_pipeline.xdc
set launch_nets {}
foreach path [get_timing_paths -setup -slack_lesser_than 0 -max_paths 200 -nworst 1] {
 set cell [get_cells -of_objects [get_property STARTPOINT_PIN $path] -filter {REF_NAME =~ FD*}]
 if {[llength $cell]} {
  foreach net [get_nets -of_objects [get_pins -of_objects $cell -filter {REF_PIN_NAME == Q}]] {lappend launch_nets $net}
 }
}
set launch_nets [lsort -unique $launch_nets]
puts "A200T_REPLICATE_DATA_LAUNCH $launch_nets"
if {[llength $launch_nets]} {
 # Replication requires post-place mode. Retain the complete placement and
 # optimized netlist, remove routing, then replicate the identified drivers.
 route_design -unroute
 phys_opt_design -force_replication_on_nets $launch_nets
 phys_opt_design -directive AggressiveExplore
 write_checkpoint -force $out/replicated_placed.dcp
 route_design -directive AggressiveExplore
 phys_opt_design -directive AggressiveExplore
}
write_checkpoint -force $out/routed.dcp
report_timing -to [get_ports {SD_SCK SD_MOSI SD_CS_N I2C_SCL I2C_SDA}] -max_paths 20 -file $out/peripheral_paths.rpt
report_timing -from $rx_regs -to $result_regs -max_paths 20 -file $out/memory_mailbox_paths.rpt
report_clocks -file $out/clocks.rpt
report_cdc -file $out/cdc.rpt
report_exceptions -file $out/exceptions.rpt
report_drc -file $out/drc.rpt
report_timing -max_paths 50 -file $out/paths.rpt
set timing [report_timing_summary -report_unconstrained -return_string]
set fd [open $out/timing.rpt w];puts $fd $timing;close $fd
set util [report_utilization -return_string]
set fd [open $out/utilization.rpt w];puts $fd $util;close $fd
jmr_resource_gate routed $util
set latches [get_cells -quiet -hier -filter {REF_NAME =~ LDCE* || REF_NAME =~ LDPE*}]
jmr_internal_timing_gate $timing $latches
set vm [get_clocks vm_clk]
set fast [get_clocks -of_objects [get_pins u_core/g_vmclk_div.u_vm_bufgce/I]]
if {[get_property PERIOD $vm]!=30.000 || [get_property WAVEFORM $vm] ne "0.000 5.000" || [get_property PERIOD $fast]!=10.000} {error "Shared core clock contract changed"}
set fb_brams [get_cells -hier -filter {NAME =~ *u_fb/* && REF_NAME =~ RAMB*}]
if {[llength $fb_brams]==0} {error "Framebuffer BRAM missing"}
foreach cell $fb_brams {
 if {[get_property WRITE_MODE_A $cell] ne "READ_FIRST"} {error "Framebuffer dirty comparison needs READ_FIRST: $cell"}
}
set route [report_route_status -return_string]
set fd [open $out/route.rpt w];puts $fd $route;close $fd
if {![regexp {# of nets with routing errors\.+\s*:\s*0\s} $route]} {error "Routing errors; no bit"}
if {[llength [get_drc_violations -quiet -filter {SEVERITY == Error}]]} {error "DRC errors; no bit"}
set wns [get_property SLACK [get_timing_paths -setup -max_paths 1]]
set whs [get_property SLACK [get_timing_paths -hold -max_paths 1]]
puts "A200T_TIMING WNS=$wns WHS=$whs"
if {$wns eq "" || $whs eq "" || $wns<0 || $whs<0 || ![regexp {All user specified timing constraints are met} $timing]} {error "Timing gate failed; no bit"}
write_bitstream -force $out/jmr_js_a200t_d2a1.bit
puts "A200T_BUILD_PASS $out/jmr_js_a200t_d2a1.bit"
