# NOT FPGA-SIM. LED-only J15 proof. Own build dir — never touches
# build/nexys_video or sim/sim_build_synth. Do not add this top to CORE_SRCS.
# Foolproof J15 USB-HID → LED test.
#
#   source scripts/vivado_env.sh
#   make -C tools/hid_led_blink bit flash
#
# Do NOT run this while another Vivado is building the JS bit.

ROOT := $(abspath ../..)
OUT  := $(ROOT)/build/hid_led_blink
BIT  := $(OUT)/hid_led_blink.bit

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
$(BIT): $(ROOT)/rtl/phys/ps2_rx.sv top_hid_led_blink.sv hid_led_blink.xdc vivado_build.tcl | $(OUT)
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
