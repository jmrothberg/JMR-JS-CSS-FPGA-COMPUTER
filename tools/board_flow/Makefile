# Nexys Video board flow — HDMI standalone smoke (Digilent rgb2dvi)
#
#   source scripts/vivado_env.sh
#   make -C tools/board_flow bit          # .bit/.bin — reuses project/MIG/DCP
#   make -C tools/board_flow bit-fresh    # recreate project (MIG/XDC/file list)
#   make -C tools/board_flow flash        # volatile SRAM config (needs USB)
#   make -C tools/board_flow flash-qspi   # SPI flash — untethered after power-cycle
#
# First T200 bit is slow (1–3 h): MIG generate + full synth of jmr_js_vm + impl.
# Later bits open build/nexys_video/vivado, skip MIG create, incremental synth.
# Do not `make clean` unless you want another first-build. JMR_VIVADO_JOBS=2
# default (this VM+MIG is RAM-heavy; raise only if you have headroom).
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

.PHONY: bit bit-fresh flash flash-qspi clean

bit: $(BIT)

# Recreate Vivado project + MIG (file list / pinout / IP change). Leaves RTL.
bit-fresh:
	$(MAKE) FRESH=1 -B bit

$(OUT):
	mkdir -p $(OUT)

ifndef VIVADO
$(BIT):
	@echo "Set VIVADO=…  (source $(ROOT)/scripts/vivado_env.sh first)"; exit 1
else
$(BIT): $(RTL_SRCS) $(DVI_SRCS) $(ROOT)/constraints/nexys_video.xdc $(ROOT)/tools/board_flow/vivado_build.tcl $(ROOT)/tools/board_flow/mig_a.prj | $(OUT)
	$(VIVADO) -mode batch -source $(ROOT)/tools/board_flow/vivado_build.tcl \
		-tclargs $(ROOT) $(OUT) $(if $(filter 1,$(FRESH)),fresh)
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
