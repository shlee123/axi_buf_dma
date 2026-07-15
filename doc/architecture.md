# AXI Buffer DMA V2 Architecture

## Overview

AXI Buffer DMA moves a byte stream between a 64-bit AXI4 memory-mapped master interface and a 128 x 32-bit local buffer. Version 2 uses byte addresses and byte transfer lengths. Transfers may start and end on any byte lane.

## Major blocks

- **Register interface**: programs source or destination address, byte length, direction, timeout, start, and interrupt control.
- **Command/control FSM**: validates a command, sequences write or read operation, records completion and error state, and raises the interrupt.
- **Burst planner**: converts the remaining byte count into legal AXI INCR bursts, limits burst size, and splits any transfer that would cross a 4 KB boundary.
- **Write datapath**: reads 32-bit local-buffer words, packs bytes into 64-bit AXI beats, and generates contiguous `WSTRB` values for partial first and last beats.
- **Read datapath**: accepts 64-bit AXI read beats, extracts only requested byte lanes, and writes the reconstructed byte stream into 32-bit local-buffer words.
- **Error/timeout monitor**: detects BRESP/RRESP failures, early or missing RLAST, and programmable channel timeout conditions.

## Address and length model

- AXI addresses are byte addresses.
- Programmed length is a byte count.
- A zero-byte command is not issued as an AXI transfer.
- AXI beat size is fixed at 8 bytes (`AxSIZE = 3'b011`).
- Bursts are INCR type.
- The first and last beat may be partial; intermediate beats are full-width.

## 4 KB rule

For every burst:

```text
AxADDR[11:0] + ((AxLEN + 1) << AxSIZE) <= 4096
```

The burst planner shortens a burst at the page boundary and resumes at the next 4 KB page.

## Concurrency model

The implementation supports one active write burst and one active read burst at a time. A new address phase is not accepted by the internal command sequencer until the current burst of the same direction is complete.

## Completion and error behavior

A command completes only after the final response phase for the programmed byte range. On protocol, response, or timeout error, the engine terminates the command, latches an error code and status, and raises the configured interrupt.