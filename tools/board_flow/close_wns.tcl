# Close tiny WNS miss on already-routed tether-KEYBITS design
set DCP /home/jonathan/JMR-JS-CSS-FPGA-COMPUTER/build/nexys_video/vivado/jmr_nexys_video.runs/impl_1/top_nexys_video_routed.dcp
set OUT /home/jonathan/JMR-JS-CSS-FPGA-COMPUTER/build/nexys_video
open_checkpoint $DCP
phys_opt_design -directive AggressiveExplore
route_design -directive Explore
set wns [lindex [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]] 0]
puts "TIMING WNS=$wns"
if {$wns eq "" || $wns < 0} {
  puts "ERROR: still failing WNS=$wns"
  exit 1
}
write_bitstream -force $OUT/jmr_nexys_video.bit -bin_file
puts "OK wrote $OUT/jmr_nexys_video.bit (WNS=$wns)"
exit 0
