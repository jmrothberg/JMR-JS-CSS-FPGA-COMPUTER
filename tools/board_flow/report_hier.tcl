# Forensic hierarchy report on an EXISTING checkpoint - NO resynthesis.
# 2026-08-21: the fresh bit-fresh netlist still holds TWO framebuffer trees
# (u_core/u_fb AND u_corei_10/u_fb) and 1.84M LUT-as-logic. This report
# attributes both: per-instance utilization + whether u_corei_10 is a real
# cell in the final netlist or a synthesis-log phantom.
# Run:  make -C tools/board_flow hier      (~5 minutes, reads post_opt.dcp)
set ROOT [file normalize [file join [file dirname [info script]] ../..]]
set OUT  $ROOT/build/nexys_video
set DCP  $OUT/post_opt.dcp
if {![file exists $DCP]} { set DCP $OUT/post_synth.dcp }
puts "INFO: opening $DCP"
open_checkpoint $DCP
puts "=== duplicate-hierarchy check ==="
set dup [get_cells -quiet u_corei_10]
puts "u_corei_10 cell: [expr {$dup eq {} ? {ABSENT} : $dup}]"
puts "top-level cells:"
foreach c [get_cells] { puts "  $c  ([get_property REF_NAME [get_cells $c]])" }
report_utilization -hierarchical -hierarchical_depth 3 \
    -file $OUT/utilization_hier.rpt
puts "INFO: wrote $OUT/utilization_hier.rpt"
close_design
