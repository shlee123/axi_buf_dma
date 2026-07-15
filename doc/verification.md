# AXI Buffer DMA V2 Verification

## Objectives

Verification demonstrates correct byte-addressed transfers, legal AXI behavior, correct local-buffer data, deterministic fault handling, and legal 4 KB burst splitting.

## Regression groups

### Basic byte transfers

- aligned and unaligned write
- aligned and unaligned read
- partial first beat
- partial last beat
- single-beat partial transfer
- 512-byte maximum transfer

### Backpressure

Deterministic stalls are applied independently to AW, W, AR, and R channels. Tests verify no payload changes while a VALID signal waits for READY and no data is lost or duplicated.

### Error and timeout

Directed tests cover BRESP error, RRESP error, early RLAST, missing RLAST, write timeout, and read timeout. Each test checks latched error code, status, and interrupt behavior.

### Deterministic random regression

Fixed seeds generate non-aligned byte addresses and byte lengths for write and readback cases. Scoreboards compare every requested byte and verify the total number of enabled `WSTRB` lanes equals the programmed length.

### 4 KB boundary

Transfers are placed before a 4 KB boundary so that one command requires multiple bursts. Every observed burst must satisfy:

```text
AxADDR[11:0] + ((AxLEN + 1) << AxSIZE) <= 4096
```

## Protocol assertions

The reusable checker verifies:

- AW/AR payload stability under stall
- W payload and WLAST stability under stall
- INCR burst type and 8-byte beat size
- no new AW or AR before the corresponding active burst completes
- W beats only after AW and R beats only after AR
- non-zero contiguous `WSTRB`
- exact WLAST and RLAST beat positions
- no burst crossing a 4 KB boundary

## Pass criteria

A pull request is eligible for merge only when the RTL Regression workflow succeeds, the PR is mergeable, review blockers are resolved, and the changes match the planned scope.