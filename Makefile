# Unified RTL Simulation Makefile

SHELL := /bin/bash

SIM        ?= iverilog
TOP        ?= tb_top
FILELIST   ?= filelist.f
BUILD_DIR  ?= build
SIM_DIR    ?= $(BUILD_DIR)/sim
LOG_DIR    ?= $(BUILD_DIR)/log
WAVE_DIR   ?= $(BUILD_DIR)/wave

FSDB       ?= 0
FSDB_FILE  ?= $(WAVE_DIR)/$(TOP).fsdb

SEED       ?= 1
PLUSARGS   ?=
DEFINES    ?=
INCDIRS    ?=

IVERILOG   ?= iverilog
VVP        ?= vvp
VCS        ?= vcs
VERDI      ?= verdi
VERDI_HOME ?=

IVERILOG_COMPILE_OPTS ?= -g2012 -Wall
IVERILOG_RUN_OPTS     ?=
VCS_COMPILE_OPTS      ?= -full64 -sverilog -timescale=1ns/1ps -debug_access+all -kdb -lca
VCS_RUN_OPTS          ?= -lca

NOVAS_TAB ?= $(VERDI_HOME)/share/PLI/VCS/LINUX64/novas.tab
NOVAS_PLI ?= $(VERDI_HOME)/share/PLI/VCS/LINUX64/pli.a

DEFINE_OPTS_IVL := $(foreach d,$(DEFINES),-D$(d))
DEFINE_OPTS_VCS := $(foreach d,$(DEFINES),+define+$(d))
INCDIR_OPTS_IVL := $(foreach d,$(INCDIRS),-I$(d))
INCDIR_OPTS_VCS := $(foreach d,$(INCDIRS),+incdir+$(d))

IVERILOG_EXE := $(SIM_DIR)/$(TOP).vvp
VCS_EXE      := $(SIM_DIR)/simv
FSDB_DUMP_SV := $(SIM_DIR)/fsdb_dump.sv

COMPILE_LOG := $(LOG_DIR)/compile_$(SIM).log
SIM_LOG     := $(LOG_DIR)/sim_$(SIM).log
VERDI_LOG   := $(LOG_DIR)/verdi.log

SUPPORTED_SIMS := iverilog vcs

ifeq ($(filter $(SIM),$(SUPPORTED_SIMS)),)
  $(error Unsupported SIM='$(SIM)'. Use SIM=iverilog or SIM=vcs)
endif

.PHONY: all sim compile run verdi help clean distclean print-config check dirs

all: sim

sim: check compile run

compile: dirs
ifeq ($(SIM),iverilog)
	@echo "[INFO] Compiling with Icarus Verilog"
	@$(IVERILOG) $(IVERILOG_COMPILE_OPTS) \
		$(DEFINE_OPTS_IVL) $(INCDIR_OPTS_IVL) \
		-s $(TOP) -o $(IVERILOG_EXE) -f $(FILELIST) \
		2>&1 | tee $(COMPILE_LOG)
else ifeq ($(SIM),vcs)
	@echo "[INFO] Compiling with VCS"
	@if [[ "$(FSDB)" == "1" && -z "$(VERDI_HOME)" ]]; then \
		echo "[ERROR] FSDB=1 requires VERDI_HOME."; exit 1; \
	fi
	@$(VCS) $(VCS_COMPILE_OPTS) \
		$(DEFINE_OPTS_VCS) $(INCDIR_OPTS_VCS) \
		$(if $(filter 1,$(FSDB)),+define+ENABLE_FSDB -P $(NOVAS_TAB) $(NOVAS_PLI) $(FSDB_DUMP_SV),) \
		-top $(TOP) -o $(VCS_EXE) -f $(FILELIST) \
		-l $(COMPILE_LOG)
endif

run: dirs
ifeq ($(SIM),iverilog)
	@test -x "$(IVERILOG_EXE)" || { echo "[ERROR] Run 'make compile SIM=iverilog' first."; exit 1; }
	@$(VVP) $(IVERILOG_RUN_OPTS) $(IVERILOG_EXE) \
		+ntb_random_seed=$(SEED) $(PLUSARGS) \
		2>&1 | tee $(SIM_LOG)
else ifeq ($(SIM),vcs)
	@test -x "$(VCS_EXE)" || { echo "[ERROR] Run 'make compile SIM=vcs' first."; exit 1; }
	@cd $(SIM_DIR) && ./simv $(VCS_RUN_OPTS) \
		+ntb_random_seed=$(SEED) \
		+FSDB_FILE=$(abspath $(FSDB_FILE)) \
		$(PLUSARGS) -l $(abspath $(SIM_LOG))
