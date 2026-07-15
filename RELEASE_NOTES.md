# Release Notes

## V2.0.0 - Byte-based DMA

### Highlights

- Byte-addressed AXI source and destination addressing
- Transfer length expressed in bytes
- Unaligned first and last beat support
- Contiguous `WSTRB` generation for partial writes
- Read byte extraction and local-buffer repacking
- Legal AXI INCR burst planning with 4 KB boundary splitting
- Deterministic byte-mode backpressure regression
- Directed BRESP, RRESP, RLAST, and timeout regression
- Fixed-seed non-aligned random write/readback regression
- Strengthened AXI protocol checker and boundary assertions
- Architecture, design, verification, and programmer documentation

### Compatibility

V2 changes the programmed transfer-length interpretation from words to bytes. Software written for V1 must convert word counts to byte counts before issuing V2 commands. Addresses are byte addresses and no longer require word alignment.

### Verification status

The V2 directed and deterministic-random tests are included in the GitHub Actions RTL Regression workflow. Release acceptance requires that workflow to pass on the release commit.

### Known limits

- AXI data width is 64 bits.
- Local buffer is 128 x 32 bits (512 bytes).
- AXI burst type is INCR.
- One active burst per direction is supported by the current architecture.
