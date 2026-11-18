# Same area/timing split as the current Vision build.
set_property -quiet BLOCK_SYNTH.STRATEGY {PERFORMANCE_OPTIMIZED} [get_cells -quiet u_core/u_cons]
set_property -quiet BLOCK_SYNTH.STRATEGY {PERFORMANCE_OPTIMIZED} [get_cells -quiet u_core/u_toolbox]
set_property -quiet BLOCK_SYNTH.STRATEGY {PERFORMANCE_OPTIMIZED} [get_cells -quiet u_core/u_stor]

# Generated VM clock and held-audio constraints must be visible DURING
# synthesis, matching Vision, rather than only after netlist generation.
create_generated_clock -name vm_clk -edges {1 2 7} -source [get_pins u_core/g_vmclk_div.u_vm_bufgce/I] [get_pins u_core/g_vmclk_div.u_vm_bufgce/O]
# Audio uses the unchanged held-payload request/acknowledgement protocol.
set_false_path -to [get_pins -hier -regexp {sound/tgl_sync_reg\[0\]/D}]
set_false_path -to [get_pins -hier -regexp {.*u_exec64/snd_ack_sync_reg\[0\]/D}]
set_false_path -to [get_pins -hier -regexp {game_sync_reg\[0\]/D}]
set_false_path -to [get_pins -hier -regexp {audio_reset_reg\[0\]/D}]
set_false_path -to [get_pins -hier -regexp {audio_reset_reg\[[01]\]/CLR}]
set audio_payload [get_cells -hier -regexp {.*u_exec64/snd_(ch|freq|vol|frames|slide)_reg(\[[0-9]+\])?}]
set audio_capture [get_cells -hier -regexp {sound/(v(freq|vol|frames|slide|phase)|ph23_q)_reg.*}]
set audio_capture_pins [get_pins -of_objects $audio_capture -filter {REF_PIN_NAME == D || REF_PIN_NAME == CE || REF_PIN_NAME == R || REF_PIN_NAME == S}]
set_max_delay -datapath_only 83.333 -from $audio_payload -to $audio_capture_pins
set_false_path -to [get_pins -hier -regexp {game_sync_reg\[[01]\]/CLR}]
