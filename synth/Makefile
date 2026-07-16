ROOT := ..
BUILD := build
RTL := \
	$(ROOT)/rtl/dma_pkg.sv \
	$(ROOT)/rtl/axi_buf_dma_buffer.sv \
	$(ROOT)/rtl/axi_buf_dma.sv
YOSYS_RTL := $(BUILD)/axi_buf_dma_yosys.sv

.PHONY: all elaborate yosys clean

all: elaborate yosys

$(BUILD):
	mkdir -p $(BUILD)

# Front-end elaboration catches unresolved modules, illegal selects, and width issues.
elaborate: $(BUILD)
	iverilog -g2012 -Wall -Wimplicit -tnull -s axi_buf_dma $(RTL)

# Debian/Ubuntu Yosys 0.33 does not parse SystemVerilog package imports. Build an
# equivalent synthesis-only translation unit by extracting the package typedefs
# at compilation-unit scope and removing the import statement from the controller.
$(YOSYS_RTL): $(RTL) | $(BUILD)
	@awk 'BEGIN { emit=0 } \
	  /typedef enum logic/ { emit=1 } \
	  emit { print } \
	  /} dma_state_t;/ { emit=0 } \
	  /} dma_error_code_t;/ { emit=0 }' $(ROOT)/rtl/dma_pkg.sv > $@
	@cat $(ROOT)/rtl/axi_buf_dma_buffer.sv >> $@
	@sed '/^[[:space:]]*import[[:space:]]\+dma_pkg::\*;/d' $(ROOT)/rtl/axi_buf_dma.sv >> $@

# Generic synthesis proves that the controller and synchronous SRAM wrapper map
# through a synthesis front end without latches, multiple drivers, or processes
# that Yosys cannot lower.
yosys: $(YOSYS_RTL)
	yosys -ql $(BUILD)/yosys.log -p 'read_verilog -sv $(YOSYS_RTL); hierarchy -check -top axi_buf_dma; proc; check -assert; memory; opt; check -assert; stat'
	@grep -E 'ERROR:|Warning: multiple conflicting drivers' $(BUILD)/yosys.log && exit 1 || true

clean:
	rm -rf $(BUILD)
