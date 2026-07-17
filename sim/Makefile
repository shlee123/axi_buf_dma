# Simulation Makefile dispatcher.

SIM_MK_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

include $(SIM_MK_DIR)/config.mk
include $(SIM_MK_DIR)/compile.mk
include $(SIM_MK_DIR)/gui.mk
include $(SIM_MK_DIR)/regression.mk

.PHONY: all sim vcs-dry-run print-config clean distclean help

all: sim
sim: check compile run

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

help:
	@echo "Targets: sim compile run regression gui verdi vcs-dry-run print-config clean help"
	@echo "Variables: SIM=iverilog|vcs GUI=verdi TEST=<name> FSDB=0|1 SEED=<n> VERDI_HOME=<path>"
	@echo "Examples:"
	@echo "  make sim SIM=iverilog TEST=byte_boundary"
	@echo "  make sim SIM=vcs TEST=byte_addressing FSDB=1 VERDI_HOME=/tools/verdi"
	@echo "  make gui GUI=verdi TEST=byte_addressing"
