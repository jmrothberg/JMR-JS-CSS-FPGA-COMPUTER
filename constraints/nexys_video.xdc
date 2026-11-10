# Nexys Video (XC7A200T) — Digilent master pins for standalone console.
# Source: Digilent digilent-xdc Nexys-Video-Master.xdc

## System clock 100 MHz
set_property -dict { PACKAGE_PIN R4 IOSTANDARD LVCMOS33 } [get_ports { clk100 }]
## Relax experiment result: create_clock NEVER applies at
## synthesis here (XDC deferred past the MIG black box — Project 1-498),
## so a 20 ns relax produced a BIT-IDENTICAL netlist.
## The area gain the relax was meant to buy was already banked by
## AreaOptimized_high + the deferral. The period must stay TRUTHFUL:
## the physical clock is 100 MHz, and 20 ns would under-constrain the
## MMCM-derived pixel/HDMI paths at implementation. Half-rate core =
## BUFGCE /2 with a real generated clock, when needed.
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk100 }]
set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets clk100_IBUF]

## CPU reset (active low)
set_property -dict { PACKAGE_PIN G4 IOSTANDARD LVCMOS15 } [get_ports { cpu_resetn }]

## BTNC (center button) = user reset, like the T100/BASIC board
set_property -dict { PACKAGE_PIN B22 IOSTANDARD LVCMOS12 } [get_ports { btnc }]

## DPTI / FT245 FIFO on PROG jack J12 (FT2232 channel B) — GUI tether
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

## Pmod JC backup PS/2 mouse: JC1=data, JC3=clock, open drain.
set_property -dict { PACKAGE_PIN Y6 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { pmod_jc_ps2_data }]
set_property -dict { PACKAGE_PIN AA8 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { pmod_jc_ps2_clk }]

## Pmod JB — Mini I2C joystick 0x5A (SCL=JB1 SDA=JB2). Same as pmod_input_test.
set_property -dict { PACKAGE_PIN V9 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { joy_scl }]
set_property -dict { PACKAGE_PIN V8 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { joy_sda }]

## ADAU1761 audio codec (J5 line-out) — pins per Digilent master XDC; same
## set proven by tools/audio_beep_test. I2C has board pull-ups: open-drain only.
set_property -dict { PACKAGE_PIN U6 IOSTANDARD LVCMOS33 } [get_ports { ac_mclk }]
set_property -dict { PACKAGE_PIN T5 IOSTANDARD LVCMOS33 } [get_ports { ac_bclk }]
set_property -dict { PACKAGE_PIN U5 IOSTANDARD LVCMOS33 } [get_ports { ac_lrclk }]
set_property -dict { PACKAGE_PIN W6 IOSTANDARD LVCMOS33 } [get_ports { ac_dac_sdata }]
set_property -dict { PACKAGE_PIN W5 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { ac_scl }]
set_property -dict { PACKAGE_PIN V5 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { ac_sda }]

## Audio CDC: synchronized request/acknowledgement, source-held payload.
## Cut only first synchronizer stages. The payload is NOT false-pathed:
## capture occurs >=2 MCLK periods after request launch; bound its complete
## data/decode path to1 MCLK period (83.333ns), leaving one settling period.
set_false_path -to [get_pins -hierarchical -regexp {.*acfg_sync_reg\[0\]/D}] -quiet
set_false_path -to [get_pins -hierarchical -regexp {.*mute_sync_reg\[0\]/D}] -quiet
set_false_path -to [get_pins -hierarchical -regexp {.*u_psg/tgl_sync_reg\[0\]/D}] -quiet
set_false_path -to [get_pins -hierarchical -regexp {.*u_exec64/snd_ack_sync_reg\[0\]/D}] -quiet
set audio_payload_regs [get_cells -hierarchical -regexp {.*u_exec64/snd_(ch|freq|vol|frames|slide)_reg(\[[0-9]+\])?}]
# snd_ch also inhibits ph23_q history on the same synchronized poke.
# This is another held-payload capture endpoint, not a free-running CDC.
set audio_capture_regs [get_cells -hierarchical -regexp {.*u_psg/(v(freq|vol|frames|slide|phase)|ph23_q)_reg.*}]
set audio_capture_pins [get_pins -of_objects $audio_capture_regs -filter {REF_PIN_NAME == D || REF_PIN_NAME == CE || REF_PIN_NAME == R || REF_PIN_NAME == S}]
set_max_delay -datapath_only 83.333 -from $audio_payload_regs -to $audio_capture_pins

