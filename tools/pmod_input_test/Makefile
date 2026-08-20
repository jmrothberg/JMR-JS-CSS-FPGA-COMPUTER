# NOT FPGA-SIM. LED-only board proof. Own build dir — never touches
# build/nexys_video or sim/sim_build_synth. Do not add these .sv files to
# sim/Makefile CORE_SRCS. I2C sources here are snapshots; live PHY is rtl/phys/.
# Foolproof Pmod PS/2 + I2C joystick LED test.
#
#   source scripts/vivado_env.sh
#   make -C tools/pmod_input_test bit flash
#
# Do NOT run this while another Vivado is building the JS bit.

ROOT := $(abspath ../..)
OUT  := $(ROOT)/build/pmod_input_test
BIT  := $(OUT)/pmod_input_test.bit

.PHONY: bit flash clean

bit: $(BIT)

$(OUT):
	mkdir -p $(OUT)

# Abort if the JS board-flow Vivado is still running (same license / USB).
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
$(BIT): $(ROOT)/rtl/phys/ps2_rx.sv $(ROOT)/rtl/phys/ps2_decode.sv \
		jmr_i2c_master.sv jmr_i2c_joy.sv usb_ps2_try.sv top_pmod_input_test.sv \
		pmod_input_test.xdc vivado_build.tcl | $(OUT)
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
