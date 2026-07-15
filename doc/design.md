# AXI Buffer DMA V2 Design

## Command lifecycle

1. Software programs address, byte length, direction, timeout, and interrupt enable.
2. A start write snapshots the command when the engine is idle.
3. The burst planner calculates the next legal burst from the current byte address and remaining byte count.
4. The datapath transfers the burst while honoring AXI backpressure.
5. The engine advances the byte address and remaining count after the burst completes.
6. The engine reports done after the final response, or reports error on a detected fault.

## Write path

The write path aligns the requested byte stream to the AXI address offset. `WSTRB` identifies valid lanes. Legal strobes are non-zero and contiguous. The first and last beats can be partial; a single-beat transfer can be partial at both ends. `WLAST` is asserted exactly on beat `AWLEN`.

Write channel payload and control remain stable while `WVALID` is asserted and `WREADY` is low. Address channel payload remains stable while `AWVALID` is asserted and `AWREADY` is low.

## Read path

The read path issues an aligned sequence of 64-bit beats covering the requested byte range, extracts requested lanes, and packs the byte stream into the local buffer. `RLAST` must occur exactly on beat `ARLEN`. Early or missing `RLAST` is a command error.

Read address payload remains stable while `ARVALID` is asserted and `ARREADY` is low. Incoming read payload is consumed only on `RVALID && RREADY`.

## Burst planning

The next burst size is the minimum of:

- remaining transfer bytes rounded to required AXI beats;
- configured maximum burst beats;
- beats available before the next 4 KB boundary.

`AWLEN` and `ARLEN` encode beats minus one. `AxBURST` is INCR and `AxSIZE` is fixed to 8 bytes.

## Error classes

- AXI write response error (`BRESP` not OKAY)
- AXI read response error (`RRESP` not OKAY)
- early `RLAST`
- missing `RLAST`
- write-channel timeout
- read-channel timeout

The error path latches status and error code, terminates the active command, and requests an interrupt when enabled.

## Reset

Reset clears active command state, outstanding burst state, beat counters, completion, error, timeout status, and interrupt state. No AXI valid signal remains asserted after reset handling completes.