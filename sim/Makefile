ROOT := ..
BUILD := build
LOG_DIR := $(BUILD)/log
WAVE_DIR := $(BUILD)/wave

SIM ?= iverilog
GUI ?= verdi
TEST ?= byte_addressing
FSDB ?= 0
SEED ?= 1
PLUSARGS ?=
DEFINES ?=
INCDIRS ?=
VERDI_HOME ?=

IVERILOG ?= iverilog
VVP ?= vvp
VCS ?= vcs
VERDI ?= verdi

NOVAS_TAB ?= $(VERDI_HOME)/share/PLI/VCS/LINUX64/novas.tab
NOVAS_PLI ?= $(VERDI_HOME)/share/PLI/VCS/LINUX64/pli.a

SUPPORTED_SIMS := iverilog vcs
SUPPORTED_GUIS := verdi
SUPPORTED_TESTS := byte_addressing byte_backpressure byte_boundary byte_random byte_error basic boundary read_boundary length_sweep random random_read error

ifeq ($(filter $(SIM),$(SUPPORTED_SIMS)),)
  $(error Unsupported SIM='$(SIM)'; use one of: $(SUPPORTED_SIMS))
endif
ifeq ($(filter $(GUI),$(SUPPORTED_GUIS)),)
  $(error Unsupported GUI='$(GUI)'; use one of: $(SUPPORTED_GUIS))
endif
ifeq ($(filter $(TEST),$(SUPPORTED_TESTS)),)
  $(error Unsupported TEST='$(TEST)'; use one of: $(SUPPORTED_TESTS))
endif

RTL := \
  $(ROOT)/rtl/dma_pkg.sv \
  $(ROOT)/rtl/axi_buf_dma_buffer.sv \
  $(ROOT)/rtl/axi_buf_dma.sv

COMMON_TB := $(ROOT)/tb/axi_memory_model.sv
CHECKER := $(ROOT)/tb/axi_protocol_checker.sv

TOP_byte_addressing := tb_axi_buf_dma_byte_addressing
SRC_byte_addressing := $(COMMON_TB) $(ROOT)/tb/tb_axi_buf_dma_byte_addressing.sv
TOP_byte_backpressure := tb_axi_buf_dma_byte_addressing
SRC_byte_backpressure := $(COMMON_TB) $(ROOT)/tb/tb_axi_buf_dma_byte_addressing.sv
TOP_byte_boundary := tb_axi_buf_dma_byte_boundary
SRC_byte_boundary := $(CHECKER) $(COMMON_TB) $(ROOT)/tb/tb_axi_buf_dma_byte_boundary.sv
TOP_byte_random := tb_axi_buf_dma_byte_random
SRC_byte_random := $(COMMON_TB) $(ROOT)/tb/tb_axi_buf_dma_byte_random.sv
TOP_byte_error := tb_axi_buf_dma_byte_error
SRC_byte_error := $(COMMON_TB) $(ROOT)/tb/tb_axi_buf_dma_byte_error.sv
TOP_basic := tb_axi_buf_dma
SRC_basic := $(CHECKER) $(COMMON_TB) $(ROOT)/tb/tb_axi_buf_dma.sv
TOP_boundary := tb_axi_buf_dma_boundary
SRC_boundary := $(COMMON_TB) $(ROOT)/tb/tb_axi_buf_dma_boundary.sv
TOP_read_boundary := tb_axi_buf_dma_read_boundary
SRC_read_boundary := $(COMMON_TB) $(ROOT)/tb/tb_axi_buf_dma_read_boundary.sv
TOP_length_sweep := tb_axi_buf_dma_length_sweep
SRC_length_sweep := $(COMMON_TB) $(ROOT)/tb/tb_axi_buf_dma_length_sweep.sv
TOP_random := tb_axi_buf_dma_random
SRC_random := $(COMMON_TB) $(ROOT)/tb/tb_axi_buf_dma_random.sv
TOP_random_read := tb_axi_buf_dma_random_read
SRC_random_read := $(COMMON_TB) $(ROOT)/tb/tb_axi_buf_dma_random_read.sv
TOP_error := tb_axi_buf_dma_error
SRC_error := $(COMMON_TB) $(ROOT)/tb/tb_axi_buf_dma_error.sv

