# Synthesis Hardening Task

## Objective

Make the AXI Buffer DMA RTL synthesis-clean and add evidence-based synthesis checks to CI.

## Required RTL changes

1. Refactor `buffer_mem` so that all writes originate from one `always_ff` process with explicit priority between local-buffer writes and DMA read-data writes.
2. Replace the unconstrained `integer unsigned timeout_count` with a parameter-derived logic vector based on `$clog2(AXI_TIMEOUT_CYCLES)`.
3. Make the 64-bit AXI assumption explicit. Either fully parameterize byte-lane and `AxSIZE` calculations or add an elaboration-time restriction stating that V2 supports `AXI_DATA_WIDTH == 64`.
4. Preserve existing byte-addressed behavior, partial-beat packing, 4 KB splitting, error handling, and interrupt behavior.

## Mandatory validation

- run the complete `RTL Regression` suite;
- run `Synthesis Check`;
- confirm no simulation-only construct exists under `rtl/`;
- confirm no multiple procedural writer remains for `buffer_mem`;
- inspect synthesis-oriented warnings and document any intentional memory implementation limitation.

## Vendor sign-off

When a licensed runner is available, execute one of:

- Vivado: `read_verilog -sv`, `synth_design -top axi_buf_dma`, `report_utilization`, and `report_timing_summary`;
- Design Compiler: `analyze`, `elaborate`, `check_design`, `compile_ultra`, and `report_area`.

The vendor synthesis report must show no unresolved references, no multiple-driver error, and no inferred latch.
