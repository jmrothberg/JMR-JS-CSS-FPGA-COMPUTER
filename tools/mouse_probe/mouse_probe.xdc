# HDMI mouse probe only. Do not reuse the JS XDC (DDR3, SD, audio, tether).
# Pins from the Digilent Nexys Video master, same HDMI and J15 mouse pins
# as constraints/nexys_video.xdc.

set_property -dict { PACKAGE_PIN R4 IOSTANDARD LVCMOS33 } [get_ports { clk100 }]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk100 }]
# R4 and this design's pixel MMCM are not in the same clock region.
# Same waiver the JS bit uses. hid_led_blink must NOT copy this: with no
# MMCM on clk100, BACKBONE fails write_bitstream (DRC RTRES-1).
set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets clk100_IBUF]

set_property -dict { PACKAGE_PIN G4 IOSTANDARD LVCMOS15 } [get_ports { cpu_resetn }]
set_property -dict { PACKAGE_PIN B22 IOSTANDARD LVCMOS12 } [get_ports { btnc }]

set_property -dict { PACKAGE_PIN T14 IOSTANDARD LVCMOS25 } [get_ports { led[0] }]
set_property -dict { PACKAGE_PIN T15 IOSTANDARD LVCMOS25 } [get_ports { led[1] }]
set_property -dict { PACKAGE_PIN T16 IOSTANDARD LVCMOS25 } [get_ports { led[2] }]
set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS25 } [get_ports { led[3] }]
set_property -dict { PACKAGE_PIN V15 IOSTANDARD LVCMOS25 } [get_ports { led[4] }]
set_property -dict { PACKAGE_PIN W16 IOSTANDARD LVCMOS25 } [get_ports { led[5] }]
set_property -dict { PACKAGE_PIN W15 IOSTANDARD LVCMOS25 } [get_ports { led[6] }]
set_property -dict { PACKAGE_PIN Y13 IOSTANDARD LVCMOS25 } [get_ports { led[7] }]

set_property -dict { PACKAGE_PIN U1  IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_clk_n }]
set_property -dict { PACKAGE_PIN T1  IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_clk_p }]
set_property -dict { PACKAGE_PIN Y1  IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_n[0] }]
set_property -dict { PACKAGE_PIN W1  IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_p[0] }]
set_property -dict { PACKAGE_PIN AB1 IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_n[1] }]
set_property -dict { PACKAGE_PIN AA1 IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_p[1] }]
set_property -dict { PACKAGE_PIN AB2 IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_n[2] }]
set_property -dict { PACKAGE_PIN AB3 IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_p[2] }]
set_property -dict { PACKAGE_PIN AA4  IOSTANDARD LVCMOS33 } [get_ports { hdmi_tx_cec }]
set_property -dict { PACKAGE_PIN U3   IOSTANDARD LVCMOS33 } [get_ports { hdmi_tx_rscl }]
set_property -dict { PACKAGE_PIN V3   IOSTANDARD LVCMOS33 } [get_ports { hdmi_tx_rsda }]

set_property -dict { PACKAGE_PIN W17 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { ps2_clk }]
set_property -dict { PACKAGE_PIN N13 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { ps2_data }]
set_property PULLTYPE PULLUP [get_ports { ps2_clk }]
set_property PULLTYPE PULLUP [get_ports { ps2_data }]

# Pmod JA top row — all 4 signal pins (JA1=AB22, JA2=AB21, JA3=AB20, JA4=AB18) with pull-ups
set_property -dict { PACKAGE_PIN AB22 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { pmod_ja1 }]
set_property -dict { PACKAGE_PIN AB21 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { pmod_ja2 }]
set_property -dict { PACKAGE_PIN AB20 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { pmod_ja3 }]
set_property -dict { PACKAGE_PIN AB18 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { pmod_ja4 }]
set_property PULLTYPE PULLUP [get_ports { pmod_ja1 }]
set_property PULLTYPE PULLUP [get_ports { pmod_ja2 }]
set_property PULLTYPE PULLUP [get_ports { pmod_ja3 }]
set_property PULLTYPE PULLUP [get_ports { pmod_ja4 }]

# Pmod JC top row — all 4 signal pins (JC1=Y6, JC2=AA6, JC3=AA8, JC4=AB8) with pull-ups
set_property -dict { PACKAGE_PIN Y6  IOSTANDARD LVCMOS33 PULLUP true } [get_ports { pmod_jc1 }]
set_property -dict { PACKAGE_PIN AA6 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { pmod_jc2 }]
set_property -dict { PACKAGE_PIN AA8 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { pmod_jc3 }]
set_property -dict { PACKAGE_PIN AB8 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { pmod_jc4 }]
set_property PULLTYPE PULLUP [get_ports { pmod_jc1 }]
set_property PULLTYPE PULLUP [get_ports { pmod_jc2 }]
set_property PULLTYPE PULLUP [get_ports { pmod_jc3 }]
set_property PULLTYPE PULLUP [get_ports { pmod_jc4 }]

# Pmod JB top row — all 4 signal pins (JB1=V9, JB2=V8, JB3=V7, JB4=W7) with pull-ups
set_property -dict { PACKAGE_PIN V9 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { pmod_jb1 }]
set_property -dict { PACKAGE_PIN V8 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { pmod_jb2 }]
set_property -dict { PACKAGE_PIN V7 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { pmod_jb3 }]
set_property -dict { PACKAGE_PIN W7 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { pmod_jb4 }]
set_property PULLTYPE PULLUP [get_ports { pmod_jb1 }]
set_property PULLTYPE PULLUP [get_ports { pmod_jb2 }]
set_property PULLTYPE PULLUP [get_ports { pmod_jb3 }]
set_property PULLTYPE PULLUP [get_ports { pmod_jb4 }]

# Same HDMI bank placement the JS bit uses. This design is small, but the
# rgb2dvi MMCM still has to sit next to the TMDS pins.
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets u_tmds/u_rgb2dvi/ClockGenInternal.ClockGenX/PixelClkInX5]
set_property LOC MMCME2_ADV_X1Y2 [get_cells {u_tmds/u_rgb2dvi/ClockGenInternal.ClockGenX/GenMMCM.DVI_ClkGenerator}]
