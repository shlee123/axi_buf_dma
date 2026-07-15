# AXI Error Injection and Timeout Controls v1.3

## Purpose

The AXI memory model supports deterministic error and latency injection so the DMA error paths can be verified in CI.

## Parameters

| Parameter | Default | Description |
|---|---:|---|
| `BRESP_VALUE` | `2'b00` | Write response returned for each completed burst |
| `RRESP_VALUE` | `2'b00` | Read response returned for each read beat |
| `RLAST_MODE` | `0` | `0`: normal, `1`: early RLAST, `2`: missing RLAST |
| `BVALID_DELAY` | `0` | Cycles between final W beat and BVALID assertion |
| `RVALID_DELAY` | `0` | Cycles between AR handshake and first RVALID |

Existing backpressure controls remain available and may be combined with these parameters.

## Planned directed tests

1. `BRESP_VALUE = SLVERR`: expect `DMA_ERR_BRESP`.
2. `RRESP_VALUE = SLVERR`: expect `DMA_ERR_RRESP`.
3. `RLAST_MODE = 1`: expect early-RLAST error.
4. `RLAST_MODE = 2`: expect missing-RLAST error.
5. `BVALID_DELAY` greater than the DMA timeout threshold: expect timeout.
6. `RVALID_DELAY` greater than the DMA timeout threshold: expect timeout.

## Determinism

All injected behaviors are parameter-driven and deterministic. This makes failures reproducible locally and in GitHub Actions.

## Default compatibility

All error and delay parameters default to normal AXI behavior. The existing smoke and backpressure regression must therefore continue to pass without testbench changes.
