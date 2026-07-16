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

## Buffer data lifetime rule

Each DMA transfer owns the local-buffer words that it uses. Data left in unused byte lanes of the first or final 32-bit word does not need to be preserved and is treated as don't-care.

Consequences:

- no read-modify-write is required for a partial final word
- no byte-write-enable interface is required
- a partial word may be written as a complete 32-bit word with unused byte lanes filled with zero or any deterministic implementation value
- later software or DMA operations must only consume the byte count programmed for that transfer

## Controller responsibilities

The DMA controller owns:

- host/DMA arbitration
- word-address generation
- synchronous-read request and wait states
- assembly of 32-bit SRAM words into 64-bit AXI write beats
- splitting of AXI read beats into 32-bit SRAM words
- construction of a complete 32-bit write word for a partial final payload word without preserving old SRAM contents
- suppression of host accesses while DMA is busy

## Required FSM behavior

### Local buffer to AXI

1. Issue a synchronous SRAM read for the word containing the next payload byte.
2. Wait one cycle for `dout`.
3. Copy the required bytes into a 64-bit staging register.
4. Repeat until the current AXI beat is complete.
5. Assert `WVALID` with the assembled `WDATA/WSTRB`.

Only the programmed transfer length is valid. Bytes read from SRAM beyond the final payload byte are ignored.

### AXI to local buffer

1. Latch each accepted AXI read beat.
2. Accumulate sequential payload bytes into a 32-bit word staging register.
3. Write complete words directly to SRAM.
4. For a final partial word, fill unused byte lanes with a deterministic value, preferably zero, and perform one normal 32-bit SRAM write.

No existing SRAM data is read or merged for a partial final word.

## Acceptance criteria

- `axi_buf_dma_buffer` has exactly `clk`, `address`, `wr_en`, `csn`, `din`, and `dout` ports, plus width parameters.
- No combinational memory read exists.
- No byte enables exist in the memory module.
- No read-modify-write operation is used for partial words.
- Unused byte lanes of a partial word are documented as don't-care and preferably written as zero.
- The full byte-addressed regression remains passing.
- Synthesis Check remains passing.
- Host read timing is documented as synchronous.
- The wrapper can be replaced by a foundry SRAM macro without changing DMA datapath behavior.
