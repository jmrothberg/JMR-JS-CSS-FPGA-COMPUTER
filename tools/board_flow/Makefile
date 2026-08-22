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
# Do not `make clean` unless you want another first-build.
# Parallelism: synth_design mapping OOM'd at 7 workers (16:17). UG901 has
# one thread knob for all of synth — cap synth at 2. Place/route stays 8.
# `-jobs` is parallel runs, not mapping workers. Do not raise synth threads
# unless JMR_VIVADO_ALLOW_WIDE=1. After synth_1 100%, a DCP is written;
# mapping cannot resume mid-step. Never bit-fresh unless MIG/XDC/file list.
JMR_VIVADO_SYNTH_THREADS ?= 2
JMR_VIVADO_IMPL_THREADS ?= 8
JMR_VIVADO_JOBS ?= 1
JMR_VIVADO_THREADS ?= $(JMR_VIVADO_SYNTH_THREADS)
export JMR_VIVADO_SYNTH_THREADS JMR_VIVADO_IMPL_THREADS JMR_VIVADO_JOBS JMR_VIVADO_THREADS
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

# Forensic: per-instance utilization from the EXISTING checkpoint (~5 min,
# no resynthesis). Answers "why two framebuffers / where are the LUTs".
hier:
	@test -n "$(VIVADO)" || { echo "Set VIVADO= (source scripts/vivado_env.sh)"; exit 1; }
	$(VIVADO) -mode batch -nolog -nojournal -source report_hier.tcl

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
