# Vivado batch build for Digilent Nexys Video (XC7A200T) — standalone console
# Usage: vivado -mode batch -source vivado_build.tcl -tclargs ROOT OUTDIR [fresh]
#   Default: reuse OUT/vivado if it exists (skip MIG recreate; incremental DCP).
#   Third arg "fresh": create_project -force (MIG/XDC/file-list change).

set ROOT [lindex $argv 0]
set OUT  [lindex $argv 1]
set FRESH 0
if {[llength $argv] >= 3 && [lindex $argv 2] eq "fresh"} {
  set FRESH 1
}
file mkdir $OUT
# NEVER-SMASH GUARD (2026-08-27, user directive): before this flow touches
# anything, auto-archive whatever bit/bin the PREVIOUS run left in impl_1.
# Runs unconditionally — a launch can no longer destroy an untested bit.
set _prev_impl "$OUT/vivado/jmr_nexys_video.runs/impl_1"
if {[file exists "$_prev_impl/top_nexys_video.bit"]} {
  set _stamp [clock format [clock seconds] -format %Y%m%d_%H%M%S]
  file mkdir "$ROOT/build/bits/auto"
  foreach _f {top_nexys_video.bit top_nexys_video.bin} {
    if {[file exists "$_prev_impl/$_f"]} {
      file copy -force "$_prev_impl/$_f" "$ROOT/build/bits/auto/${_stamp}_$_f"
    }
  }
  puts "INFO: never-smash: previous impl bit auto-archived to build/bits/auto/${_stamp}_*"
}

if {[llength [get_parts -quiet xc7a200tsbg484-1]] == 0} {
  puts "ERROR: xc7a200tsbg484-1 not installed — enable Artix-7 in xsetup"
  exit 1
}

# 2026-08-19: synth_design technology mapping OOM (tcmalloc 5.2 GB, RSS
# 58→114 GB) with 7 synth workers. UG901 has one knob for all of
# synth_design (`general.maxThreads`) — there is no "mapping only" cap.
# Cap synth threads; leave impl place/route at 8. `-jobs` is parallel
# *runs*, not mapping workers — do not cap impl jobs for this OOM.
# Override synth cap: JMR_VIVADO_ALLOW_WIDE=1.
# NEW: impl strategy (congestion campaign): JMR_VIVADO_STRATEGY names a
# Vivado impl_1 strategy, e.g. Performance_Explore or
# Congestion_SpreadLogic_low. Default placement failed/died 3 of the
# last 4 routes (35, 41, 45); directed placements route.
if {[info exists ::env(JMR_VIVADO_STRATEGY)] && $::env(JMR_VIVADO_STRATEGY) ne ""} {
  set JMR_STRATEGY $::env(JMR_VIVADO_STRATEGY)
} else {
  set JMR_STRATEGY ""
}

# NEW: build-variant defines (JMR_VIVADO_DEFINES=JMR_NOCACHE = the
# PACMAN-freeze read-cache A/B build)
if {[info exists ::env(JMR_VIVADO_DEFINES)] && $::env(JMR_VIVADO_DEFINES) ne ""} {
  set JMR_DEFINES [split $::env(JMR_VIVADO_DEFINES) ","]
} else {
  set JMR_DEFINES {}
}

