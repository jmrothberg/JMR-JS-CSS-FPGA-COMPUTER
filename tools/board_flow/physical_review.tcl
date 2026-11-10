# Read-only physical evidence. Does not remap controls, move cells or relax timing.
proc jmr_physical_review {stage out} {
  if {$stage ni {place impl}} {error "Physical review requires placed/implemented design"}
  report_control_sets -verbose -file $out/control_sets_${stage}.rpt
  set pb [get_pblocks -quiet pb_sram_br]
  if {[llength $pb] != 1} {error "Expected exactly one existing pb_sram_br"}
  set range [get_property GRID_RANGES $pb]
  if {![regexp {^CLOCKREGION_X1Y3(:CLOCKREGION_X1Y3)?$} $range]} {
    error "Bridge pblock range changed unexpectedly: $range"
  }
  set members [get_cells -quiet -of_objects $pb]
  if {[llength $members] == 0} {error "Bridge pblock is empty"}
  foreach cell $members {
    set name [get_property NAME $cell]
    if {$name ne "u_sram_br" && ![string match "u_sram_br/*" $name]} {
      error "Unrelated cell added to bridge pblock: $name"
    }
  }
  report_utilization -pblocks $pb -file $out/bridge_utilization_${stage}.rpt
  set leaves [get_cells -quiet -hierarchical -filter {NAME =~ u_sram_br/* && IS_PRIMITIVE}]
  if {[llength $leaves] == 0} {error "Bridge has no mapped primitive cells"}
  set f [open $out/bridge_placement_${stage}.tsv w]
  puts $f "# range=$range soft=[get_property IS_SOFT $pb] primitive_count=[llength $leaves]"
  puts $f "cell\tprimitive\tloc\tbel\tclock_regions"
  foreach cell $leaves {
    set loc [get_property LOC $cell]
    set regions {}
    if {$loc ne ""} {set regions [get_clock_regions -quiet -of_objects [get_sites -quiet $loc]]}
    puts $f "[get_property NAME $cell]\t[get_property REF_NAME $cell]\t$loc\t[get_property BEL $cell]\t$regions"
  }
  close $f
  # Report both the 128-bit MIG boundary and the narrower shared client side.
  # Missing timing paths remain visible reports; only a later timing gate can qualify.
  report_timing -from $leaves -max_paths 20 -unique_pins -file $out/bridge_outgoing_${stage}.rpt
  report_timing -to $leaves -max_paths 20 -unique_pins -file $out/bridge_incoming_${stage}.rpt
}
