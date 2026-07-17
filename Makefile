# AXI Buffer DMA project entry point

SIM        ?= iverilog
GUI        ?= verdi
TEST       ?= byte_addressing
TEST_KIND  ?= 1
FSDB       ?= 0
SEED       ?= 1
PLUSARGS   ?=
DEFINES    ?=
INCDIRS    ?=
VERDI_HOME ?=

# sim/Makefile contains Bash conditionals and uses tee for compile/run logs.
# Passing Bash plus pipefail ensures [[ ... ]] is portable and simulator
# failures are not hidden by a successful tee process.
SIM_SHELL_VARS := \
	SHELL=/bin/bash \
	.SHELLFLAGS=-o\ pipefail\ -c

SIM_VARS := \
	SIM=$(SIM) \
	GUI=$(GUI) \
	TEST=$(TEST) \
	TEST_KIND=$(TEST_KIND) \
	FSDB=$(FSDB) \
	SEED=$(SEED) \
	PLUSARGS="$(PLUSARGS)" \
	DEFINES="$(DEFINES)" \
	INCDIRS="$(INCDIRS)" \
	VERDI_HOME="$(VERDI_HOME)"

.PHONY: all sim compile run regression gui verdi vcs-dry-run synthesis lint \
        print-config clean distclean help

all: regression

sim compile run regression gui verdi vcs-dry-run print-config:
	$(MAKE) -C sim $@ $(SIM_SHELL_VARS) $(SIM_VARS)

synthesis:
	$(MAKE) -C synth all

lint:
	verilator --lint-only --sv --Wall -Wno-fatal \
		--top-module axi_buf_dma \
		rtl/dma_pkg.sv rtl/axi_buf_dma_buffer.sv rtl/axi_buf_dma.sv

clean:
	$(MAKE) -C sim clean $(SIM_SHELL_VARS)
	$(MAKE) -C synth clean

distclean:
	$(MAKE) -C sim distclean $(SIM_SHELL_VARS)
	$(MAKE) -C synth clean

help:
	@echo ""
	@echo "============================================"
	@echo " AXI Buffer DMA build and simulation targets"
	@echo "============================================"
	@echo ""
	@echo "Targets:"
	@echo "  make sim          Compile and run one selected test"
	@echo "  make compile      Compile the selected test only"
	@echo "  make run          Run the existing selected-test executable"
	@echo "  make regression   Run the complete Icarus RTL regression"
	@echo "  make vcs-dry-run  Validate generated VCS/FSDB commands without VCS"
	@echo "  make gui          Open the GUI selected by GUI=<tool>"
	@echo "  make verdi        Open Verdi directly"
	@echo "  make synthesis    Run open-source elaboration and synthesis"
	@echo "  make lint         Run Verilator synthesis-oriented lint"
	@echo "  make print-config Show current simulation settings"
	@echo "  make clean        Remove generated simulation and synthesis files"
	@echo "  make distclean    Remove the complete simulation build directory"
	@echo "  make help         Display this help"
	@echo ""
	@echo "Variables:"
	@echo "  SIM=iverilog|vcs       Simulator; default: iverilog"
	@echo "  GUI=verdi              GUI dispatcher selection; default: verdi"
	@echo "  TEST=<name>            Test selection; default: byte_addressing"
	@echo "  TEST_KIND=<1..6>       Error-injection subtype; default: 1"
	@echo "  FSDB=0|1               Enable FSDB for VCS"
	@echo "  SEED=<number>           Simulation random seed"
	@echo "  PLUSARGS='+ARG=VALUE'   Runtime plusargs"
	@echo "  DEFINES='D1 D2'         Compile definitions"
	@echo "  INCDIRS='dir1 dir2'     Include directories"
	@echo "  VERDI_HOME=<path>       Verdi installation root for VCS PLI"
	@echo ""
	@echo "Examples:"
	@echo "  make sim"
	@echo "  make sim SIM=iverilog TEST=byte_boundary"
	@echo "  make sim SIM=vcs TEST=byte_addressing"
	@echo "  make sim SIM=vcs TEST=byte_addressing FSDB=1 VERDI_HOME=/tools/verdi"
	@echo "  make sim TEST=byte_error TEST_KIND=3"
	@echo "  make vcs-dry-run"
	@echo "  make gui GUI=verdi"
	@echo "  make verdi"
	@echo "  make regression"
	@echo "  make synthesis"
	@echo ""
