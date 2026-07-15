# AXI Buffer DMA Verification Test Plan V1

## 1. Objective

Verify that the V1 DMA controller transfers 32-bit local-buffer words over a 64-bit AXI4 master interface while meeting the approved control, error, timeout and interrupt requirements.

## 2. Current Smoke Test

`tb/tb_axi_buf_dma.sv` currently performs:

1. Reset initialization.
2. External local-buffer writes.
3. Three-word buffer-to-AXI transfer.
4. Verification of one full 64-bit beat and one odd-word partial beat.
5. Two-word AXI-to-buffer transfer.
6. Verification through the registered external buffer read interface.
7. Misaligned-address error test.
8. Error interrupt assertion and clear test.

## 3. Directed Test Matrix

| ID | Test | Expected Result |
|---|---|---|
| WR_001 | One-word DMA write | One beat, `WSTRB=0x0F`, `WLAST=1` |
| WR_002 | Two-word DMA write | One full beat, `WSTRB=0xFF` |
| WR_003 | Odd-length write | Final beat lower word only |
| WR_004 | 128-word write | 64 data beats |
| RD_001 | One-word DMA read | Only lower 32 bits stored |
| RD_002 | Odd-length read | Final upper 32 bits discarded |
| RD_003 | 128-word read | 64 data beats |
| BURST_001 | Transfer ending at 4 KB boundary | No burst crosses boundary |
| BURST_002 | Transfer spanning 4 KB boundary | Operation split into two bursts |
| BP_001 | AW backpressure | AW payload remains stable |
| BP_002 | W backpressure | W payload remains stable |
| BP_003 | B response delay | Timeout counter resets only on progress |
| BP_004 | AR backpressure | AR payload remains stable |
| BP_005 | R data gaps | DMA waits without data corruption |
| ERR_001 | Misaligned start address | No AXI request; alignment error |
| ERR_002 | AXI `BRESP` error | DMA terminates with write-response error |
| ERR_003 | AXI `RRESP` error | DMA terminates with read-response error |
| ERR_004 | Early `RLAST` | DMA terminates with early-last error |
| ERR_005 | Missing `RLAST` | DMA terminates with missing-last error |
| TO_001 | AW timeout | Timeout error and IRQ status |
| TO_002 | W timeout | Timeout error and IRQ status |
| TO_003 | B timeout | Timeout error and IRQ status |
| TO_004 | AR timeout | Timeout error and IRQ status |
| TO_005 | R timeout | Timeout error and IRQ status |
| IRQ_001 | Done interrupt disabled | Status set; output IRQ low |
| IRQ_002 | Done interrupt enabled | Status and output IRQ high |
| IRQ_003 | Error interrupt enabled | Status and output IRQ high |
| IRQ_004 | W1C clear | Selected status clears |
| IRQ_005 | Set and clear same cycle | Set wins |
| BUF_001 | External write while busy | Write ignored |
| BUF_002 | External read while busy | Registered output retained |
| RST_001 | Reset in idle | All status and valid outputs clear |
| RST_002 | Reset during transfer | Operation aborted and state cleared |

## 4. Assertions Planned

- `AWADDR`, `AWLEN`, `AWSIZE`, and `AWBURST` stable while `AWVALID && !AWREADY`.
- `WDATA`, `WSTRB`, and `WLAST` stable while `WVALID && !WREADY`.
- `ARADDR`, `ARLEN`, `ARSIZE`, and `ARBURST` stable while `ARVALID && !ARREADY`.
- `WLAST` asserted on exactly the last write beat.
- No AXI burst crosses a 4 KB boundary.
- Buffer index never exceeds 127 for a legal command.
- `dma_busy` and `dma_ready` are not simultaneously asserted during active transfer.
- Interrupt status set has priority over clear.
- AXI requests are not generated for a misaligned command.

## 5. Coverage Goals

Functional coverage shall include:

- DMA direction.
- Word counts: 1, 2, odd, even, maximum.
- Burst lengths: 1 and 64, plus a 4 KB boundary-limited burst.
- All defined error codes.
- Each timeout phase.
- Interrupt enabled and disabled states.
- AXI backpressure on each channel.

## 6. Regression Exit Criteria

V1 is ready for merge after:

- All directed tests pass.
- No assertion failures.
- All defined error paths are exercised.
- Functional coverage goals are met or waived with documented rationale.
- RTL lint produces no unresolved errors.
