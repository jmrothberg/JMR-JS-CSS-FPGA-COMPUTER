# NOT FPGA-SIM. Audio-only board proof. Own build dir — never touches
# build/nexys_video* or sim/sim_build_synth. Do not add these .sv files to
# sim/Makefile CORE_SRCS or to tools/board_flow/vivado_build.tcl.
#
# Phase 0 of the line-out PSG plan: prove J5 makes a sound before any of
# it goes near the VM.
#
#   source scripts/vivado_env.sh
#   make -C tools/audio_beep_test bit flash
#
# Then: headphones or powered speakers into J5 (LINE OUT, the green jack).
# You should hear a 440 Hz beep pulsing about twice a second.
#
# Do NOT run this while another Vivado is building the JS bit — the guard
# below refuses, because both want the same license and the same machine.

ROOT := $(abspath ../..)
OUT  := $(ROOT)/build/audio_beep_test
BIT  := $(OUT)/audio_beep_test.bit

.PHONY: bit flash clean

bit: $(BIT)

$(OUT):
	mkdir -p $(OUT)

define HID_VIVADO_GUARD
	@if pgrep -x vivado >/dev/null 2>&1; then \
	  echo "REFUSE: another Vivado is running — wait for the JS bit build"; \
	  exit 1; \
	fi
endef

ifndef VIVADO
$(BIT):
	@echo "Set VIVADO=…  (source $(ROOT)/scripts/vivado_env.sh first)"; exit 1
else
$(BIT): jmr_adau1761_cfg.sv jmr_i2s_beep.sv top_audio_beep_test.sv \
		audio_beep_test.xdc vivado_build.tcl | $(OUT)
	$(HID_VIVADO_GUARD)
	$(VIVADO) -mode batch -source $(CURDIR)/vivado_build.tcl \
		-tclargs $(ROOT) $(OUT)
endif

flash: $(BIT)
	$(HID_VIVADO_GUARD)
	@if command -v openFPGALoader >/dev/null 2>&1; then \
	  openFPGALoader -b nexysVideo $(BIT); \
	else \
	  echo "Install openFPGALoader"; exit 1; \
	fi

clean:
	@echo "REFUSE: this Makefile does not delete files"
	@exit 1
