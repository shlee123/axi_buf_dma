# V2.1.0 Release Acceptance Checklist

## Scope

V2.1.0 hardens the byte-based AXI Buffer DMA implementation around the synchronous 128 x 32-bit local SRAM boundary, deterministic and random regression, synthesis portability, and repeatable agent-driven development.

## Required automated gates

The release candidate commit must pass all required GitHub Actions checks on the exact commit SHA:

- RTL Regression
- Synthesis Check
- SRAM Directed Test
- Coverage Random Regression

The random regression is fixed-seed and reproducible. Any failure must preserve the failing seed and test name in the CI log.

## Functional acceptance

- Byte-addressed source and destination programming
- Byte-count transfer length
- Aligned and unaligned transfers
- Partial first and last AXI beats
- Contiguous write strobes
- AXI INCR bursts split at 4 KB boundaries
- Backpressure on AXI read and write channels
- BRESP and RRESP error reporting
- RLAST protocol checking
- Timeout handling
- Synchronous single-port SRAM read/write behavior

## Synthesis acceptance

Open-source elaboration, lint, and generic synthesis are mandatory CI gates. Vendor scripts for Vivado and Synopsys Design Compiler must remain batch-mode entry points and must not silently claim technology sign-off.

Technology sign-off remains external until the following inputs are supplied:

- FPGA part or ASIC target libraries
- Production clock and I/O constraints
- Licensed Vivado or Design Compiler environment
- Target-specific SRAM macro or inference policy

## Documentation acceptance

Before tagging the release candidate, verify that README, architecture, design, verification, programmer guide, Agent Framework guide, roadmap, and release notes consistently describe byte units and the synchronous SRAM boundary.

## Notification

After the release-candidate verification gates pass and review blockers are cleared, send the verification completion summary to `tony_lee@syntronix.com.tw` using the connected Gmail capability. Include exact CI status, regression scope, and remaining technology-signoff limitations.
