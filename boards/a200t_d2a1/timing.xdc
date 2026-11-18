# The actual VM waveform is one complete 100 MHz pulse every three cycles.
create_generated_clock -name ram_forward -source [get_pins memory/bus/phy/ckP/C] -divide_by 1 [get_ports HR_CK_P_SRC]
create_clock -name ram_rwds -period 20.000 [get_ports HR_RWDS]
# Virtual launch is -5 ns, +5 ns delay: DQ transition window remains
# +/-0.8 ns around physical RWDS. Delayed RWDS captures THIS data edge.
create_clock -name ram_data -period 20.000 -waveform {-5.000 5.000}
set_input_delay -clock ram_data -max 5.800 [get_ports {HR_DQ[*]}]
set_input_delay -clock ram_data -min 4.200 [get_ports {HR_DQ[*]}]
set_input_delay -clock ram_data -clock_fall -add_delay -max 5.800 [get_ports {HR_DQ[*]}]
set_input_delay -clock ram_data -clock_fall -add_delay -min 4.200 [get_ports {HR_DQ[*]}]
set_clock_uncertainty -setup 0.200 [get_clocks ram_rwds]
set_clock_uncertainty -hold 0.200 [get_clocks ram_rwds]
set_output_delay -clock ram_forward -max 1.200 [get_ports {HR_DQ[*] HR_RWDS}]
set_output_delay -clock ram_forward -min -1.200 [get_ports {HR_DQ[*] HR_RWDS}]
set_output_delay -clock ram_forward -clock_fall -add_delay -max 1.200 [get_ports {HR_DQ[*] HR_RWDS}]
set_output_delay -clock ram_forward -clock_fall -add_delay -min -1.200 [get_ports {HR_DQ[*] HR_RWDS}]
set_clock_uncertainty -setup 0.400 [get_clocks ram_forward]
set_clock_uncertainty -hold 0.400 [get_clocks ram_forward]
set_output_delay -clock ram_forward -max 3.000 [get_ports HR_CS_N]
set_output_delay -clock ram_forward -min -1.000 [get_ports HR_CS_N]
# Completed burst mailbox: CK stops, STOP+RECOVER allow >100 ns before
# capture. Bound physical settling to one 50 MHz cycle, not a blanket cut.
set rx_regs [get_cells -hier -regexp {memory/bus/phy/((received|count)_reg.*|g_rx\[[0-7]\].capture)}]
set result_regs [get_cells -hier -regexp {memory/bus/result_reg.*}]
set_max_delay -datapath_only 20.000 -from $rx_regs -to $result_regs
set_false_path -hold -from $rx_regs -to $result_regs
# Only the first stage of each asynchronous status/toggle synchronizer.
set sync_first [get_pins -hier -regexp {.*(command_sync|delay_sync|count_ready|ready_sync|fault_sync|done_sync)_reg\[0\]/D}]
set_false_path -to $sync_first
set rx_clear [get_pins -hier -regexp {memory/bus/phy/(received|count)_reg.*/CLR}]
set_false_path -to $rx_clear
# UART is asynchronous; SD/I2C use existing synchronizing receivers.
set_false_path -from [get_ports UART_RX] -to [get_pins -hier -regexp {input_devices/reports/sync_reg\[0\]/D}]
set_false_path -from [get_ports SD_MISO] -to [get_pins -hier -regexp {.*/miso_sync_reg\[0\]/D}]
set_false_path -from [get_ports I2C_SDA] -to [get_pins -hier -regexp {u_i2c_joy/u_i2c/sda_i_reg/D}]
set_false_path -from [get_ports I2C_SCL] -to [get_pins -hier -regexp {u_i2c_joy/u_i2c/scl_i_reg/D}]
set_false_path -from [get_ports RESET_N]
set_false_path -to [get_ports {STAT* GPIO_OUT* AUD_PWM AUD_SD UART_TX HR_RESET_N}]
set pix [get_clocks -of_objects [get_pins bp/O]]
set fast [get_clocks -of_objects [get_pins bc/O]]
set_output_delay -clock $pix -max 5 [get_ports {VGA_* VIDEO_DE}]
set_output_delay -clock $pix -min 0 [get_ports {VGA_* VIDEO_DE}]
# SPI is 12.5 MHz maximum: data launches on falling SCK, sampled on the
# following rising SCK, 40 ns later. Bound each clock-to-pad data path to
# 10 ns, preserving at least 30 ns relative settling margin. Initialization
# is slower. I2C changes data in its 2.5-us low quarter before clock-high.
# These ports are not sampled at the next 100-MHz fabric edge.
# Only data flip-flops: IS_SEQUENTIAL also includes MMCM/BUFG primitives,
# which must remain clock propagation objects rather than data starts.
set_max_delay -datapath_only 10.000 -from [get_cells -hier -filter {REF_NAME =~ FD*}] -to [get_ports {SD_SCK SD_MOSI SD_CS_N I2C_SCL I2C_SDA}]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
