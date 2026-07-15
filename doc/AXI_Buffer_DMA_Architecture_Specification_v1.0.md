# AXI Buffer DMA Architecture Specification

**Document Version:** Version 1.0  
**Date:** 2026-07-14  
**Repository:** `shlee123/axi_buf_dma`  
**Status:** Approved baseline for V1 RTL implementation

---

## 1. Purpose

This document defines the V1 architecture and behavioral specification of an AXI Buffer DMA Controller. The controller transfers data directly between an AXI4 memory space and a local 128 x 32-bit DMA buffer.

The specification is derived from the supplied `DMA_Specification.pdf`, including the local buffer interface, `DMA_LENGTH + 1` transfer count convention, DMA direction definition, and `DMA_START` / `DMA_READY` behavior.

## 2. Scope

V1 shall provide:

- One DMA channel.
- AXI4 master interface.
- 32-bit AXI address width.
- 64-bit AXI data width.
- Local buffer interface with 7-bit address and 32-bit data.
- Buffer-to-AXI write transfers.
- AXI-to-buffer read transfers.
- Interrupt generation for completion and error events.
- Timeout detection.
- AXI response error detection.
- 8-byte aligned AXI start address.
- One outstanding AXI transaction.
- INCR burst support.
- 4 KB boundary-aware burst splitting.

V1 does not include scatter-gather operation, descriptor queues, multiple DMA channels, unaligned start addresses, clock-domain crossing, or multiple outstanding transactions.

## 3. Top-Level Architecture

```text
                +---------------------------+
                |      DMA Control I/F      |
                | DMA_SA, DMA_LENGTH        |
                | DMA_RW, DMA_START         |
                | IRQ enable / clear        |
                +-------------+-------------+
                              |
                    +---------v----------+
                    | DMA Control Engine |
                    | FSM                |
                    | Address Generator  |
                    | Burst Planner      |
                    | Timeout Counter    |
                    | Error Handler      |
                    +-----+---------+----+
                          |         |
                  AXI4 M  |         | Local Buffer Port
                          |         |
                 +--------v--+   +--v----------------+
                 | AXI Master|   | 128 x 32-bit     |
                 | 32b Addr  |   | Local DMA Buffer |
                 | 64b Data  |   | / Buffer Port    |
                 +-----------+   +-------------------+
```

## 4. Clock and Reset

### 4.1 Clock

- Signal: `clk`
- All V1 control, AXI, interrupt, and local buffer logic operate in the same clock domain.
- Clock-domain crossing is outside the V1 scope.

### 4.2 Reset

- Signal: `rst_n`
- Active low.
- Synchronous reset is used in V1.
- Reset shall return the DMA FSM to `IDLE`, clear status and interrupt state, disable interrupt enables, and deassert all AXI `VALID` outputs.

## 5. DMA Programming Interface

| Signal | Direction | Width | Description |
|---|---:|---:|---|
| `dma_sa` | Input | 32 | AXI byte start address |
| `dma_length` | Input | 7 | Transfer count encoded as number of 32-bit words minus one |
| `dma_rw` | Input | 1 | `0`: AXI memory to local buffer; `1`: local buffer to AXI memory |
| `dma_start` | Input | 1 | Starts transfer when asserted after being low |
| `dma_ready` | Output | 1 | Sticky completion indication |
| `dma_busy` | Output | 1 | DMA operation in progress |
| `dma_error` | Output | 1 | Sticky error summary for the most recent operation |
| `dma_irq` | Output | 1 | Active-high level interrupt |

### 5.1 Transfer Length

```text
transfer_word_count = dma_length + 1
```

- Unit: 32-bit word.
- Minimum: 1 word.
- Maximum: 128 words.
- Maximum byte count: 512 bytes.
- Maximum 64-bit AXI beat count: 64 beats.

### 5.2 DMA Direction

```text
dma_rw = 0: AXI memory -> local buffer
dma_rw = 1: local buffer -> AXI memory
```

### 5.3 Start and Completion Handshake

1. Program `dma_sa`, `dma_length`, and `dma_rw`.
2. Drive `dma_start = 0` to clear `dma_ready`.
3. Assert `dma_start = 1`.
4. The DMA latches the programmed fields and begins the operation.
5. `dma_busy` remains high until completion or error termination.
6. `dma_ready` is set when the operation terminates, whether successful or failed.
7. Software drives `dma_start = 0` to clear `dma_ready`.

A new transfer shall only be accepted from `IDLE`. Changes to programming inputs while `dma_busy = 1` shall not affect the active transfer.

## 6. Local Buffer Interface

