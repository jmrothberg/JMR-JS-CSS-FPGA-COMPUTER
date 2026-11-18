set root [file normalize [lindex $argv 0]]
set out [file normalize [lindex $argv 1]]
set board $root/boards/a200t_d2a1
file mkdir $out
create_project a200t_d2a1 $out/vivado -part xc7a200tfbg484-1 -force
set_param general.maxThreads 2
source $root/tools/board_flow/build_gates.tcl
# All software/core sources remain shared with Vision. Only the physical
# shell, input adapter and memory interface live in the new board folder.
set files [glob $root/rtl/engines/*pkg.sv]
lappend files $root/rtl/engines/jmr_value.sv
foreach dir {engines phys video} {
 foreach f [glob $root/rtl/$dir/*.sv] {
  if {$f ni $files} {lappend files $f}
 }
}
lappend files $root/rtl/jmr_js_core.sv
set files [concat $files [glob $board/rtl/*.sv]]
add_files $files
add_files [glob $root/vectors/*.hex]
set_property top top_a200t_d2a1 [current_fileset]
set_property verilog_define SYNTHESIS [current_fileset]
add_files -fileset constrs_1 $board/pins.xdc
add_files -fileset constrs_1 $board/synthesis.xdc
update_compile_order -fileset sources_1
# Stage ROMs only inside this build; never rewrite Vision source directories.
foreach f [glob $root/vectors/*.hex] {file copy -force $f $out/[file tail $f]}
cd $out
synth_design -top top_a200t_d2a1 -part xc7a200tfbg484-1 -flatten_hierarchy rebuilt -directive AreaOptimized_high
write_checkpoint -force $out/synth.dcp
report_utilization -file $out/synth_utilization.rpt
jmr_resource_gate synth [report_utilization -return_string]
read_xdc $board/timing.xdc
read_xdc $root/constraints/native_argument_pipeline.xdc
opt_design -directive ExploreArea
write_checkpoint -force $out/opt.dcp
set_param general.maxThreads 8
place_design -directive ExtraTimingOpt
phys_opt_design -directive AggressiveExplore
write_checkpoint -force $out/placed.dcp
route_design -directive AggressiveExplore
phys_opt_design -directive AggressiveExplore
write_checkpoint -force $out/routed.dcp
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
write_bitstream $out/jmr_js_a200t_d2a1.bit
puts "A200T_BUILD_PASS $out/jmr_js_a200t_d2a1.bit"