TOP := $(TOP_$(TEST))
TEST_SRCS := $(SRC_$(TEST))

BACKPRESSURE_PARAMS_IVL := \
  -Paxi_memory_model.AW_STALL_CYCLES=3 \
  -Paxi_memory_model.W_STALL_EVERY=2 \
  -Paxi_memory_model.W_STALL_CYCLES=2 \
  -Paxi_memory_model.AR_STALL_CYCLES=4 \
  -Paxi_memory_model.R_GAP_CYCLES=3
BACKPRESSURE_PARAMS_VCS := \
  -pvalue+axi_memory_model.AW_STALL_CYCLES=3 \
  -pvalue+axi_memory_model.W_STALL_EVERY=2 \
  -pvalue+axi_memory_model.W_STALL_CYCLES=2 \
  -pvalue+axi_memory_model.AR_STALL_CYCLES=4 \
  -pvalue+axi_memory_model.R_GAP_CYCLES=3

TEST_COMPILE_OPTS_IVL_byte_backpressure := $(BACKPRESSURE_PARAMS_IVL)
TEST_COMPILE_OPTS_VCS_byte_backpressure := $(BACKPRESSURE_PARAMS_VCS)
TEST_COMPILE_OPTS_IVL_byte_error := -Ptb_axi_buf_dma_byte_error.TEST_KIND=$(TEST_KIND)
TEST_COMPILE_OPTS_VCS_byte_error := -pvalue+tb_axi_buf_dma_byte_error.TEST_KIND=$(TEST_KIND)
TEST_COMPILE_OPTS_IVL_error := -Ptb_axi_buf_dma_error.TEST_KIND=$(TEST_KIND)
TEST_COMPILE_OPTS_VCS_error := -pvalue+tb_axi_buf_dma_error.TEST_KIND=$(TEST_KIND)

TEST_KIND ?= 1

DEFINE_OPTS_IVL := $(foreach d,$(DEFINES),-D$(d))
DEFINE_OPTS_VCS := $(foreach d,$(DEFINES),+define+$(d))
INCDIR_OPTS_IVL := $(foreach d,$(INCDIRS),-I$(d))
INCDIR_OPTS_VCS := $(foreach d,$(INCDIRS),+incdir+$(d))

TEST_BUILD := $(BUILD)/$(SIM)/$(TEST)
SIM_EXE_IVL := $(TEST_BUILD)/$(TOP).vvp
SIM_EXE_VCS := $(TEST_BUILD)/simv
COMPILE_LOG := $(LOG_DIR)/compile_$(SIM)_$(TEST).log
SIM_LOG := $(LOG_DIR)/sim_$(SIM)_$(TEST).log
FSDB_FILE ?= $(WAVE_DIR)/$(TEST).fsdb
VERDI_LOG := $(LOG_DIR)/verdi_$(TEST).log

RELEASE_DOCS := \
  $(ROOT)/README.md \
  $(ROOT)/RELEASE_NOTES.md \
  $(ROOT)/doc/architecture.md \
  $(ROOT)/doc/design.md \
  $(ROOT)/doc/verification.md \
  $(ROOT)/doc/programmer_guide.md

.PHONY: all sim compile run gui verdi regression release-check \
        run-byte-addressing run-byte-backpressure run-byte-boundary run-byte-random \
        run-byte-error run-byte-errors legacy-regression run-basic run-boundary \
        run-read-boundary run-length-sweep run-random run-random-read run-error run-errors \
        check print-config vcs-dry-run clean distclean help dirs

all: sim
sim: check compile run
compile: compile-$(SIM)
run: run-$(SIM)
gui: $(GUI)