| Signal | Direction | Width | Description |
|---|---:|---:|---|
| `buf_addr` | Input | 7 | External buffer word address |
| `buf_din` | Input | 32 | External buffer write data |
| `buf_dout` | Output | 32 | External buffer read data |
| `buf_wr_en` | Input | 1 | `1`: write; `0`: read |
| `buf_csn` | Input | 1 | Active-low buffer chip select |

### 6.1 Buffer Organization

- Depth: 128 words.
- Width: 32 bits.
- Capacity: 512 bytes.
- Address range: `0` through `127`.
- External read data is returned one clock after a valid read request.

### 6.2 Buffer Arbitration

- When `dma_busy = 0`, the external buffer interface owns the buffer.
- When `dma_busy = 1`, the DMA engine owns the buffer.
- External buffer writes while `dma_busy = 1` shall be ignored.
- Software shall treat the local buffer as unavailable while `dma_busy = 1`.

## 7. AXI4 Master Interface

### 7.1 Parameters

| Parameter | Value |
|---|---:|
| Address width | 32 bits |
| Data width | 64 bits |
| Strobe width | 8 bits |
| Burst type | INCR |
| Maximum burst length | 64 beats |
| Outstanding transactions | 1 |
| AXI ID | Fixed zero or omitted by integration wrapper |

### 7.2 Fixed Attributes

```text
AWSIZE = 3'b011
ARSIZE = 3'b011
AWBURST = 2'b01
ARBURST = 2'b01
```

### 7.3 AXI Protocol Requirements

- Once `AWVALID`, `WVALID`, or `ARVALID` is asserted, the corresponding payload must remain stable until handshake.
- `WDATA`, `WSTRB`, and `WLAST` must remain stable while `WVALID = 1` and `WREADY = 0`.
- Every write burst must terminate with exactly one `WLAST`.
- Every read burst must terminate with exactly one expected `RLAST`.

## 8. Address Alignment

V1 requires:

```text
dma_sa[2:0] == 3'b000
```

If the address is not aligned:

- No AXI request shall be issued.
- `dma_error` shall be set.
- Alignment error status shall be recorded.
- Error interrupt status shall be set.
- `dma_ready` shall be set.
- `dma_busy` shall return low.

## 9. Data Packing and Unpacking

### 9.1 Local Buffer to AXI

```text
WDATA[31:0]  = buffer[word_index]
WDATA[63:32] = buffer[word_index + 1]
WSTRB        = 8'hFF
```

### 9.2 AXI to Local Buffer

```text
buffer[word_index]     = RDATA[31:0]
buffer[word_index + 1] = RDATA[63:32]
```

### 9.3 Odd Word Count

For an odd transfer length, the final AXI write beat uses:

```text
WDATA[31:0]  = final buffer word
WDATA[63:32] = don't care
WSTRB        = 8'h0F
```

For AXI read, only `RDATA[31:0]` is written into the final buffer location.

## 10. Burst Planning and 4 KB Boundary

Each burst length shall be:

```text
min(
    remaining_axi_beats,
    64,
    axi_beats_until_4KB_boundary
)
```

No burst may cross a 4 KB address boundary.

## 11. DMA Write Operation

Direction: local buffer to AXI memory.

1. Latch programming inputs.
2. Validate address alignment and transfer length.
3. Calculate burst length.
4. Prefetch and assemble up to two 32-bit buffer words.
5. Issue AXI write address.
6. Stream AXI write data.
7. Assert `WLAST` on the final beat.
8. Wait for `BVALID`.
9. Check `BRESP`.
10. Continue with the next burst or complete.

The datapath must buffer outgoing write data so AXI backpressure cannot alter an asserted write payload.

## 12. DMA Read Operation

Direction: AXI memory to local buffer.

1. Latch programming inputs.
2. Validate address alignment and transfer length.
3. Calculate burst length.
4. Issue AXI read address.
5. Accept each `RDATA` beat.
6. Check `RRESP`.
7. Split each 64-bit beat into one or two 32-bit buffer writes.
8. Verify `RLAST`.
9. Continue with the next burst or complete.

If only one 32-bit buffer write per clock is available, staging logic shall temporarily deassert `RREADY` as needed.

## 13. Status and Error Handling

### 13.1 Status

| Status | Behavior |
|---|---|
| `dma_busy` | High from accepted start until success or error termination |
| `dma_ready` | Sticky high after success or error; cleared by `dma_start = 0` |
| `dma_error` | Sticky summary for the latest operation; cleared when a new operation is accepted or by reset |
| `timeout_status` | Sticky indication that the operation terminated due to timeout |

### 13.2 Error Sources

- Address alignment error.
- AXI `BRESP` error.
- AXI `RRESP` error.
- Early `RLAST`.
- Missing `RLAST`.
- AXI timeout.
- Illegal FSM state.

### 13.3 Fatal Error Behavior

