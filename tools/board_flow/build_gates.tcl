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

# A passing WNS does not cover paths excluded by missing clocks. These are
# internal checks; ordinary asynchronous external I/O is assessed separately.
proc jmr_internal_timing_gate {report latch_cells} {
  if {[llength $latch_cells] != 0} {
    error "Unexpected inferred latches: $latch_cells"
  }
  foreach check {no_clock unconstrained_internal_endpoints} {
    set pattern [format {checking %s \(([0-9]+)\)} $check]
    set matches [regexp -all -inline $pattern $report]
    if {[llength $matches] == 0} {
      error "Missing internal timing coverage check: $check"
    }
    foreach {heading count} $matches {
      if {$count != 0} {error "Internal timing coverage failed: $check=$count"}
    }
  }
}

# ACK protocol holds audio data; actual routed paths must still have a bounded
# settling time. Empty/false-pathed collections are a failure, not a waiver.
proc jmr_audio_payload_gate {out} {
  set src [get_cells -hierarchical -regexp {.*u_exec64/snd_(ch|freq|vol|frames|slide)_reg(\[[0-9]+\])?}]
  set dst {}
  # Require all logical capture families, allowing synthesis to prune constant
  # phase bits but never allowing the entire phase-history family to disappear.
  foreach family {vfreq vvol vframes vslide vphase ph23_q} {
    set regs [get_cells -quiet -hierarchical -filter {IS_SEQUENTIAL} -regexp ".*u_psg/${family}_reg.*"]
    if {[llength $regs] == 0} {error "Audio capture family missing: $family"}
    set dst [concat $dst $regs]
    foreach reg $regs {
      set family_pins [get_pins -of_objects $reg -filter {REF_PIN_NAME == D || REF_PIN_NAME == CE || REF_PIN_NAME == R || REF_PIN_NAME == S}]
      if {[llength $family_pins] == 0} {
        error "Audio capture register has no sequential payload pins: $reg"
      }
      set paths [get_timing_paths -delay_type max -from $src -to $family_pins -max_paths 1]
      if {[llength $paths] == 0} {
        error "Audio capture register has no timed payload path: $reg"
      }
    }
  }
  set pins [get_pins -of_objects $dst -filter {REF_PIN_NAME == D || REF_PIN_NAME == CE || REF_PIN_NAME == R || REF_PIN_NAME == S}]
  if {[llength $src] != 38 || [llength $pins] == 0} {
    error "Audio held-payload endpoints missing or changed: source=[llength $src], destination=[llength $pins]"
  }
  foreach reg $src {
    set paths [get_timing_paths -delay_type max -from $reg -to $pins -max_paths 1]
    if {[llength $paths] == 0} {error "Audio payload has no timed capture path: $reg"}
    set requirement [get_property REQUIREMENT $paths]
    set slack [get_property SLACK $paths]
    if {![string is double -strict $requirement] || $requirement > 83.334 ||
        ![string is double -strict $slack] || $slack < 0} {
      error "Audio payload settling bound failed: $reg requirement=$requirement slack=$slack"
    }
  }
  report_timing -delay_type max -from $src -to $pins -max_paths 100 -file $out/audio_payload_paths.rpt
}
