set root [file normalize [lindex $argv 0]]
set model [file normalize [lindex $argv 1]]
set top [lindex $argv 2]
if {$top eq ""} {set top tb_hyperram}
set out $root/build/a200t_d2a1/$top
create_project -force a200t_vendor_sim $out -part xc7a200tfbg484-1
add_files -fileset sim_1 [list $root/boards/a200t_d2a1/rtl/jmr_hyperram_phy.sv $root/boards/a200t_d2a1/rtl/jmr_hyperram_bus.sv $root/boards/a200t_d2a1/rtl/jmr_hyperram_sram.sv $root/rtl/engines/jmr_ddr3_sram_bridge.sv $model $root/boards/a200t_d2a1/tests/$top.sv]
set_property top $top [get_filesets sim_1]
set_property xsim.simulate.runtime 1ms [get_filesets sim_1]
launch_simulation
close_sim
close_project
