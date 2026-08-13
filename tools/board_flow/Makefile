# Nexys Video board flow — HDMI standalone smoke (Digilent rgb2dvi)
#
#   source scripts/vivado_env.sh
#   make -C tools/board_flow bit          # build .bit
#   make -C tools/board_flow flash        # volatile SRAM config (needs USB)
#   make -C tools/board_flow flash-qspi   # SPI flash — untethered after power-cycle
#
# LLM NOTE: Cursor sandbox breaks Vivado license — run on host shell.
# openFPGALoader board id: nexysVideo

ROOT := $(abspath ../..)
RTL  := $(ROOT)/rtl
OUT  := $(ROOT)/build/nexys_video
BIT  := $(OUT)/jmr_nexys_video.bit
VENV := $(ROOT)/.venv

RTL_SRCS := $(shell find $(RTL) -name '*.sv' -o -name '*.vhd' 2>/dev/null)
DVI_SRCS := $(shell find $(ROOT)/third_party/digilent_rgb2dvi/src -name '*.vhd' 2>/dev/null)

.PHONY: bit flash flash-qspi clean

bit: $(BIT)

$(OUT):
	mkdir -p $(OUT)

ifndef VIVADO
$(BIT):
	@echo "Set VIVADO=…  (source $(ROOT)/scripts/vivado_env.sh first)"; exit 1
else
$(BIT): $(RTL_SRCS) $(DVI_SRCS) $(ROOT)/constraints/nexys_video.xdc $(ROOT)/tools/board_flow/vivado_build.tcl | $(OUT)
	$(VIVADO) -mode batch -source $(ROOT)/tools/board_flow/vivado_build.tcl \
		-tclargs $(ROOT) $(OUT)
endif

# Volatile config — lost when you unplug USB power
flash: $(BIT)
	@if command -v openFPGALoader >/dev/null 2>&1; then \
	  openFPGALoader -b nexysVideo $(BIT); \
	else \
	  echo "Install openFPGALoader"; exit 1; \
	fi

# Quad-SPI flash — board boots HDMI alone after PROG/power (set JP1 to QSPI)
# Erase+program is slow (minutes). This is the untethered path.
flash-qspi: $(BIT)
	@if command -v openFPGALoader >/dev/null 2>&1; then \
	  openFPGALoader -b nexysVideo -f $(BIT); \
	else \
	  echo "Install openFPGALoader"; exit 1; \
	fi

clean:
	rm -rf $(OUT)
