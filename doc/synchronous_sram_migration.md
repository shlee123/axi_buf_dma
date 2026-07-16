# Synchronous SRAM Migration

## Target memory boundary

`axi_buf_dma_buffer` will expose only a conventional single-port synchronous memory interface:

```systemverilog
module axi_buf_dma_buffer #(
  parameter int unsigned ADDR_WIDTH = 7,
  parameter int unsigned DATA_WIDTH = 32
) (
  input  logic                  clk,
  input  logic [ADDR_WIDTH-1:0] address,
  input  logic                  wr_en,
  input  logic                  csn,
  input  logic [DATA_WIDTH-1:0] din,
  output logic [DATA_WIDTH-1:0] dout
);
```

Read data is registered and becomes available after the active clock edge for which `csn` is asserted low and `wr_en` is low. The module contains no DMA-specific, host-specific, byte-address, arbitration, or byte-enable behavior.

## Controller responsibilities

The DMA controller owns:

- host/DMA arbitration
- word-address generation
- synchronous-read request and wait states
- assembly of 32-bit SRAM words into 64-bit AXI write beats
- splitting of AXI read beats into 32-bit SRAM words
- preservation of unwritten bytes through read-modify-write when a final word is partial
- suppression of host accesses while DMA is busy

## Required FSM behavior

### Local buffer to AXI

1. Issue a synchronous SRAM read for the word containing the next payload byte.
2. Wait one cycle for `dout`.
3. Copy the required bytes into a 64-bit staging register.
4. Repeat until the current AXI beat is complete.
5. Assert `WVALID` with the assembled `WDATA/WSTRB`.

### AXI to local buffer

1. Latch each accepted AXI read beat.
2. Accumulate sequential bytes into a 32-bit word staging register.
3. Write complete words directly to SRAM.
4. For a final partial word, read the existing word, merge valid bytes, then write the merged word.

## Acceptance criteria

- `axi_buf_dma_buffer` has exactly `clk`, `address`, `wr_en`, `csn`, `din`, and `dout` ports, plus width parameters.
- No combinational memory read exists.
- No byte enables exist in the memory module.
- The full byte-addressed regression remains passing.
- Synthesis Check remains passing.
- Host read timing is documented as synchronous.
- The wrapper can be replaced by a foundry SRAM macro without changing DMA datapath behavior.
