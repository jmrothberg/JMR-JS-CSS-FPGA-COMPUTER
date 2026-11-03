# NOT FPGA-SIM. Tiny HDMI mouse probe. Own build dir — never touches
# build/nexys_video or sim/sim_build_synth. Do not add this top to CORE_SRCS
# or to the JS board-flow file list.
#
# The node-locked license is uncounted, so this build may run beside
# another Vivado. It has its own project under build/mouse_probe.
#
#   source scripts/vivado_env.sh
#   make -C tools/mouse_probe bit flash
#
# Bitstream: build/mouse_probe/mouse_probe.bit
# Test bitstream (does not replace the one above):
#   make -C tools/mouse_probe bit-ja-mouse
#   build/mouse_probe/mouse_probe_J15kbd_JAmouse.bit
#   wired USB keyboard on J15, PS/2 mouse on JA.

ROOT := $(abspath ../..)
OUT  := $(ROOT)/build/mouse_probe
BIT  := $(OUT)/mouse_probe.bit
BIT_JA := $(OUT)/mouse_probe_J15kbd_JAmouse.bit

.PHONY: bit bit-ja-mouse flash clean

bit: $(BIT)

bit-ja-mouse: $(BIT_JA)

$(OUT):
	mkdir -p $(OUT)

ifndef VIVADO
$(BIT):
	@echo "Set VIVADO=…  (source $(ROOT)/scripts/vivado_env.sh first)"; exit 1
else
$(BIT): top_mouse_probe.sv mouse_probe_host.sv mouse_probe.xdc vivado_build.tcl \
		$(ROOT)/rtl/video/jmr_mouse_overlay.sv $(ROOT)/rtl/video/jmr_rgb2dvi_wrap.vhd | $(OUT)
	$(VIVADO) -mode batch -source $(CURDIR)/vivado_build.tcl \
		-tclargs $(ROOT) $(OUT)

$(BIT_JA): top_mouse_probe.sv mouse_probe_host.sv mouse_probe.xdc vivado_build.tcl \
		$(ROOT)/rtl/video/jmr_mouse_overlay.sv $(ROOT)/rtl/video/jmr_rgb2dvi_wrap.vhd | $(OUT)
	$(VIVADO) -mode batch -source $(CURDIR)/vivado_build.tcl \
		-tclargs $(ROOT) $(OUT) ja_mouse
endif

flash: $(BIT)
	@if command -v openFPGALoader >/dev/null 2>&1; then \
	  openFPGALoader -b nexysVideo $(BIT); \
	else \
	  echo "Install openFPGALoader"; exit 1; \
	fi

clean:
	@echo "REFUSE: this Makefile does not delete files"
	@exit 1
