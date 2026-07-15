ROOT := ..
BUILD := build
SIMV := $(BUILD)/tb_axi_buf_dma.vvp
SIMV_BP := $(BUILD)/tb_axi_buf_dma_backpressure.vvp

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

BACKPRESSURE_PARAMS := \
  -Paxi_memory_model.AW_STALL_CYCLES=3 \
  -Paxi_memory_model.W_STALL_EVERY=2 \
  -Paxi_memory_model.W_STALL_CYCLES=2 \
  -Paxi_memory_model.AR_STALL_CYCLES=4 \
  -Paxi_memory_model.R_GAP_CYCLES=3

.PHONY: all compile run compile-backpressure run-backpressure run-errors regression clean

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

run-errors: $(BUILD)
	@set -e; \
	for kind in 1 2 3 4 5 6; do \
	  echo "Running directed error test $$kind"; \
	  iverilog -g2012 -Wall -DTEST_KIND=$$kind -s tb_axi_buf_dma_error \
	    -o $(BUILD)/tb_axi_buf_dma_error_$$kind.vvp $(RTL) $(TB_ERROR); \
	  vvp $(BUILD)/tb_axi_buf_dma_error_$$kind.vvp; \
	done

regression: run run-backpressure run-errors

clean:
	rm -rf $(BUILD)
