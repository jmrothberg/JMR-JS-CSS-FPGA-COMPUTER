# Nexys Video (XC7A200T) — Digilent master pins for standalone console.
# Source: Digilent digilent-xdc Nexys-Video-Master.xdc

## System clock 100 MHz
set_property -dict { PACKAGE_PIN R4 IOSTANDARD LVCMOS33 } [get_ports { clk100 }]
## 2026-08-23 relax experiment result: create_clock NEVER applies at
## synthesis here (XDC deferred past the MIG black box — Project 1-498),
## so a 20 ns relax produced a BIT-IDENTICAL netlist (run 18 == run 17).
## The area gain the relax was meant to buy was already banked by
## AreaOptimized_high + the deferral. The period must stay TRUTHFUL:
## the physical clock is 100 MHz, and 20 ns would under-constrain the
## MMCM-derived pixel/HDMI paths at implementation. Half-rate core =
## BUFGCE /2 with a real generated clock, when needed.
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk100 }]
set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets clk100_IBUF]

## CPU reset (active low)
set_property -dict { PACKAGE_PIN G4 IOSTANDARD LVCMOS15 } [get_ports { cpu_resetn }]

## NEW: BTNC (center button) = user reset, like the T100/BASIC board
set_property -dict { PACKAGE_PIN B22 IOSTANDARD LVCMOS12 } [get_ports { btnc }]

## NEW: DPTI / FT245 FIFO on PROG jack J12 (FT2232 channel B) — GUI tether
## Same USB cable as JTAG, matching the T100. Not the J13 UART jack.
set_property -dict { PACKAGE_PIN U20 IOSTANDARD LVCMOS33 } [get_ports { prog_d[0] }]
set_property -dict { PACKAGE_PIN P14 IOSTANDARD LVCMOS33 } [get_ports { prog_d[1] }]
set_property -dict { PACKAGE_PIN P15 IOSTANDARD LVCMOS33 } [get_ports { prog_d[2] }]
set_property -dict { PACKAGE_PIN U17 IOSTANDARD LVCMOS33 } [get_ports { prog_d[3] }]
set_property -dict { PACKAGE_PIN R17 IOSTANDARD LVCMOS33 } [get_ports { prog_d[4] }]
set_property -dict { PACKAGE_PIN P16 IOSTANDARD LVCMOS33 } [get_ports { prog_d[5] }]
set_property -dict { PACKAGE_PIN R18 IOSTANDARD LVCMOS33 } [get_ports { prog_d[6] }]
set_property -dict { PACKAGE_PIN N14 IOSTANDARD LVCMOS33 } [get_ports { prog_d[7] }]
set_property -dict { PACKAGE_PIN N17 IOSTANDARD LVCMOS33 } [get_ports { prog_rxen }]
set_property -dict { PACKAGE_PIN Y19 IOSTANDARD LVCMOS33 } [get_ports { prog_txen }]
set_property -dict { PACKAGE_PIN P19 IOSTANDARD LVCMOS33 } [get_ports { prog_rdn }]
set_property -dict { PACKAGE_PIN R19 IOSTANDARD LVCMOS33 } [get_ports { prog_wrn }]
set_property -dict { PACKAGE_PIN V17 IOSTANDARD LVCMOS33 } [get_ports { prog_oen }]
set_property -dict { PACKAGE_PIN P17 IOSTANDARD LVCMOS33 } [get_ports { prog_siwun }]

## LEDs
set_property -dict { PACKAGE_PIN T14 IOSTANDARD LVCMOS25 } [get_ports { led[0] }]
set_property -dict { PACKAGE_PIN T15 IOSTANDARD LVCMOS25 } [get_ports { led[1] }]
set_property -dict { PACKAGE_PIN T16 IOSTANDARD LVCMOS25 } [get_ports { led[2] }]
set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS25 } [get_ports { led[3] }]
set_property -dict { PACKAGE_PIN V15 IOSTANDARD LVCMOS25 } [get_ports { led[4] }]
set_property -dict { PACKAGE_PIN W16 IOSTANDARD LVCMOS25 } [get_ports { led[5] }]
set_property -dict { PACKAGE_PIN W15 IOSTANDARD LVCMOS25 } [get_ports { led[6] }]
set_property -dict { PACKAGE_PIN Y13 IOSTANDARD LVCMOS25 } [get_ports { led[7] }]

