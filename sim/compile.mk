# Simulator compile and run targets.

.PHONY: check compile run compile-iverilog run-iverilog compile-vcs run-vcs dirs

compile: compile-$(SIM)
run: run-$(SIM)

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

dirs:
	@mkdir -p $(TEST_BUILD) $(LOG_DIR) $(WAVE_DIR)
