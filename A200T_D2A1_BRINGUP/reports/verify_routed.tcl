# Independent constraint reload after physical replication and bit generation.
# Do not modify the netlist, checkpoint, bit or original qualification reports.
set root [file normalize [lindex $argv 0]]
set out $root/build/a200t_d2a1/application
set board $root/boards/a200t_d2a1
source $root/tools/board_flow/build_gates.tcl
open_checkpoint $out/routed.dcp
reset_timing -invalid
foreach f [list $board/pins.xdc $board/synthesis.xdc $board/timing.xdc $root/constraints/native_argument_pipeline.xdc] {read_xdc $f}
set timing [report_timing_summary -report_unconstrained -return_string]
set fd [open $out/constraint_reload_timing.rpt w];puts $fd $timing;close $fd
jmr_internal_timing_gate $timing [get_cells -quiet -hier -filter {REF_NAME =~ LDCE* || REF_NAME =~ LDPE*}]
set wns [get_property SLACK [get_timing_paths -setup -max_paths 1]]
set whs [get_property SLACK [get_timing_paths -hold -max_paths 1]]
if {$wns eq "" || $whs eq "" || $wns<0 || $whs<0 || ![regexp {All user specified timing constraints are met} $timing]} {error "Fresh constraints fail timing"}
set fd [open $out/constraint_reload_ports.rpt w];close $fd
foreach port [get_ports {SD_SCK SD_MOSI SD_CS_N I2C_SCL I2C_SDA}] {
 set path [get_timing_paths -to $port -max_paths 1]
 if {[llength $path]!=1 || [get_property REQUIREMENT $path]!=10.000 || [get_property SLACK $path]<0} {error "Missing or failed 10 ns pad budget: $port"}
 report_timing -to $port -max_paths 1 -append -file $out/constraint_reload_ports.rpt
}
set mailbox [get_timing_paths -from $rx_regs -to $result_regs -max_paths 1]
if {[llength $mailbox]!=1 || [get_property REQUIREMENT $mailbox]!=20.000 || [get_property SLACK $mailbox]<0} {error "Missing or failed receive-mailbox settling budget"}
puts "A200T_RELOAD_PASS WNS=$wns WHS=$whs; all five peripheral pads and receive mailbox bounded"
