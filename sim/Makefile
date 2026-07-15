ROOT := ..
BUILD := build
SIMV := $(BUILD)/tb_axi_buf_dma.vvp
SIMV_BP := $(BUILD)/tb_axi_buf_dma_backpressure.vvp
SIMV_BOUNDARY := $(BUILD)/tb_axi_buf_dma_boundary.vvp
SIMV_READ_BOUNDARY := $(BUILD)/tb_axi_buf_dma_read_boundary.vvp
SIMV_LENGTH_SWEEP := $(BUILD)/tb_axi_buf_dma_length_sweep.vvp
SIMV_RANDOM := $(BUILD)/tb_axi_buf_dma_random.vvp
TEST_KIND ?= 1
SIMV_ERR := $(BUILD)/tb_axi_buf_dma_error_$(TEST_KIND).vvp
LOG_ERR := $(BUILD)/tb_axi_buf_dma_error_$(TEST_KIND).log

RTL := \
  $(ROOT)/rtl/dma_pkg.sv \
  $(ROOT)/rtl/axi_buf_dma.sv

TB := \
  $(ROOT)/tb/axi_protocol_checker.sv \
  $(ROOT)/tb/axi_memory_model.sv \
  $(ROOT)/tb/tb_axi_buf_dma.sv

TB_ERROR := \
  $(ROOT)/tb/axi_memory_model.sv \
  $(ROOT)/tb/tb_axi_buf_dma_error.sv

TB_BOUNDARY := \
  $(ROOT)/tb/axi_memory_model.sv \
  $(ROOT)/tb/tb_axi_buf_dma_boundary.sv

TB_READ_BOUNDARY := \
  $(ROOT)/tb/axi_memory_model.sv \
  $(ROOT)/tb/tb_axi_buf_dma_read_boundary.sv

TB_LENGTH_SWEEP := \
  $(ROOT)/tb/axi_memory_model.sv \
  $(ROOT)/tb/tb_axi_buf_dma_length_sweep.sv

TB_RANDOM := \
  $(ROOT)/tb/axi_memory_model.sv \
  $(ROOT)/tb/tb_axi_buf_dma_random.sv

BACKPRESSURE_PARAMS := \
  -Paxi_memory_model.AW_STALL_CYCLES=3 \
  -Paxi_memory_model.W_STALL_EVERY=2 \
  -Paxi_memory_model.W_STALL_CYCLES=2 \
  -Paxi_memory_model.AR_STALL_CYCLES=4 \
  -Paxi_memory_model.R_GAP_CYCLES=3

.PHONY: all compile run compile-backpressure run-backpressure run-boundary run-read-boundary run-length-sweep run-random run-error run-errors regression clean

all: regression

$(BUILD):
	mkdir -p $(BUILD)

compile: $(BUILD)
	iverilog -g2012 -Wall -s tb_axi_buf_dma -o $(SIMV) $(RTL) $(TB)

run: compile
	vvp $(SIMV)

compile-backpressure: $(BUILD)
	iverilog -g2012 -Wall -s tb_axi_buf_dma $(BACKPRESSURE_PARAMS) -o $(SIMV_BP) $(RTL) $(TB)

run-backpressure: compile-backpressure
	vvp $(SIMV_BP)

run-boundary: $(BUILD)
	iverilog -g2012 -Wall -s tb_axi_buf_dma_boundary -o $(SIMV_BOUNDARY) $(RTL) $(TB_BOUNDARY)
	vvp $(SIMV_BOUNDARY)

run-read-boundary: $(BUILD)
	iverilog -g2012 -Wall -s tb_axi_buf_dma_read_boundary -o $(SIMV_READ_BOUNDARY) $(RTL) $(TB_READ_BOUNDARY)
	vvp $(SIMV_READ_BOUNDARY)

run-length-sweep: $(BUILD)
	iverilog -g2012 -Wall -s tb_axi_buf_dma_length_sweep -o $(SIMV_LENGTH_SWEEP) $(RTL) $(TB_LENGTH_SWEEP)
	vvp $(SIMV_LENGTH_SWEEP)

run-random: $(BUILD)
	iverilog -g2012 -Wall -s tb_axi_buf_dma_random -o $(SIMV_RANDOM) $(RTL) $(TB_RANDOM)
	vvp $(SIMV_RANDOM)

run-error: $(BUILD)
	iverilog -g2012 -Wall -Ptb_axi_buf_dma_error.TEST_KIND=$(TEST_KIND) -s tb_axi_buf_dma_error \
	  -o $(SIMV_ERR) $(RTL) $(TB_ERROR)
	@vvp $(SIMV_ERR) | tee $(LOG_ERR)
	@case "$(TEST_KIND)" in \
	  1) expected='RESULT kind=1 error=1 code=2 irq=1 dma_irq=1 timeout=0' ;; \
	  2) expected='RESULT kind=2 error=1 code=3 irq=1 dma_irq=1 timeout=0' ;; \
	  3) expected='RESULT kind=3 error=1 code=4 irq=1 dma_irq=1 timeout=0' ;; \
	  4) expected='RESULT kind=4 error=1 code=5 irq=1 dma_irq=1 timeout=0' ;; \
	  5) expected='RESULT kind=5 error=1 code=6 irq=1 dma_irq=1 timeout=1' ;; \
	  6) expected='RESULT kind=6 error=1 code=6 irq=1 dma_irq=1 timeout=1' ;; \
	  *) echo "Unsupported TEST_KIND=$(TEST_KIND)"; exit 1 ;; \
	esac; \
	grep -F "$$expected" $(LOG_ERR) >/dev/null || { cat $(LOG_ERR); exit 1; }

run-errors: $(BUILD)
	@set -e; \
	for kind in 1 2 3 4 5 6; do \
	  echo "Running directed error test $$kind"; \
	  $(MAKE) --no-print-directory run-error TEST_KIND=$$kind; \
	done

regression: run run-backpressure run-boundary run-read-boundary run-length-sweep run-random run-errors

clean:
	rm -rf $(BUILD)