set SYNTH_THREADS 2
if {[info exists ::env(JMR_VIVADO_SYNTH_THREADS)] && $::env(JMR_VIVADO_SYNTH_THREADS) ne ""} {
  set SYNTH_THREADS $::env(JMR_VIVADO_SYNTH_THREADS)
} elseif {[info exists ::env(JMR_VIVADO_THREADS)] && $::env(JMR_VIVADO_THREADS) ne ""} {
  set SYNTH_THREADS $::env(JMR_VIVADO_THREADS)
}
set IMPL_THREADS 8
if {[info exists ::env(JMR_VIVADO_IMPL_THREADS)] && $::env(JMR_VIVADO_IMPL_THREADS) ne ""} {
  set IMPL_THREADS $::env(JMR_VIVADO_IMPL_THREADS)
}
set SYNTH_JOBS 1
set IMPL_JOBS 1
if {[info exists ::env(JMR_VIVADO_JOBS)] && $::env(JMR_VIVADO_JOBS) ne ""} {
  # Parallel runs (impl), not synth mapping workers.
  set IMPL_JOBS $::env(JMR_VIVADO_JOBS)
}
set wide 0
if {[info exists ::env(JMR_VIVADO_ALLOW_WIDE)] && $::env(JMR_VIVADO_ALLOW_WIDE) ne ""} {
  set wide 1
}
if {!$wide && $SYNTH_THREADS > 2} {
  puts "WARNING: synth threads=$SYNTH_THREADS capped to 2 (16:17 tech-map OOM). JMR_VIVADO_ALLOW_WIDE=1 to override."
  set SYNTH_THREADS 2
}
set_param general.maxThreads $SYNTH_THREADS
puts "INFO: synth threads=$SYNTH_THREADS impl threads=$IMPL_THREADS synth_jobs=$SYNTH_JOBS impl_jobs=$IMPL_JOBS"

# Font ROM next to scanout AND next to the VM ($readmemh is relative to .sv)
file copy -force $ROOT/vectors/font_rom.hex $ROOT/rtl/video/font_rom.hex
file copy -force $ROOT/vectors/font_rom.hex $ROOT/rtl/engines/font_rom.hex
# NEW: INVADERS bytecode for jmr_js_vm $readmemh
file copy -force $ROOT/vectors/invaders_jsb.hex $ROOT/rtl/engines/invaders_jsb.hex

set XPR $OUT/vivado/jmr_nexys_video.xpr
set REUSE [expr {[file exists $XPR] && !$FRESH}]

proc jmr_ensure_file {path} {
  if {![file exists $path]} {
    puts "ERROR: missing source $path"
    exit 1
  }
  if {[llength [get_files -quiet $path]] == 0} {
    add_files $path
  }
}

proc jmr_add_sources {ROOT} {
  set DVI $ROOT/third_party/digilent_rgb2dvi/src
  foreach f [list \
      $DVI/DVI_Constants.vhd \
      $DVI/SyncAsync.vhd \
      $DVI/SyncAsyncReset.vhd \
      $DVI/ClockGen.vhd \
      $DVI/TMDS_Encoder.vhd \
      $DVI/OutputSERDES.vhd \
      $DVI/rgb2dvi.vhd \
      $ROOT/rtl/video/jmr_rgb2dvi_wrap.vhd \
      $ROOT/rtl/video/jmr_text_hdmi_scanout.sv \
      $ROOT/rtl/video/font_rom.hex \
      $ROOT/rtl/engines/jmr_keyboard_fifo.sv \
      $ROOT/rtl/engines/jmr_video_vram.sv \
      $ROOT/rtl/engines/jmr_console_engine.sv \
      $ROOT/rtl/engines/jmr_mini_fb.sv \
      $ROOT/rtl/engines/jmr_raster_engine.sv \
      $ROOT/rtl/engines/jmr_rectdemo_engine.sv \
      $ROOT/rtl/engines/jmr_value.sv \
      $ROOT/rtl/engines/jmr_js_vm_pkg.sv \
      $ROOT/rtl/engines/jmr_js_vm_exec64.sv \
      $ROOT/rtl/engines/jmr_js_vm.sv \
      $ROOT/rtl/engines/font_rom.hex \
      $ROOT/rtl/engines/invaders_jsb.hex \
      $ROOT/rtl/engines/jmr_palette_bram.sv \
      $ROOT/rtl/engines/jmr_fb_present.sv \
      $ROOT/rtl/engines/jmr_fb_scanout.sv \
      $ROOT/rtl/engines/jmr_ddr3_sram_bridge.sv \
      $ROOT/rtl/engines/jmr_uart_link.sv \
      $ROOT/rtl/engines/jmr_ft245_async.sv \
      $ROOT/rtl/engines/storage_engine.sv \
      $ROOT/rtl/phys/ps2_rx.sv \
      $ROOT/rtl/phys/ps2_decode.sv \
      $ROOT/rtl/phys/jmr_i2c_master.sv \
      $ROOT/rtl/phys/jmr_i2c_joy.sv \
      $ROOT/rtl/phys/sd_spi_master.sv \
      $ROOT/rtl/jmr_js_core.sv \
      $ROOT/rtl/top_nexys_video.sv \
  ] {
    jmr_ensure_file $f
  }
  # NEW: jmr_ps2_host removed from build — BASIC T100 is RX-only (file kept)
  # LED tests (tools/pmod_input_test, hid_led_blink) are a different
  # project — do not add those paths to this JS board file list.
  if {[llength [get_files -quiet -of_objects [get_filesets constrs_1] \
      $ROOT/constraints/nexys_video.xdc]] == 0} {
    add_files -fileset constrs_1 $ROOT/constraints/nexys_video.xdc
  }
}

