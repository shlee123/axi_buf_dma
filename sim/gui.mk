# Waveform and GUI targets.

.PHONY: gui verdi

gui: $(GUI)

verdi: dirs
	@command -v $(VERDI) >/dev/null 2>&1 || { echo "[ERROR] verdi not found"; exit 1; }
	@if [[ -f "$(FSDB_FILE)" ]]; then \
	  echo "[INFO] opening Verdi with $(FSDB_FILE)"; \
	  $(VERDI) -sv $(RTL) $(TEST_SRCS) -top $(TOP) -ssf $(FSDB_FILE) -l $(VERDI_LOG) & \
	else \
	  echo "[INFO] FSDB not found; opening source only"; \
	  $(VERDI) -sv $(RTL) $(TEST_SRCS) -top $(TOP) -l $(VERDI_LOG) & \
	fi
