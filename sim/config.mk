# Shared simulation configuration and testcase mapping.

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
TEST_KIND ?= 1

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