if {$REUSE} {
  puts "INFO: reusing $XPR (incremental). make bit-fresh if MIG/XDC/file list changed."
  open_project $XPR
  # Project may have stored 8; pin the synth OOM cap until impl.
  set_param general.maxThreads $SYNTH_THREADS
} else {
  if {$FRESH} {
    puts "INFO: bit-fresh — create_project -force (MIG regenerated)"
  } else {
    puts "INFO: first T200 project — MIG generate + full synth (often 1–3 hours)"
  }
  create_project jmr_nexys_video $OUT/vivado -part xc7a200tsbg484-1 -force
}

set_param general.maxThreads $SYNTH_THREADS

set_property target_language Verilog [current_project]
jmr_add_sources $ROOT

set_property top top_nexys_video [current_fileset]
set_property verilog_define {SYNTHESIS=1} [current_fileset]
set_property STEPS.WRITE_BITSTREAM.ARGS.BIN_FILE true [get_runs impl_1]
# Default Vivado strategy — Explore took 30m and still missed WNS; fix RTL instead
# AUTO_INCREMENTAL_CHECKPOINT is BANNED (2026-08-21): the 04:11 place-fail
# netlist was an incremental stitch against the pre-exec32-delete reference
# checkpoint — it contained the core's framebuffers TWICE (u_core/u_fb AND
# u_corei_10/u_fb, 658 = 338 VM + 160 FB + 160 stale FB) and ~2x logic.
# Incremental synth after big RTL/file-list changes produces garbage netlists
# that place cannot fix. Full resynthesis every bit until the design is stable.
catch {set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1]}
# 2026-08-22: the design is control-logic-bound (flat 112-state FSM taxes
# every FF with a decode cone; measured ~9-11 LUT/FF). AreaOptimized_high
# targets exactly this. First tried on run 4 of the LUT campaign.
catch {set_property STEPS.SYNTH_DESIGN.ARGS.DIRECTIVE AreaOptimized_high [get_runs synth_1]}
catch {set_property STEPS.OPT_DESIGN.ARGS.DIRECTIVE ExploreArea [get_runs impl_1]}
# 2026-08-23: the UTLZ-1 DRC compares LOGICAL LUT count against sites
# BEFORE LUT6_2 pairing is attempted; control-heavy netlists pack 10-25%.
# Demote to warning and let the placer try (user-approved experiment).
set_param drc.disableLUTOverUtilError 1
catch {set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs impl_1]}
# UG904: write a DCP after each *impl* step (opt/place/route). synth_design
# is one step — first DCP is at synth_1 100%. Cannot resume mid-mapping.
catch {set_param project.writeIntermediateCheckpoints 1}
file mkdir $OUT/checkpoints
proc jmr_ckpt_hook {run step dcp} {
  global OUT
  set hook $OUT/checkpoints/write_[file tail [file rootname $dcp]].tcl
  set fd [open $hook w]
  puts $fd "if {\[catch {write_checkpoint -force $dcp} err\]} {"
  puts $fd "  puts \"WARNING: checkpoint $dcp failed: \$err\""
  puts $fd "}"
  close $fd
  catch {set_property STEPS.${step}.TCL.POST $hook [get_runs $run]}
}
jmr_ckpt_hook synth_1 SYNTH_DESIGN $OUT/post_synth.dcp
jmr_ckpt_hook impl_1 OPT_DESIGN $OUT/post_opt.dcp
jmr_ckpt_hook impl_1 PLACE_DESIGN $OUT/post_place.dcp
jmr_ckpt_hook impl_1 PHYS_OPT_DESIGN $OUT/post_phys_opt.dcp
jmr_ckpt_hook impl_1 ROUTE_DESIGN $OUT/post_route.dcp