check:
	@command -v $(if $(filter vcs,$(SIM)),$(VCS),$(IVERILOG)) >/dev/null 2>&1 || { echo "[ERROR] simulator command not found for SIM=$(SIM)"; exit 1; }
	@test -n "$(TOP)" || { echo "[ERROR] no TOP mapping for TEST=$(TEST)"; exit 1; }

compile-iverilog: dirs
	@echo "[INFO] Icarus compile TEST=$(TEST) TOP=$(TOP)"
	@$(IVERILOG) -g2012 -Wall $(DEFINE_OPTS_IVL) $(INCDIR_OPTS_IVL) \
		$(TEST_COMPILE_OPTS_IVL_$(TEST)) -s $(TOP) -o $(SIM_EXE_IVL) \
		$(RTL) $(TEST_SRCS) 2>&1 | tee $(COMPILE_LOG)

run-iverilog: dirs
	@test -f $(SIM_EXE_IVL) || { echo "[ERROR] compile first"; exit 1; }
	@$(VVP) $(SIM_EXE_IVL) +ntb_random_seed=$(SEED) $(PLUSARGS) 2>&1 | tee $(SIM_LOG)

compile-vcs: dirs
	@if [[ "$(FSDB)" == "1" && -z "$(VERDI_HOME)" ]]; then echo "[ERROR] FSDB=1 requires VERDI_HOME"; exit 1; fi
	@echo "[INFO] VCS compile TEST=$(TEST) TOP=$(TOP) FSDB=$(FSDB)"
	@$(VCS) -full64 -sverilog -timescale=1ns/1ps -debug_access+all -kdb -lca \
		$(DEFINE_OPTS_VCS) $(INCDIR_OPTS_VCS) $(TEST_COMPILE_OPTS_VCS_$(TEST)) \
		$(if $(filter 1,$(FSDB)),+define+ENABLE_FSDB +define+FSDB_TOP=$(TOP) -P $(NOVAS_TAB) $(NOVAS_PLI) $(ROOT)/sim/fsdb_dump.sv,) \
		-top $(TOP) -o $(SIM_EXE_VCS) $(RTL) $(TEST_SRCS) -l $(COMPILE_LOG)

run-vcs: dirs
	@test -x $(SIM_EXE_VCS) || { echo "[ERROR] compile first"; exit 1; }
	@$(SIM_EXE_VCS) -lca +ntb_random_seed=$(SEED) +FSDB_FILE=$(abspath $(FSDB_FILE)) $(PLUSARGS) -l $(SIM_LOG)

verdi: dirs
	@command -v $(VERDI) >/dev/null 2>&1 || { echo "[ERROR] verdi not found"; exit 1; }
	@if [[ -f "$(FSDB_FILE)" ]]; then \
	  echo "[INFO] opening Verdi with $(FSDB_FILE)"; \
	  $(VERDI) -sv $(RTL) $(TEST_SRCS) -top $(TOP) -ssf $(FSDB_FILE) -l $(VERDI_LOG) & \
	else \
	  echo "[INFO] FSDB not found; opening source only"; \
	  $(VERDI) -sv $(RTL) $(TEST_SRCS) -top $(TOP) -l $(VERDI_LOG) & \
	fi

release-check:
	@set -e; for file in $(RELEASE_DOCS); do test -s "$$file" || { echo "Missing release document: $$file"; exit 1; }; done
	@grep -F 'V2.0.0' $(ROOT)/RELEASE_NOTES.md >/dev/null
	@grep -F 'byte' $(ROOT)/doc/programmer_guide.md >/dev/null
	@grep -F '4 KB' $(ROOT)/doc/verification.md >/dev/null
	@echo "Release documentation check passed"

run-byte-addressing:
	@$(MAKE) --no-print-directory sim SIM=iverilog TEST=byte_addressing
run-byte-backpressure:
	@$(MAKE) --no-print-directory sim SIM=iverilog TEST=byte_backpressure
run-byte-boundary:
	@$(MAKE) --no-print-directory sim SIM=iverilog TEST=byte_boundary