- Stop issuing new AXI requests.
- Safely terminate the active AXI channel.
- Set specific and summary error status.
- Set error interrupt status.
- Set `dma_ready`.
- Clear `dma_busy`.
- Return to a recoverable idle state.

## 14. Timeout

- Recommended parameter: `AXI_TIMEOUT_CYCLES = 1024`.
- Monitor prolonged waits for `AWREADY`, `WREADY`, `BVALID`, `ARREADY`, and `RVALID`.
- Reset the timeout counter whenever forward progress occurs.
- Reaching the threshold terminates the DMA with timeout error status and interrupt.

## 15. Interrupt Architecture

### 15.1 Trigger Type

- Active-high.
- Level-triggered.
- Sticky until software acknowledgement.

### 15.2 Interrupt Sources

| Bit | Name | Set Condition |
|---:|---|---|
| 0 | `irq_done_status` | DMA completed successfully |
| 1 | `irq_error_status` | DMA terminated with an error, including timeout |

### 15.3 Interrupt Enable

| Bit | Name |
|---:|---|
| 0 | `irq_done_enable` |
| 1 | `irq_error_enable` |

Reset value: zero.

### 15.4 Interrupt Output

```systemverilog
dma_irq =
    (irq_done_status  & irq_done_enable) |
    (irq_error_status & irq_error_enable);
```

### 15.5 Interrupt Clear

Status bits use write-one-to-clear semantics. Before a bus register interface is added, equivalent top-level inputs may be used:

```systemverilog
irq_done_clear
irq_error_clear
```

### 15.6 Set/Clear Priority

If set and clear occur in the same cycle, set has priority.

### 15.7 Relationship to DMA_READY

- `dma_start = 0` clears `dma_ready`.
- W1C clears interrupt status.
- The two mechanisms are independent.

## 16. Recommended FSM Partitioning

```text
IDLE
  |
  v
CHECK
  |---------------------> ERROR
  |
  +-- dma_rw = 1 --> WRITE_PREP --> AW_REQ --> W_DATA --> B_RESP
  |
  +-- dma_rw = 0 --> READ_PREP  --> AR_REQ --> R_DATA
                                      |
                                      v
                                 NEXT_BURST
                                      |
                           +----------+----------+
                           |                     |
                           v                     v
                         DONE                  ERROR
```

## 17. Reset Values

| Signal / Field | Reset Value |
|---|---:|
| `dma_ready` | 0 |
| `dma_busy` | 0 |
| `dma_error` | 0 |
| `timeout_status` | 0 |
| `irq_done_status` | 0 |
| `irq_error_status` | 0 |
| `irq_done_enable` | 0 |
| `irq_error_enable` | 0 |
| `dma_irq` | 0 |
| AXI `VALID` outputs | 0 |

## 18. Performance Target

For a 128-word transfer with no AXI backpressure:

- Data volume: 512 bytes.
- AXI beats: 64.
- Target throughput: one AXI data beat per clock after startup, subject to local buffer latency.
- Expected write latency: approximately 66 to 70 clocks for one burst.
- Read latency may be longer if the buffer accepts only one 32-bit write per clock.

## 19. Verification Requirements

The V1 verification environment shall cover:

1. One-, two-, odd-, and maximum-length AXI writes.
2. One-, odd-, and maximum-length AXI reads.
3. AXI backpressure on all channels.
4. `BRESP` and `RRESP` errors.
5. Early and missing `RLAST`.
6. Address alignment error.
7. Timeout on each monitored phase.
8. 4 KB boundary splitting.
9. Interrupt masking and W1C clearing.
10. Simultaneous interrupt set and clear.
11. External buffer access while DMA is busy.
12. Reset during idle and active operation.

Assertions shall check AXI payload stability, correct `WLAST`, expected `RLAST`, no 4 KB boundary crossing, buffer bounds, and legal FSM transitions.

## 20. V1 Limitations

- Single clock domain.
- Single DMA channel.
- One outstanding transaction.
- No scatter-gather.
- No descriptor engine.
- No linked-list operation.
- No multi-channel arbitration.
- No unaligned AXI start address.
- No byte-granular transfer length.
- No AXI narrow burst.
- No APB or AXI-Lite programming interface in the initial core.

## 21. Implementation Deliverables

```text
rtl/
  axi_buf_dma.sv
  dma_pkg.sv
  dma_control.sv
  dma_axi_write.sv
  dma_axi_read.sv
  dma_local_buffer.sv

tb/
  tb_axi_buf_dma.sv
  axi_memory_model.sv

doc/
  AXI_Buffer_DMA_Architecture_Specification_v1.0.md
  AXI_Buffer_DMA_Architecture_Specification_v1.0.docx

sim/
  Makefile
```

## 22. Approval Baseline

This document is the approved design baseline for the first RTL implementation. Any behavioral change shall be reflected in a document revision and repository change history.
