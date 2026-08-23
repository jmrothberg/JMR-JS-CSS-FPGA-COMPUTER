# Verilator FPGA-SIM for JMR JS Computer.
# From repo root (this is the terminal command):
#   make -C sim sim_server_synth      # rebuild if rtl/sim_main.cpp is newer
#   make -C sim sim_server_synth -B   # force Verilator; keep obj_dir (not clean)
# "Nothing to be done" meant the binary was already newer than those files.
# Do not `make -C sim clean` between small RTL edits.


ROOT := $(abspath ..)
RTL  := $(ROOT)/rtl
BUILD := sim_build_synth
# Simulator runtime threads. Empty = no --threads flag = today's 1-thread build.
#   make -C sim sim_server_synth THREADS=12 -B
THREADS ?=
VTHREADS := $(if $(THREADS),--threads $(THREADS),)
FONT := $(ROOT)/vectors/font_rom.hex

.PHONY: sim_server_synth font tb_uart_link tb_ft245 tb_ps2_rx tb_ps2_typing clean
# Keep the sim server as default — extra TBs are gates, not the build
.DEFAULT_GOAL := sim_server_synth

# UART tether link testbench — must PASS before any board flash
tb_uart_link: $(BUILD)/tb_uart_link
	$(BUILD)/tb_uart_link

$(BUILD)/tb_uart_link: tb_uart_link.cpp $(RTL)/engines/jmr_uart_link.sv
	mkdir -p $(BUILD)
	verilator -cc -exe -build -j 0 \
		-Mdir $(BUILD)/obj_uart \
		-o $(abspath $(BUILD)/tb_uart_link) \
		--top-module jmr_uart_link \
		-GCLK_HZ=1000000 -GBAUD=100000 \
		-CFLAGS "-std=c++17" \
		$(RTL)/engines/jmr_uart_link.sv \
		tb_uart_link.cpp

# DPTI / FT245 PHY — PROG-cable tether (must PASS before flash)
tb_ft245: $(BUILD)/tb_ft245
	$(BUILD)/tb_ft245

$(BUILD)/tb_ft245: tb_ft245.cpp $(RTL)/engines/jmr_ft245_async.sv
	mkdir -p $(BUILD)
	verilator -cc -exe -build -j 0 \
		-Mdir $(BUILD)/obj_ft245 \
		-o $(abspath $(BUILD)/tb_ft245) \
		--top-module jmr_ft245_async \
		-CFLAGS "-std=c++17" \
		$(RTL)/engines/jmr_ft245_async.sv \
		tb_ft245.cpp

# PS/2 receiver — debounce must still assemble Set-2 bytes
tb_ps2_rx: $(BUILD)/tb_ps2_rx
	$(BUILD)/tb_ps2_rx

$(BUILD)/tb_ps2_rx: tb_ps2_rx.cpp $(RTL)/phys/ps2_rx.sv
	mkdir -p $(BUILD)
	verilator -cc -exe -build -j 0 \
		-Mdir $(BUILD)/obj_ps2 \
		-o $(abspath $(BUILD)/tb_ps2_rx) \
		--top-module ps2_rx \
		-CFLAGS "-std=c++17" \
		$(RTL)/phys/ps2_rx.sv \
		tb_ps2_rx.cpp

# PS/2 end-to-end: waveforms → decode table → type HELP into console
tb_ps2_typing: $(BUILD)/tb_ps2_typing
	$(BUILD)/tb_ps2_typing

$(BUILD)/tb_ps2_typing: tb_ps2_typing.cpp tb_ps2_typing_top.sv \
		$(RTL)/phys/ps2_rx.sv $(RTL)/phys/ps2_decode.sv \
		$(RTL)/engines/jmr_keyboard_fifo.sv $(RTL)/engines/jmr_video_vram.sv \
		$(RTL)/engines/jmr_console_engine.sv
	mkdir -p $(BUILD)
	verilator -cc -exe -build -j 0 \
		-Mdir $(BUILD)/obj_ps2_typing \
		-o $(abspath $(BUILD)/tb_ps2_typing) \
		--top-module tb_ps2_typing_top \
		-Wno-UNOPTTHREADS -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC \
		-CFLAGS "-std=c++17" \
		tb_ps2_typing_top.sv \
		$(RTL)/phys/ps2_rx.sv $(RTL)/phys/ps2_decode.sv \
		$(RTL)/engines/jmr_keyboard_fifo.sv $(RTL)/engines/jmr_video_vram.sv \
		$(RTL)/engines/jmr_console_engine.sv \
		tb_ps2_typing.cpp