# NEW: Nexys Video DDR3 MIG (native UI) — pinout from Digilent mig_a.prj
# Skip create/generate when the IP already exists in a reused project.
if {[llength [get_ips -quiet mig_7series_0]] == 0} {
  create_ip -name mig_7series -vendor xilinx.com -library ip -module_name mig_7series_0
  set mig_ip [get_ips mig_7series_0]
  set mig_dir [get_property IP_DIR $mig_ip]
  file copy -force $ROOT/tools/board_flow/mig_a.prj $mig_dir/mig_a.prj
  set_property -dict [list \
      CONFIG.XML_INPUT_FILE [file normalize $mig_dir/mig_a.prj] \
      CONFIG.RESET_BOARD_INTERFACE {Custom} \
      CONFIG.MIG_DONT_TOUCH_PARAM {Custom} \
  ] $mig_ip
  generate_target {instantiation_template synthesis} $mig_ip
} else {
  puts "INFO: MIG mig_7series_0 already in project — skip generate_target"
}

update_compile_order -fileset sources_1

# Synth 8-6014 etc. stop printing after 100 (Common 17-14). The log then
# looks hung while Vivado is still in opt. BASIC finishes that phase in
# seconds; this VM can sit minutes. Raise the cap and heartbeat STATUS.
set_param messaging.defaultLimit 2000
set_msg_config -id {Synth 8-6014} -limit 2000
set_msg_config -id {Synth 8-4767} -limit 200
set_msg_config -id {Synth 8-3967} -limit 200
set_msg_config -id {Synth 8-7186} -limit 200

# wait_on_run does not tick during synth_design. Side log: RSS + last runme line
# every 10s so a frozen e32_p_clr print still shows the RAM climb.
set rss_log $OUT/synth_rss.log
set runme $OUT/vivado/jmr_nexys_video.runs/synth_1/runme.log
# Keep the previous tracker (16:17 OOM is the tech-map benchmark).
if {[file exists $rss_log]} {
  file copy -force $rss_log ${rss_log}.prev
}
set watch [open $rss_log w]
puts $watch "watch start [clock format [clock seconds]]"
close $watch
exec bash -c "while true; do ts=\$(date '+%H:%M:%S'); rss=\$(ps -C vivado -o rss= --no-headers 2>/dev/null | awk '{if (\$1+0>m) m=\$1+0} END {printf \"%.2f\", m/1024/1024}'); last=\$(tail -n 1 '$runme' 2>/dev/null | tr -d '\\r' | cut -c1-160); echo \"\$ts rss=\${rss}GB \$last\" >> '$rss_log'; sleep 10; done" &

proc jmr_rss_gb {} {
  if {[catch {exec ps -C vivado -o rss= --no-headers} out]} { return "?" }
  set m 0
  foreach r [split $out "\n"] {
    set r [string trim $r]
    if {$r ne "" && [string is integer -strict $r] && $r > $m} { set m $r }
  }
  return [format "%.2f" [expr {$m / 1024.0 / 1024.0}]]
}

proc jmr_wait_run {run} {
  while {1} {
    set st [get_property STATUS [get_runs $run]]
    set pr [get_property PROGRESS [get_runs $run]]
    puts "HEARTBEAT [clock format [clock seconds] -format {%H:%M:%S}] $run STATUS=$st PROGRESS=$pr RSS=[jmr_rss_gb]GB"
    if {$pr eq "100%" ||
        [string match -nocase "*fail*" $st] ||
        [string match -nocase "*error*" $st] ||
        [string match -nocase "*complete*" $st]} {
      wait_on_run $run
      break
    }
    wait_on_run $run -timeout 30
  }
}

