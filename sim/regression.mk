# Directed and regression targets.

.PHONY: regression legacy-regression release-check \
        run-byte-addressing run-byte-backpressure run-byte-boundary run-byte-random \
        run-byte-error run-byte-errors run-basic run-boundary run-read-boundary \
        run-length-sweep run-random run-random-read run-error run-errors

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
