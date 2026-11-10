# Run after opening the integrated synthesized/routed design. No netlist edits.
# Reloads ONLY the exact paired boundary exceptions; session variables from XDC
# reading are not assumed to survive checkpoint serialization.
proc audio_require {ok message} {if {!$ok} {error "Audio reset audit: $message"}}
set ff0 [get_cells -quiet -hierarchical -regexp {^mrst_sync_reg\[0\]$}]
set ff1 [get_cells -quiet -hierarchical -regexp {^mrst_sync_reg\[1\]$}]
audio_require [expr {[llength $ff0]==1 && [llength $ff1]==1}] "expected exact two top-level reset FFs"
foreach ff [list $ff0 $ff1] {
 audio_require [expr {[string toupper [get_property ASYNC_REG $ff]] in {TRUE 1}}] "missing ASYNC_REG on $ff"
 audio_require [expr {[get_property REF_NAME $ff] eq "FDCE"}] "$ff must have asynchronous clear-to-zero"
 set init [string toupper [get_property INIT $ff]]
 audio_require [expr {$init eq "1'B0" || $init eq "1'H0" || $init eq "0"}] "$ff INIT is not zero"
 set clocks [get_clocks -quiet -of_objects [get_pins $ff/C]]
 audio_require [expr {[llength $clocks]==1}] "$ff clock missing/ambiguous"
 audio_require [expr {[get_property NAME $clocks] eq "mclk_raw"}] "$ff is not on mclk_raw"
 audio_require [expr {abs([get_property PERIOD $clocks]-83.333333)<0.01}] "$ff audio clock period changed"
}
set d0 [get_pins -quiet -hierarchical -regexp {^mrst_sync_reg\[0\]/D$}]
set clear [get_pins -quiet -hierarchical -regexp {^mrst_sync_reg\[[01]\]/CLR$}]
audio_require [expr {[llength $d0]==1 && [llength $clear]==2}] "boundary pin count"
set upstream [get_property NAME [get_pins -quiet -leaf -of_objects [get_nets -quiet -segments -of_objects [get_pins $ff1/D]] -filter {DIRECTION == OUT}]]
audio_require [expr {[llength $upstream]==1 && [lindex $upstream 0] eq "mrst_sync_reg\[0\]/Q"}] "second stage must receive only first-stage Q"
set release_sources [get_property NAME [get_pins -quiet -leaf -of_objects [get_nets -quiet -segments -of_objects $d0] -filter {DIRECTION == OUT}]]
audio_require [expr {[llength $release_sources]==1 && [lindex $release_sources 0] eq "core_reset_release_reg\[1\]/Q"}] "first stage must receive qualified core reset Q"
set n0 [get_nets -of_objects [get_pins $ff0/CLR]]
set n1 [get_nets -of_objects [get_pins $ff1/CLR]]
audio_require [expr {[get_property NAME $n0] eq [get_property NAME $n1]}] "reset FFs do not share common asynchronous assertion"
set raw_sources [get_property NAME [all_fanin -flat -startpoints_only -only_cells -to [get_pins $ff0/CLR]]]
audio_require [expr {[lsearch -exact $raw_sources {core_reset_release_reg[1]}]<0}] "clear still driven by core-qualified release instead of common raw reset"
# A fresh DCP process does not preserve Tcl variables. Apply the exact paired
# fail-closed boundary declarations again, then audit the resulting timing.
# This proves qualification coverage after reload, not persisted exception
# provenance in the checkpoint; preserve the exception report as evidence.
source [file join [file dirname [info script]] audio_reset_exceptions.xdc]
audio_require [expr {[lsort [get_property NAME $audio_reset_first_d]] eq [lsort [get_property NAME $d0]]}] "unexpected first-D exception endpoints"
audio_require [expr {[lsort [get_property NAME $audio_reset_sync_clr]] eq [lsort [get_property NAME $clear]]}] "unexpected CLR exception endpoints (possible leaf waiver)"
foreach kind {max min} {
 set p [get_timing_paths -delay_type $kind -from [get_pins $ff0/Q] -to [get_pins $ff1/D] -max_paths 1]
 audio_require [expr {[llength $p]==1}] "second-stage $kind path is not timed"
}
set leaf_count 0
foreach pin [all_fanout -flat -endpoints_only -from [get_pins $ff1/Q]] {
 set ref [get_property REF_PIN_NAME $pin]
 if {$ref ni {D CE R S CLR PRE}} {continue}
 incr leaf_count
 foreach kind {max min} {
  set paths [get_timing_paths -delay_type $kind -from [get_pins $ff1/Q] -to $pin -max_paths 1]
  audio_require [expr {[llength $paths]==1}] "leaf $pin has no timed $kind reset path"
 }
}
audio_require [expr {$leaf_count>0}] "audio leaf reset fanout missing"
if {![info exists audio_audit_out]} {set audio_audit_out [pwd]}
file mkdir $audio_audit_out
report_exceptions -file [file join $audio_audit_out audio_reset_exceptions.rpt]
puts "PASS audio reset: exact boundary constraints reloaded; second-stage and $leaf_count leaf paths timed (persisted exception provenance not asserted)"