endif

verdi: dirs
	@echo "[INFO] Starting Verdi"
	@if [[ -f "$(FSDB_FILE)" ]]; then \
		echo "[INFO] Opening source and waveform: $(FSDB_FILE)"; \
		$(VERDI) -sv -f $(FILELIST) -top $(TOP) \
			$(DEFINE_OPTS_VCS) $(INCDIR_OPTS_VCS) \
			-ssf $(FSDB_FILE) -l $(VERDI_LOG) & \
	else \
		echo "[INFO] FSDB not found; opening source/test environment only."; \
		$(VERDI) -sv -f $(FILELIST) -top $(TOP) \
			$(DEFINE_OPTS_VCS) $(INCDIR_OPTS_VCS) \
			-l $(VERDI_LOG) & \
	fi

check:
	@test -f "$(FILELIST)" || { echo "[ERROR] Missing file list: $(FILELIST)"; exit 1; }
ifeq ($(SIM),iverilog)
	@command -v $(IVERILOG) >/dev/null || { echo "[ERROR] iverilog not found."; exit 1; }
	@command -v $(VVP) >/dev/null || { echo "[ERROR] vvp not found."; exit 1; }
else
	@command -v $(VCS) >/dev/null || { echo "[ERROR] vcs not found."; exit 1; }
endif

print-config:
	@echo "SIM        = $(SIM)"
	@echo "TOP        = $(TOP)"
	@echo "FILELIST   = $(FILELIST)"
	@echo "FSDB       = $(FSDB)"
	@echo "FSDB_FILE  = $(FSDB_FILE)"
	@echo "SEED       = $(SEED)"
	@echo "DEFINES    = $(DEFINES)"
	@echo "INCDIRS    = $(INCDIRS)"
	@echo "PLUSARGS   = $(PLUSARGS)"
	@echo "VERDI_HOME = $(VERDI_HOME)"

clean:
	@rm -rf $(SIM_DIR) $(LOG_DIR)

distclean:
	@rm -rf $(BUILD_DIR)

help:
	@echo ""
	@echo "Targets:"
	@echo "  make sim          Compile and run RTL simulation"
	@echo "  make compile      Compile only"
	@echo "  make run          Run existing simulation executable"
	@echo "  make verdi        Open source and FSDB waveform if present"
	@echo "  make print-config Show current variable settings"
	@echo "  make clean        Remove simulation executable and logs"
	@echo "  make distclean    Remove entire build directory"
	@echo "  make help         Show this help"
	@echo ""
	@echo "Main variables:"
	@echo "  SIM=iverilog|vcs"
	@echo "  TOP=<testbench_top>"
	@echo "  FILELIST=<filelist>"
	@echo "  FSDB=0|1          FSDB is supported with VCS + Verdi PLI"
	@echo "  SEED=<number>"
	@echo "  DEFINES='DEF1 DEF2'"
	@echo "  INCDIRS='dir1 dir2'"
	@echo "  PLUSARGS='+ARG=VALUE'"
	@echo ""
	@echo "Examples:"
	@echo "  make sim"
	@echo "  make sim SIM=iverilog TOP=tb_axi_buf_dma FILELIST=filelist.f"
	@echo "  make sim SIM=vcs FSDB=1 VERDI_HOME=/tools/verdi"
	@echo "  make verdi SIM=vcs FSDB=1"
	@echo ""

dirs:
	@mkdir -p $(BUILD_DIR) $(SIM_DIR) $(LOG_DIR) $(WAVE_DIR)

$(FSDB_DUMP_SV): | dirs
	@printf '%s\n' \
		'`timescale 1ns/1ps' \
		'module fsdb_dump;' \
		'`ifdef ENABLE_FSDB' \
		'  string fsdb_file;' \
		'  initial begin' \
		'    if (!$$value$$plusargs("FSDB_FILE=%s", fsdb_file))' \
		'      fsdb_file = "wave.fsdb";' \
		'    $$fsdbDumpfile(fsdb_file);' \
		'    $$fsdbDumpvars(0);' \
		'    $$fsdbDumpMDA();' \
		'  end' \
		'`endif' \
		'endmodule' \
		'' \
		'bind $(TOP) fsdb_dump u_fsdb_dump();' > $@

ifeq ($(SIM),vcs)
  ifeq ($(FSDB),1)
compile: $(FSDB_DUMP_SV)
  endif
endif
