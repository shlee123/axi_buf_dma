# AXI Buffer DMA V2 Programmer Guide

## Programming model

The DMA command consists of a byte address, a byte length, a direction, timeout control, interrupt enable, and a start request. Register names and offsets are defined by the RTL register block; software must use the repository's current register definitions as the source of truth.

## Required sequence

1. Confirm the engine is idle.
2. Clear stale done, error, timeout, and interrupt status.
3. Program the AXI byte address.
4. Program the transfer length in bytes.
5. Select local-buffer-to-AXI write or AXI-to-local-buffer read.
6. Program timeout and interrupt policy.
7. Issue start.
8. Poll status or wait for interrupt.
9. On completion, check error and timeout status before using the transferred data.

## Address and length rules

- Address units are bytes.
- Length units are bytes.
- Unaligned addresses are supported.
- Length does not need to be a multiple of 4 or 8.
- Software should not issue a zero-byte command.
- One command may be split into several AXI bursts, including at 4 KB boundaries.

## Local buffer

The local buffer is 128 x 32 bits (512 bytes). Software must keep the requested transfer within the implemented local-buffer capacity and must not modify buffer locations participating in an active command.

## Completion and interrupts

Done indicates that the complete byte range and its final AXI response have completed. Error or timeout status indicates that the command did not complete normally. When interrupts are enabled, software should read status, service the result, clear the latched condition, and only then start the next command.

## Error recovery

After BRESP, RRESP, RLAST, or timeout failure:

1. Record status and error code.
2. Clear the interrupt and error indication.
3. Verify that the target memory and local-buffer contents are still valid for retry.
4. Reprogram the full command and restart; partial progress is not a software-visible completion guarantee.