font: $(FONT)
$(FONT): $(ROOT)/tools/export_font_rom_hex.py $(ROOT)/functional_model/font8.py
	$(ROOT)/.venv/bin/python $(ROOT)/tools/export_font_rom_hex.py
	cp -f $(FONT) $(RTL)/video/font_rom.hex

sim_server_synth: $(BUILD)/jmr_js_sim_server
	@echo "OK FPGA-SIM $(BUILD)/jmr_js_sim_server"
	@echo "    already current if Make skipped Verilator. Force: make -C sim sim_server_synth -B"

CORE_SRCS := \
	$(RTL)/engines/jmr_keyboard_fifo.sv \
	$(RTL)/engines/jmr_video_vram.sv \
	$(RTL)/engines/jmr_console_engine.sv \
	$(RTL)/engines/jmr_mini_fb.sv \
	$(RTL)/engines/jmr_rectdemo_engine.sv \
	$(RTL)/engines/jmr_value.sv \
	$(RTL)/engines/jmr_js_vm_pkg.sv \
	$(RTL)/engines/jmr_js_vm_exec64.sv \
	$(RTL)/engines/jmr_js_vm.sv \
	$(RTL)/engines/jmr_sram_model.sv \
	$(RTL)/engines/jmr_palette_bram.sv \
	$(RTL)/engines/storage_engine.sv \
	$(RTL)/phys/sd_spi_master.sv \
	$(RTL)/jmr_js_core.sv
# FPGA-SIM input = core key_evt_* / joy_in (GUI tether). Do not add
# tools/pmod_input_test/ , tools/hid_led_blink/ , usb_ps2_try.sv ,
# jmr_i2c_*.sv , or ps2_rx / ps2_decode. Those are LED tests or board PHY.

JSB_HEX := $(ROOT)/vectors/invaders_jsb.hex
# Product titles are .HTML (compile-on-RUN). Do not require storage/INVADERS.JS.

$(BUILD)/jmr_js_sim_server: sim_main.cpp $(CORE_SRCS) $(JSB_HEX) | font
	mkdir -p $(BUILD) $(BUILD)/obj_dir
	# $readmemh path is relative to sim cwd / obj_dir — stage hex both places
	cp -f $(JSB_HEX) $(BUILD)/invaders_jsb.hex
	cp -f $(JSB_HEX) $(BUILD)/obj_dir/invaders_jsb.hex
	cp -f $(JSB_HEX) invaders_jsb.hex
	# same for the glyph ROM the VM now uses for ctx.fillText (sim cwd is sim/)
	cp -f $(FONT) $(BUILD)/font_rom.hex
	cp -f $(FONT) $(BUILD)/obj_dir/font_rom.hex
	cp -f $(FONT) font_rom.hex
	# SD_RUN_DIV stays at the module default (clk/8). Overriding it to speed up
	# DONKEY's fat .JSH load broke LOAD entirely: at clk/4 (DIV=1) and clk/2
	# (DIV=0) the C++ card model in sim_main.cpp misses MOSI setup and every
	# LOAD returns ?IO. Load time must be fixed above the SPI layer, not here.
	# -O3 / native codegen: simulator speed only. This is the Verilator +
	# host C++ build, not the RTL — synthesis is unaffected. The VM is large
	# and the default build ran ~600k clocks/s, which made a title boot
	# longer than a debugging cycle should ever be.
	verilator -cc -exe -build -j 0 \
		-Mdir $(BUILD)/obj_dir \
		-o $(abspath $(BUILD)/jmr_js_sim_server) \
		--top-module jmr_js_core \
		-O3 $(VTHREADS) \
		-Wno-UNOPTTHREADS -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-MULTIDRIVEN -Wno-LATCH \
		-CFLAGS "-std=c++17 -O3 -march=native -fno-semantic-interposition" \
		$(CORE_SRCS) \
		sim_main.cpp

clean:
	rm -rf $(BUILD)
