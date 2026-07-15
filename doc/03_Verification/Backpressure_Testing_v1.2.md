# AXI Backpressure Testing v1.2

## Purpose

The AXI memory model now supports deterministic and repeatable receiver-side stalls. These controls verify that the DMA preserves AXI payloads while VALID is asserted and READY is low, and that timeout handling remains predictable.

## Parameters

| Parameter | Meaning | Default |
|---|---|---:|
| `AW_STALL_CYCLES` | Delay AWREADY after AWVALID is observed | 0 |
| `W_STALL_EVERY` | Insert a write-data stall after every N accepted beats | 0 (disabled) |
| `W_STALL_CYCLES` | Number of cycles for each write-data stall | 0 |
| `AR_STALL_CYCLES` | Delay ARREADY after ARVALID is observed | 0 |
| `R_GAP_CYCLES` | Idle cycles inserted between accepted read beats | 0 |

Default values preserve the original always-ready behavior.

## Example

```systemverilog
axi_memory_model #(
  .AW_STALL_CYCLES (3),
  .W_STALL_EVERY   (4),
  .W_STALL_CYCLES  (2),
  .AR_STALL_CYCLES (2),
  .R_GAP_CYCLES    (3)
) u_mem (...);
```

This configuration delays the write address handshake by three cycles, stalls write data for two cycles after every fourth accepted beat, delays the read address handshake by two cycles, and inserts three idle cycles between read beats.

## Required Checks

The protocol checker shall report an error if the DMA changes any of the following while stalled:

- `AWADDR`, `AWLEN`, `AWSIZE`, or `AWBURST`
- `ARADDR`, `ARLEN`, `ARSIZE`, or `ARBURST`
- `WDATA`, `WSTRB`, or `WLAST`

## Planned Regression Matrix

1. No stall baseline.
2. Address-channel-only stalls.
3. Write-data periodic stalls.
4. Read-data inter-beat gaps.
5. Simultaneous address and data stalls.
6. Stall durations below the timeout threshold.
7. Stall duration equal to or above the timeout threshold.
8. Maximum 128-word transfer under repeated stalls.
9. Odd-length transfer under repeated stalls.
10. 4 KB boundary split under repeated stalls.

## Notes

The memory model uses deterministic counters rather than unconstrained randomization. This makes CI failures reproducible. Randomized backpressure may be added later with an explicit seed interface.
