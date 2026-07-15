# AXI Buffer DMA Byte-Length Addressing v2.0

## Requirement change

The external programming interface is updated as follows:

- `DMA_SA[31:0]` is a byte address and may be unaligned to 4-byte or 8-byte boundaries.
- `LENGTH[8:0]` represents `transfer_bytes - 1`.
- Valid transfer size is 1 through 512 bytes.
- The local buffer remains 128 x 32 bits (512 bytes).
- Local-buffer byte 0 corresponds to `buffer_mem[0][7:0]`; bytes increase in little-endian order through each 32-bit word.

## AXI mapping

The AXI master data width remains 64 bits. Each transaction uses:

- `AWSIZE/ARSIZE = 3'b011` (8 bytes per beat)
- `AWBURST/ARBURST = INCR`
- Maximum 64 beats per burst
- No burst crossing a 4 KB boundary

For an unaligned starting address:

- The first beat begins at lane `DMA_SA[2:0]`.
- Invalid leading lanes are masked with `WSTRB = 0` for writes and ignored for reads.
- Intermediate beats use all eight byte lanes.
- The final beat uses only the required trailing lanes.

Example: start address `0x1003`, length field `12` (13 bytes):

- One 2-beat burst
- First write beat `WSTRB = 8'hF8` (five bytes at lanes 3..7)
- Second write beat `WSTRB = 8'hFF` (eight bytes)

## Address and count progression

Internal progress is tracked in bytes:

- `current_addr` advances by the number of payload bytes completed in the burst.
- `remaining_bytes` starts at `LENGTH + 1`.
- `buffer_byte_index` starts at zero and advances by the valid byte count of each AXI beat.

The burst planner limits payload bytes by:

1. Remaining transfer bytes
2. Remaining bytes before the next 4 KB boundary
3. Payload capacity of the configured maximum AXI burst, accounting for the first-beat lane offset

## Verification

`tb_axi_buf_dma_byte_addressing.sv` verifies:

- 13-byte buffer-to-AXI transfer at address `0x1003`
- Correct first and last write strobes
- Exact byte values written into AXI memory
- 12-byte AXI-to-buffer transfer at address `0x2005`
- Exact byte packing into the 32-bit local buffer

Run with:

```bash
make -C sim regression
```

Legacy word-count tests are retained under:

```bash
make -C sim legacy-regression
```

They must be migrated so their programmed `LENGTH` values are expressed in bytes before being restored to the default V2 regression.
