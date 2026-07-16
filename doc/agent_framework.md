# Agent Framework

The repository uses GitHub-hosted Actions as the execution environment. No self-hosted Windows Agent Runner is required.

## Development loop

1. Create a same-repository `agent/<task>` branch.
2. Update RTL, tests, synthesis scripts, or documentation.
3. Open a pull request to `main`.
4. Run `RTL Regression` and `Synthesis Check` on the exact head commit.
5. Diagnose failures and update the same branch.
6. Merge only after both gates pass and review blockers are cleared.

## Required checks

`RTL Regression` covers byte addressing, unaligned transfers, 4 KB splitting, backpressure, random transfers, protocol errors, and timeout handling.

`Synthesis Check` performs simulation-only construct scanning, Icarus elaboration, Verilator lint, SRAM interface validation, and generic Yosys synthesis.

## SRAM boundary

`axi_buf_dma_buffer` is a synchronous single-port 128 x 32-bit wrapper with `clk`, `address`, `wr_en`, `csn`, `din`, and `dout`. Foundry SRAM, FPGA RAM, or vendor IP may replace its implementation without changing the DMA datapath.

## Notifications

After the complete verification stage is accepted, the project completion summary is sent to `tony_lee@syntronix.com.tw` through the connected Gmail capability.
