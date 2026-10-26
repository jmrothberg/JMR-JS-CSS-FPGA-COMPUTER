# Budget checks shared by synthesis, placement and final implementation.
# Defaults are physical part limits; a campaign can reserve routing headroom
# with JMR_MAX_LUTS / JMR_MAX_BRAM / JMR_MAX_SLICES.
proc jmr_resource_gate {stage report} {
  foreach {label pattern env_key fallback} {
    LUTs {\|\s*Slice LUTs\*?\s*\|\s*([0-9,]+)} JMR_MAX_LUTS 134600
    BRAM {\|\s*Block RAM Tile\s*\|\s*([0-9,.]+)} JMR_MAX_BRAM 365
  } {
    # Raw synthesis includes logic removed by opt_design. Keep the tighter
    # JMR_MAX_LUTS gate for the placed and routed design, with an optional
    # separate synthesis ceiling; BRAM still has the same hard budget.
    if {$stage eq "synth" && $label eq "LUTs" &&
        [info exists ::env(JMR_MAX_SYNTH_LUTS)]} {
      set env_key JMR_MAX_SYNTH_LUTS
    }
    if {![regexp $pattern $report match used]} {
      error "Cannot read $label utilization at $stage; refusing ungated implementation"
    }
    set used [string map {, {}} $used]
    set limit $fallback
    if {[info exists ::env($env_key)] && $::env($env_key) ne ""} {
      set limit $::env($env_key)
    }
    if {![string is double -strict $limit] || $limit <= 0 || $limit > $fallback} {
      error "Invalid $env_key=$limit (physical limit $fallback)"
    }
    puts "BUDGET $stage $label=$used limit=$limit"
    if {$used > $limit} { error "$stage $label=$used exceeds budget $limit" }
  }
  # Packing is meaningful after placement, not at synthesis.
  if {$stage ne "synth"} {
    if {![regexp {\|\s*Slice\s*\|\s*([0-9,]+)} $report match used]} {
      error "Cannot read occupied slices at $stage"
    }
    set used [string map {, {}} $used]
    set limit 33650
    if {[info exists ::env(JMR_MAX_SLICES)] && $::env(JMR_MAX_SLICES) ne ""} {
      set limit $::env(JMR_MAX_SLICES)
    }
    if {![string is integer -strict $limit] || $limit <= 0 || $limit > 33650} {
      error "Invalid JMR_MAX_SLICES=$limit"
    }
    puts "BUDGET $stage slices=$used limit=$limit"
    if {$used > $limit} { error "$stage slices=$used exceeds budget $limit" }
  }
}

proc jmr_stop_after {stage} {
  if {[info exists ::env(JMR_STOP_AFTER)] && $::env(JMR_STOP_AFTER) eq $stage} {
    puts "STOP_AFTER $stage: checkpoint and reports saved; no bit published"
    exit 0
  }
}

proc jmr_placed_run_ready {status progress} {
  # The next step depends on whether physical optimization is enabled.
  return [expr {$progress ne "0%" && $status in {
    {Not started phys_opt_design} {Not started route_design}
  }}]
}
