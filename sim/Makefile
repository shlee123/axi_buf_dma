ROOT := ..
BUILD := build
SIMV := $(BUILD)/tb_axi_buf_dma.vvp

RTL := \
  $(ROOT)/rtl/dma_pkg.sv \
  $(ROOT)/rtl/axi_buf_dma.sv

TB := \
  $(ROOT)/tb/axi_memory_model.sv \
  $(ROOT)/tb/tb_axi_buf_dma.sv

.PHONY: all compile run clean

all: run

$(BUILD):
	mkdir -p $(BUILD)

compile: $(BUILD)
	iverilog -g2012 -Wall -s tb_axi_buf_dma -o $(SIMV) $(RTL) $(TB)

run: compile
	vvp $(SIMV)

clean:
	rm -rf $(BUILD)