## HDMI Source (J8)
set_property -dict { PACKAGE_PIN U1  IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_clk_n }]
set_property -dict { PACKAGE_PIN T1  IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_clk_p }]
set_property -dict { PACKAGE_PIN Y1  IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_n[0] }]
set_property -dict { PACKAGE_PIN W1  IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_p[0] }]
set_property -dict { PACKAGE_PIN AB1 IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_n[1] }]
set_property -dict { PACKAGE_PIN AA1 IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_p[1] }]
set_property -dict { PACKAGE_PIN AB2 IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_n[2] }]
set_property -dict { PACKAGE_PIN AB3 IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_p[2] }]
set_property -dict { PACKAGE_PIN AA4  IOSTANDARD LVCMOS33 } [get_ports { hdmi_tx_cec }]
set_property -dict { PACKAGE_PIN AB13 IOSTANDARD LVCMOS25 } [get_ports { hdmi_tx_hpd }]
set_property -dict { PACKAGE_PIN U3   IOSTANDARD LVCMOS33 } [get_ports { hdmi_tx_rscl }]
set_property -dict { PACKAGE_PIN V3   IOSTANDARD LVCMOS33 } [get_ports { hdmi_tx_rsda }]

## USB HID PS/2 from PIC24 (J15). Classic boot-protocol keyboard.
## PULLTYPE: Vivado 2026.1; same as tools/pmod_input_test (proven PASS).
set_property -dict { PACKAGE_PIN W17 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { ps2_clk }]
set_property -dict { PACKAGE_PIN N13 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { ps2_data }]
set_property PULLTYPE PULLUP [get_ports { ps2_clk }]
set_property PULLTYPE PULLUP [get_ports { ps2_data }]

## Pmod JA top row — Pmod PS/2 (pin1=Data pin3=Clock). Same as pmod_input_test.
set_property -dict { PACKAGE_PIN AB22 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { pmod_ps2_data }]
set_property -dict { PACKAGE_PIN AB20 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { pmod_ps2_clk }]

## Pmod JB — Mini I2C joystick 0x5A (SCL=JB1 SDA=JB2). Same as pmod_input_test.
set_property -dict { PACKAGE_PIN V9 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { joy_scl }]
set_property -dict { PACKAGE_PIN V8 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { joy_sda }]

## µSD slot
## µSD — SPI: SCK=cclk MOSI=cmd MISO=d[0] CS=d[3] (LiteX/Digilent)
## NEW: PULLUP on MISO/CMD/CS — card tri-states DAT0 between transfers
set_property -dict { PACKAGE_PIN V20 IOSTANDARD LVCMOS33 } [get_ports { sd_reset }]
set_property -dict { PACKAGE_PIN W19 IOSTANDARD LVCMOS33 } [get_ports { sd_cclk }]
set_property -dict { PACKAGE_PIN T18 IOSTANDARD LVCMOS33 } [get_ports { sd_cd }]
set_property -dict { PACKAGE_PIN W20 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { sd_cmd }]
set_property -dict { PACKAGE_PIN V19 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { sd_d[0] }]
set_property -dict { PACKAGE_PIN T21 IOSTANDARD LVCMOS33 } [get_ports { sd_d[1] }]
set_property -dict { PACKAGE_PIN T20 IOSTANDARD LVCMOS33 } [get_ports { sd_d[2] }]
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { sd_d[3] }]

## 2026-08-23: at extreme LUT utilization the IO clock placer cannot
## co-locate rgb2dvi's internal MMCM with its BUFR/BUFIO pair. Fabric
## routing for the x5 serial clock is acceptable at 125 MHz for bring-up
## (override text supplied verbatim by Place 30-149).
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets u_tmds/u_rgb2dvi/ClockGenInternal.ClockGenX/PixelClkInX5]

## 2026-08-24 (Place 30-512 at ~105% packed utilization): the clock
## placer put rgb2dvi's MMCM in X1Y1 while its BUFIO/BUFR loads must sit
## in the HDMI bank's region. Pin the MMCM beside its loads.
set_property LOC MMCME2_ADV_X1Y2 [get_cells {u_tmds/u_rgb2dvi/ClockGenInternal.ClockGenX/GenMMCM.DVI_ClkGenerator}]