# synth_design is one atomic step (UG901). No DCP until 100% — cannot
# resume technology mapping. After a DCP exists and RTL is unchanged,
# skip re-synth so impl crashes do not redo ~8 h. Force: JMR_VIVADO_FORCE_SYNTH=1.
proc jmr_synth_dcp {} {
  global OUT
  set hits [glob -nocomplain $OUT/vivado/jmr_nexys_video.runs/synth_1/*.dcp]
  if {[llength $hits]} { return [lindex $hits 0] }
  if {[file exists $OUT/post_synth.dcp]} { return $OUT/post_synth.dcp }
  return ""
}
proc jmr_rtl_newer_than {dcp} {
  global ROOT
  if {$dcp eq "" || ![file exists $dcp]} { return 1 }
  if {[catch {
    exec find $ROOT/rtl $ROOT/constraints $ROOT/third_party/digilent_rgb2dvi/src \
      $ROOT/tools/board_flow/mig_a.prj \
      ( -name {*.sv} -o -name {*.vhd} -o -name {*.xdc} -o -name mig_a.prj ) \
      -type f -newer $dcp
  } out]} { return 1 }
  return [expr {[string trim $out] ne ""}]
}

set force_synth 0
if {[info exists ::env(JMR_VIVADO_FORCE_SYNTH)] && $::env(JMR_VIVADO_FORCE_SYNTH) ne ""} {
  set force_synth 1
}
set dcp [jmr_synth_dcp]
set synth_pr ""
set synth_st ""
catch {set synth_pr [get_property PROGRESS [get_runs synth_1]]}
catch {set synth_st [get_property STATUS [get_runs synth_1]]}
set skip_synth [expr {
  !$FRESH && !$force_synth && $dcp ne "" && $synth_pr eq "100%" &&
  ![string match -nocase "*fail*" $synth_st] && ![jmr_rtl_newer_than $dcp]
}]
if {$skip_synth} {
  puts "INFO: synth_1 already 100% ($dcp) — skip re-synth (RTL unchanged)"
} else {
  # Killed synth leaves PROGRESS 0% but still "needs reset" (Common 17-69).
  catch {reset_run synth_1}
  set_param general.maxThreads $SYNTH_THREADS
# 2026-08-22: a killed/aborted previous run leaves synth_1 unlaunchable
# ("needs to be reset before launching"). Reset is always safe here: with
# AUTO_INCREMENTAL off every bit is a full resynthesis anyway.
catch {reset_run synth_1}
  if {[llength $JMR_DEFINES] > 0} {
    puts "INFO: verilog_define $JMR_DEFINES"
    set_property verilog_define $JMR_DEFINES [current_fileset]
  }
  launch_runs synth_1 -jobs $SYNTH_JOBS
  jmr_wait_run synth_1
}

set st [get_property STATUS [get_runs synth_1]]
if {[get_property PROGRESS [get_runs synth_1]] != "100%" ||
    [string match -nocase "*fail*" $st] ||
    [string match -nocase "*error*" $st]} {
  puts "ERROR: synthesis failed (STATUS=$st)"
  puts "ERROR: no mid-map DCP — re-run make bit (not bit-fresh). Mapping cannot resume."
  exit 1
}

open_run synth_1
report_utilization -file $OUT/utilization_synth.rpt
if {![file exists $OUT/post_synth.dcp]} {
  catch {write_checkpoint -force $OUT/post_synth.dcp}
}

catch {reset_run impl_1}

# Place/route: restore 8 threads. Mapping OOM was synth_design, not impl.
set_param general.maxThreads $IMPL_THREADS
puts "INFO: impl maxThreads=$IMPL_THREADS jobs=$IMPL_JOBS"
if {$JMR_STRATEGY ne ""} {
  puts "INFO: impl strategy $JMR_STRATEGY"
  set_property strategy $JMR_STRATEGY [get_runs impl_1]
  # setting a strategy RESETS the run's step options — re-apply BIN_FILE
  # or the flow silently ships no .bin (run 46: stale Aug-13 .bin trap)
  set_property STEPS.WRITE_BITSTREAM.ARGS.BIN_FILE true [get_runs impl_1]
}
launch_runs impl_1 -to_step write_bitstream -jobs $IMPL_JOBS
# catch: a failed route ERRORs out of wait_on_runs and would kill the
# script before the checkpoint-recovery branch below ever ran (run 45).
catch { jmr_wait_run impl_1 }
set st [get_property STATUS [get_runs impl_1]]
set RECOVERED 0
if {[get_property PROGRESS [get_runs impl_1]] != "100%" ||
    [string match -nocase "*fail*" $st] ||
    [string match -nocase "*error*" $st]} {
  # 2026-08-26 checkpoint recovery (run-41 lesson: a route SIGKILLed by
  # something outside Vivado discarded 3h of converged routing while the
  # step checkpoints sat on disk). Resume from the newest checkpoint
  # instead of failing the whole run; only a run with no checkpoints at
  # all is a true failure.
  set idir [get_property DIRECTORY [get_runs impl_1]]
  set CKPT ""
  foreach cand {top_nexys_video_routed.dcp top_nexys_video_physopt.dcp top_nexys_video_placed.dcp top_nexys_video_opt.dcp} {
    if {[file exists "$idir/$cand"]} { set CKPT "$idir/$cand"; break }
  }
  if {$CKPT eq ""} {
    puts "ERROR: implementation failed (STATUS=$st) and no checkpoint to resume from"
    exit 1
  }
  puts "RECOVER: implementation failed (STATUS=$st) — resuming from $CKPT"
  open_checkpoint $CKPT
  if {![string match "*routed*" $CKPT]} {
    if {[string match "*_opt.dcp" $CKPT]} { place_design; phys_opt_design }
    route_design
  }
  set RECOVERED 1
}

if {!$RECOVERED} { open_run impl_1 }
report_utilization -file $OUT/utilization_impl.rpt
# run-51 observability (2026-08-27): record congestion + timing
# DISTRIBUTIONS every run. Every failed-run postmortem so far starved on
# -max_paths 1 headlines (the project had exactly ONE saved intra-VM
# path until a checkpoint was re-mined) and congestion was never
# recorded per run, so strategy regressions were invisible until a
# route died. Cheap (seconds), archived with the run.
catch {report_design_analysis -congestion -file $OUT/congestion_impl.rpt}
catch {report_timing -from [get_clocks vm_clk] -to [get_clocks vm_clk] -max_paths 100 -unique_pins -file $OUT/timing_vmclk_dist.rpt}
catch {report_timing -max_paths 100 -unique_pins -file $OUT/timing_dist.rpt}

# NEW: never ship a failing-timing bit (prior build wrote .bit with WNS −0.5 ns)
set wns [lindex [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]] 0]
set whs [lindex [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -hold]] 0]
puts "TIMING WNS=$wns WHS=$whs"
if {$wns eq "" || $wns < 0} {
  puts "ERROR: timing not met (WNS=$wns) — refusing to publish .bit"
  # never-smash: the refused bit is still preserved, clearly labeled
  set _stamp [clock format [clock seconds] -format %Y%m%d_%H%M%S]
  file mkdir "$ROOT/build/bits/auto"
  foreach _f {top_nexys_video.bit top_nexys_video.bin} {
    set _src "$OUT/vivado/jmr_nexys_video.runs/impl_1/$_f"
    if {[file exists $_src]} {
      file copy -force $_src "$ROOT/build/bits/auto/${_stamp}_WNSFAIL${wns}_$_f"
    }
  }
  puts "INFO: never-smash: refused bit preserved in build/bits/auto/ (WNSFAIL label)"
  exit 1
}
if {$whs eq "" || $whs < 0} {
  puts "ERROR: hold not met (WHS=$whs) — refusing to publish .bit"
  exit 1
}

if {$RECOVERED} {
  write_bitstream -force [get_property DIRECTORY [get_runs impl_1]]/top_nexys_video.bit
}
file copy -force \
  [get_property DIRECTORY [get_runs impl_1]]/top_nexys_video.bit \
  $OUT/jmr_nexys_video.bit
if {[file exists [get_property DIRECTORY [get_runs impl_1]]/top_nexys_video.bin]} {
  file copy -force \
    [get_property DIRECTORY [get_runs impl_1]]/top_nexys_video.bin \
    $OUT/jmr_nexys_video.bin
}

puts "OK wrote $OUT/jmr_nexys_video.bit (WNS=$wns)"
exit 0
