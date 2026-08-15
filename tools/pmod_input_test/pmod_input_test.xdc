# Pmod input LED test only — do not reuse the full JS XDC (HDMI/SD/FT245).
# Pins from Digilent Nexys-Video-Master.xdc. No CLOCK_DEDICATED_ROUTE BACKBONE
# (this design clocks fabric from clk100 directly, same as hid_led_blink).

set_property -dict { PACKAGE_PIN R4 IOSTANDARD LVCMOS33 } [get_ports { clk100 }]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk100 }]

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

## USB HID PS/2 from PIC24 (J15) — pull-ups required (RM §8). Host TX = inout.
## PULLTYPE: Vivado 2026.1 deprecates dict PULLUP (UG912); both set so IOB pull-up sticks.
set_property -dict { PACKAGE_PIN W17 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { ps2_clk }]
set_property -dict { PACKAGE_PIN N13 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { ps2_data }]
set_property PULLTYPE PULLUP [get_ports { ps2_clk }]
set_property PULLTYPE PULLUP [get_ports { ps2_data }]

## Pmod JA top row — Pmod PS/2 (pin1=Data pin3=Clock)
set_property -dict { PACKAGE_PIN AB22 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { pmod_ps2_data }]
set_property -dict { PACKAGE_PIN AB20 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { pmod_ps2_clk }]

## Pmod JB — Mini I2C joystick 0x5A (SCL=JB1 SDA=JB2)
set_property -dict { PACKAGE_PIN V9 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { joy_scl }]
set_property -dict { PACKAGE_PIN V8 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { joy_sda }]
