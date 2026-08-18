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

if {[llength [get_parts -quiet xc7a200tsbg484-1]] == 0} {
  puts "ERROR: xc7a200tsbg484-1 not installed — enable Artix-7 in xsetup"
  exit 1
}

set JOBS 2
if {[info exists ::env(JMR_VIVADO_JOBS)] && $::env(JMR_VIVADO_JOBS) ne ""} {
  set JOBS $::env(JMR_VIVADO_JOBS)
}

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
      $ROOT/rtl/engines/jmr_rectdemo_engine.sv \
      $ROOT/rtl/engines/jmr_value.sv \
      $ROOT/rtl/engines/jmr_js_vm_pkg.sv \
      $ROOT/rtl/engines/jmr_js_vm_exec32.sv \
      $ROOT/rtl/engines/jmr_js_vm_exec64.sv \
      $ROOT/rtl/engines/jmr_js_vm.sv \
      $ROOT/rtl/engines/font_rom.hex \
      $ROOT/rtl/engines/invaders_jsb.hex \
      $ROOT/rtl/engines/jmr_palette_bram.sv \
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
  if {[llength [get_files -quiet -of_objects [get_filesets constrs_1] \
      $ROOT/constraints/nexys_video.xdc]] == 0} {
    add_files -fileset constrs_1 $ROOT/constraints/nexys_video.xdc
  }
}

if {$REUSE} {
  puts "INFO: reusing $XPR (incremental). make bit-fresh if MIG/XDC/file list changed."
  open_project $XPR
} else {
  if {$FRESH} {
    puts "INFO: bit-fresh — create_project -force (MIG regenerated)"
  } else {
    puts "INFO: first T200 project — MIG generate + full synth (often 1–3 hours)"
  }
  create_project jmr_nexys_video $OUT/vivado -part xc7a200tsbg484-1 -force
}

set_property target_language Verilog [current_project]
jmr_add_sources $ROOT

set_property top top_nexys_video [current_fileset]
set_property verilog_define {SYNTHESIS=1} [current_fileset]
set_property STEPS.WRITE_BITSTREAM.ARGS.BIN_FILE true [get_runs impl_1]
# Default Vivado strategy — Explore took 30m and still missed WNS; fix RTL instead
# Later bits: reuse synth/impl DCPs when RTL change is small
catch {set_property AUTO_INCREMENTAL_CHECKPOINT 1 [get_runs synth_1]}
catch {set_property AUTO_INCREMENTAL_CHECKPOINT 1 [get_runs impl_1]}

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

# Always reset: a killed synth leaves PROGRESS 0% but still "needs reset"
# (Common 17-69). catch: no-op if the run was never launched.
catch {reset_run synth_1}

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

launch_runs synth_1 -jobs $JOBS
jmr_wait_run synth_1
set st [get_property STATUS [get_runs synth_1]]
if {[get_property PROGRESS [get_runs synth_1]] != "100%" ||
    [string match -nocase "*fail*" $st] ||
    [string match -nocase "*error*" $st]} {
  puts "ERROR: synthesis failed (STATUS=$st)"
  exit 1
}

open_run synth_1
report_utilization -file $OUT/utilization_synth.rpt

catch {reset_run impl_1}

launch_runs impl_1 -to_step write_bitstream -jobs $JOBS
jmr_wait_run impl_1
set st [get_property STATUS [get_runs impl_1]]
if {[get_property PROGRESS [get_runs impl_1]] != "100%" ||
    [string match -nocase "*fail*" $st] ||
    [string match -nocase "*error*" $st]} {
  puts "ERROR: implementation failed (STATUS=$st)"
  exit 1
}

open_run impl_1
report_utilization -file $OUT/utilization_impl.rpt

# NEW: never ship a failing-timing bit (prior build wrote .bit with WNS −0.5 ns)
set wns [lindex [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]] 0]
puts "TIMING WNS=$wns"
if {$wns eq "" || $wns < 0} {
  puts "ERROR: timing not met (WNS=$wns) — refusing to publish .bit"
  exit 1
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