## µSD slot
## µSD — SPI: SCK=cclk MOSI=cmd MISO=d[0] CS=d[3] (LiteX/Digilent)
## PULLUP on MISO/CMD/CS — card tri-states DAT0 between transfers
set_property -dict { PACKAGE_PIN V20 IOSTANDARD LVCMOS33 } [get_ports { sd_reset }]
set_property -dict { PACKAGE_PIN W19 IOSTANDARD LVCMOS33 } [get_ports { sd_cclk }]
set_property -dict { PACKAGE_PIN T18 IOSTANDARD LVCMOS33 } [get_ports { sd_cd }]
set_property -dict { PACKAGE_PIN W20 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { sd_cmd }]
set_property -dict { PACKAGE_PIN V19 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { sd_d[0] }]
set_property -dict { PACKAGE_PIN T21 IOSTANDARD LVCMOS33 } [get_ports { sd_d[1] }]
set_property -dict { PACKAGE_PIN T20 IOSTANDARD LVCMOS33 } [get_ports { sd_d[2] }]
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { sd_d[3] }]

## At extreme LUT utilization the IO clock placer cannot
## co-locate rgb2dvi's internal MMCM with its BUFR/BUFIO pair. Fabric
## routing for the x5 serial clock is acceptable at 125 MHz for bring-up
## (override text supplied verbatim by Place 30-149).
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets u_tmds/u_rgb2dvi/ClockGenInternal.ClockGenX/PixelClkInX5]

## The clock
## placer put rgb2dvi's MMCM in X1Y1 while its BUFIO/BUFR loads must sit
## in the HDMI bank's region. Pin the MMCM beside its loads.
set_property LOC MMCME2_ADV_X1Y2 [get_cells {u_tmds/u_rgb2dvi/ClockGenInternal.ClockGenX/GenMMCM.DVI_ClkGenerator}]

# VM_CLK_DIV=3: BUFGCE passes one complete 100 MHz pulse per three cycles.
# Its waveform is {0,5} ns with a 30 ns period, rather than 50% duty cycle.
# Edges {1,2,7} refer to the source clock's rising/falling/rising edges.
# Rising edges remain a subset of ui_clk edges; crossings retain their
# ordinary 10 ns requirement. Keep this aligned with jmr_js_core.sv.
create_generated_clock -name vm_clk -edges {1 2 7} \
    -source [get_pins u_core/g_vmclk_div.u_vm_bufgce/I] \
    [get_pins u_core/g_vmclk_div.u_vm_bufgce/O]

# init_calib_complete is quasi-static (asserts once at power-up, long
# before console/storage traffic) yet fanned into 51 failing
# endpoints. Standard MIG practice: exclude it from timing.
set_false_path -from [get_pins -hierarchical -filter {NAME =~ *u_ddr_calib_top/init_calib_complete*/C}]

# Congestion fix (measured: two builds differ by +399 LUTs
# at identical BRAM/DSP, yet one placed a 104% East window; the variable
# is the DDR3 bridge's 128-bit cache nets anchored to the MIG hard
# block warping the floorplan). Pin the bridge beside the MIG: the
# pinned placement reproduces the clean profile (no congestion
# window above level 5).
create_pblock pb_sram_br
add_cells_to_pblock [get_pblocks pb_sram_br] [get_cells u_sram_br]
resize_pblock [get_pblocks pb_sram_br] -add {CLOCKREGION_X1Y3}

# Paired with the common-assert / core-qualified audio-release topology.
# These are the only asynchronous boundary pins. Stage1 Q -> stage2 D and
# stage2 Q -> every leaf reset remain fully timed.
set audio_reset_first_d [get_pins -quiet -hierarchical -regexp {^mrst_sync_reg\[0\]/D$}]
set audio_reset_sync_clr [get_pins -quiet -hierarchical -regexp {^mrst_sync_reg\[[01]\]/CLR$}]
if {[llength $audio_reset_first_d] != 1} {error "Audio reset CDC: expected exactly one first-stage D pin"}
if {[llength $audio_reset_sync_clr] != 2} {error "Audio reset CDC: expected exactly two synchronizer CLR pins"}
set_false_path -to $audio_reset_first_d
set_false_path -to $audio_reset_sync_clr

# The build is area-first for the VM. These three control modules are mapped
# timing-first.
set_property -quiet BLOCK_SYNTH.STRATEGY {PERFORMANCE_OPTIMIZED} [get_cells -quiet u_core/u_cons]
set_property -quiet BLOCK_SYNTH.STRATEGY {PERFORMANCE_OPTIMIZED} [get_cells -quiet u_core/u_toolbox]
set_property -quiet BLOCK_SYNTH.STRATEGY {PERFORMANCE_OPTIMIZED} [get_cells -quiet u_core/u_stor]