run-byte-random:
	@$(MAKE) --no-print-directory sim SIM=iverilog TEST=byte_random
run-byte-error:
	@$(MAKE) --no-print-directory sim SIM=iverilog TEST=byte_error TEST_KIND=$(TEST_KIND)
	@case "$(TEST_KIND)" in \
	  1) expected='RESULT kind=1 error=1 code=2 irq=1 dma_irq=1 timeout=0' ;; \
	  2) expected='RESULT kind=2 error=1 code=3 irq=1 dma_irq=1 timeout=0' ;; \
	  3) expected='RESULT kind=3 error=1 code=4 irq=1 dma_irq=1 timeout=0' ;; \
	  4) expected='RESULT kind=4 error=1 code=5 irq=1 dma_irq=1 timeout=0' ;; \
	  5) expected='RESULT kind=5 error=1 code=6 irq=1 dma_irq=1 timeout=1' ;; \
	  6) expected='RESULT kind=6 error=1 code=6 irq=1 dma_irq=1 timeout=1' ;; \
	esac; grep -F "$$expected" $(LOG_DIR)/sim_iverilog_byte_error.log >/dev/null
run-byte-errors:
	@set -e; for kind in 1 2 3 4 5 6; do $(MAKE) --no-print-directory run-byte-error TEST_KIND=$$kind; done

regression: release-check run-byte-addressing run-byte-backpressure run-byte-boundary run-byte-random run-byte-errors

run-basic:
	@$(MAKE) --no-print-directory sim SIM=iverilog TEST=basic
run-boundary:
	@$(MAKE) --no-print-directory sim SIM=iverilog TEST=boundary
run-read-boundary:
	@$(MAKE) --no-print-directory sim SIM=iverilog TEST=read_boundary
run-length-sweep:
	@$(MAKE) --no-print-directory sim SIM=iverilog TEST=length_sweep
run-random:
	@$(MAKE) --no-print-directory sim SIM=iverilog TEST=random
run-random-read:
	@$(MAKE) --no-print-directory sim SIM=iverilog TEST=random_read
run-error:
	@$(MAKE) --no-print-directory sim SIM=iverilog TEST=error TEST_KIND=$(TEST_KIND)
run-errors:
	@set -e; for kind in 1 2 3 4 5 6; do $(MAKE) --no-print-directory run-error TEST_KIND=$$kind; done
legacy-regression: run-basic run-byte-backpressure run-boundary run-read-boundary run-length-sweep run-random run-random-read run-errors

vcs-dry-run:
	@$(MAKE) --no-print-directory -n sim SIM=vcs TEST=byte_addressing FSDB=0 VCS=true
	@$(MAKE) --no-print-directory -n sim SIM=vcs TEST=byte_addressing FSDB=1 VCS=true VERDI_HOME=/mock/verdi

print-config:
	@echo "SIM=$(SIM) GUI=$(GUI) TEST=$(TEST) TOP=$(TOP) FSDB=$(FSDB)"
	@echo "SEED=$(SEED) FSDB_FILE=$(FSDB_FILE)"
	@echo "DEFINES=$(DEFINES) INCDIRS=$(INCDIRS) PLUSARGS=$(PLUSARGS)"

clean:
	rm -rf $(BUILD)
distclean: clean

dirs:
	@mkdir -p $(TEST_BUILD) $(LOG_DIR) $(WAVE_DIR)

help:
	@echo "Targets: sim compile run regression gui verdi vcs-dry-run print-config clean help"
	@echo "Variables: SIM=iverilog|vcs GUI=verdi TEST=<name> FSDB=0|1 SEED=<n> VERDI_HOME=<path>"
	@echo "Examples:"
	@echo "  make sim SIM=iverilog TEST=byte_boundary"
	@echo "  make sim SIM=vcs TEST=byte_addressing FSDB=1 VERDI_HOME=/tools/verdi"
	@echo "  make gui GUI=verdi TEST=byte_addressing"
