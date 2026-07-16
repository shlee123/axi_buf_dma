ROOT := ..
BUILD := build
RTL := \
	$(ROOT)/rtl/dma_pkg.sv \
	$(ROOT)/rtl/axi_buf_dma_buffer.sv \
	$(ROOT)/rtl/axi_buf_dma.sv

.PHONY: all elaborate yosys clean

all: elaborate yosys

$(BUILD):
	mkdir -p $(BUILD)

# Front-end elaboration catches unresolved modules, illegal selects, and width issues.
elaborate: $(BUILD)
	iverilog -g2012 -Wall -Wimplicit -tnull -s axi_buf_dma $(RTL)

# Generic synthesis proves that the controller and synchronous SRAM wrapper map
# through a synthesis front end without latches, multiple drivers, or processes
# that Yosys cannot lower.
yosys: $(BUILD)
	yosys -ql $(BUILD)/yosys.log -p 'read_verilog -sv $(RTL); hierarchy -check -top axi_buf_dma; proc; check -assert; memory; opt; check -assert; stat'
	@grep -E 'ERROR:|Warning: multiple conflicting drivers' $(BUILD)/yosys.log && exit 1 || true

clean:
	rm -rf $(BUILD)
