# Preserve the completed optimization before any checked netlist ECO.
if {[info exists out]} {write_checkpoint -force $out/post_phys_before_cascade_repair.dcp}
# O's placer cloned one 5-input address mux independently for two cascaded
# RAMB36 upper halves. AMD requires the same logical ADDR15 net on each
# cascade pair even when the muxes are identical. Collapse only those two
# connections after checking exact LUT functions and every input net.
proc checked_cascade_lut {pin} {
 set nets [get_nets -segments -of_objects $pin]
 set drivers [get_pins -leaf -of_objects $nets -filter {DIRECTION == OUT}]
 if {[llength $drivers] != 1} {error "Expected one address LUT driver for $pin"}
 set cell [get_cells -of_objects $drivers]
 if {[get_property REF_NAME $cell] ne "LUT5"} {error "Unqualified cascade driver $cell"}
 set signature [list [get_property REF_NAME $cell] [get_property INIT $cell]]
 foreach i {I0 I1 I2 I3 I4} {
  lappend signature [lsort [get_nets -segments -of_objects [get_pins $cell/$i]]]
 }
 return [list $cell $signature]
}
proc repair_o_cascade {} {
 set protected_nets {}
 set protected_cells {}
 foreach suffix {4 5} {
  set low [get_pins [format {u_core/u_fb/mem0_c0_reg_0_%s/ADDRARDADDR[15]} $suffix]]
  set high [get_pins [format {u_core/u_fb/mem0_c0_reg_1_%s/ADDRARDADDR[15]} $suffix]]
  if {[llength $low] != 1 || [llength $high] != 1} {error "Missing O cascade pair $suffix"}
  set target [get_nets -of_objects $low]
  set old [get_nets -of_objects $high]
  if {$target eq $old} {continue}
  lassign [checked_cascade_lut $low] canonical signature
  lassign [checked_cascade_lut $high] replica other_signature
  if {$signature ne $other_signature} {error "Cascade muxes are not exactly equivalent: $canonical $replica"}
  puts "VERIFIED_CASCADE_EQUIVALENCE canonical=$canonical replica=$replica signature=$signature"
  disconnect_net -net $old -objects $high
  connect_net -net $target -objects $high
  if {[get_nets -of_objects $high] ne $target} {error "Cascade reconnection did not apply: $high"}
  lappend protected_nets $target
  lappend protected_cells $canonical
  puts "REPAIRED_CASCADE_PAIR=$suffix PIN=$high NET=$target"
 }
 foreach net [lsort -unique $protected_nets] {set_property DONT_TOUCH true $net}
 foreach cell [lsort -unique $protected_cells] {set_property DONT_TOUCH true $cell}
 report_drc -checks [get_drc_checks REQP-1962]
 if {[llength [get_drc_violations -quiet -filter {NAME =~ REQP-1962*}]]} {error "Cascade DRC remains"}
}
repair_o_cascade
# A second supported algorithm may close a small remaining real setup gap.
# Preserve the first result, and never add or relax a timing exception.
set remaining [get_property SLACK [get_timing_paths -setup -max_paths 1]]
if {$remaining < 0 && $remaining > -0.5} {
 puts "SECOND_PHYSICAL_REFINEMENT initial_slack=$remaining directive=AlternateReplication"
 write_checkpoint -force $out/post_phys_first_repaired.dcp
 phys_opt_design -directive AlternateReplication
 repair_o_cascade
 write_checkpoint -force $out/post_phys_second_repaired.dcp
}
