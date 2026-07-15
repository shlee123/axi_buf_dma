# AXI Buffer DMA RTL Design Guide V1

## 1. Implementation Scope

The V1 RTL implements the approved architecture baseline with one AXI4 master channel and an internal 128 x 32-bit local buffer.

Implemented features:

- AXI4 master with 32-bit address and 64-bit data.
- Local buffer external programming port.
- Buffer-to-AXI write transfer.
- AXI-to-buffer read transfer.
- Odd 32-bit word handling through `WSTRB = 8'h0F`.
- Maximum 64-beat INCR bursts.
- 4 KB boundary-aware burst planning.
- One outstanding AXI transaction.
- AXI response and `RLAST` checking.
- Parameterized AXI timeout.
- Level-triggered interrupt with sticky status and W1C clear.

## 2. Source Files

| File | Purpose |
|---|---|
| `rtl/dma_pkg.sv` | Common state and error-code definitions |
| `rtl/axi_buf_dma.sv` | DMA control, AXI master, local buffer, timeout and interrupt logic |

The first implementation keeps the control and datapath in one top-level module to simplify initial functional review. Later revisions may partition AXI read, AXI write, interrupt and buffer logic into separate modules without changing the external behavior.

## 3. Main State Machine

```text
IDLE -> CHECK -> PREP
                  |
                  +-> W_AW -> W_LOAD -> W_SEND -> W_RESP
                  |
                  +-> R_AR -> R_DATA

Terminal paths:
DONE  -> IDLE
ERROR -> IDLE
```

`dma_ready` remains asserted after the terminal state until software drives `dma_start` low.

## 4. Burst Planning

The planner selects:

```text
min(remaining beats, AXI_MAX_BURST_LEN, beats before 4 KB boundary)
```

The AXI address advances by eight bytes per completed beat. The local buffer index advances by one or two words depending on the remaining transfer length.

## 5. Local Buffer

The buffer is implemented as a synthesizable register array:

```systemverilog
logic [31:0] buffer_mem [0:127];
```

External access is permitted only while `dma_busy == 0`.

- External writes during DMA activity are ignored.
- External reads during DMA activity retain the previous registered output.
- External read latency is one clock.

The read DMA datapath may update two 32-bit words in one clock. This is suitable for a register-array implementation. An SRAM-specific wrapper may serialize the upper-word write and backpressure AXI with `RREADY` in a later integration revision.

## 6. AXI Write Datapath

`W_LOAD` captures one or two buffer words into stable output registers. `W_SEND` holds `WDATA`, `WSTRB`, and `WLAST` unchanged until `WREADY` is observed.

For an odd final word:

```text
WDATA[31:0]  = valid word
WDATA[63:32] = zero
WSTRB        = 8'h0F
```

## 7. AXI Read Datapath

The controller accepts one AXI read beat in `R_DATA`, verifies `RRESP` and `RLAST`, then writes the lower and, when required, upper 32-bit words to the local buffer.

Detected protocol errors:

- Non-OKAY `RRESP`.
- Early `RLAST`.
- Missing `RLAST` on the expected final beat.

## 8. Timeout

The timeout counter operates only when the state machine is waiting for AXI progress:

- `AWREADY`
- `WREADY`
- `BVALID`
- `ARREADY`
- `RVALID`

Any successful handshake resets the counter. Reaching `AXI_TIMEOUT_CYCLES` terminates the operation with `DMA_ERR_TIMEOUT`.

## 9. Interrupts

`irq_done_status` and `irq_error_status` are sticky. Their clear inputs use W1C-equivalent pulses. Event set has priority over clear in the same cycle.

```systemverilog
dma_irq =
    (irq_done_status  & irq_done_enable) |
    (irq_error_status & irq_error_enable);
```

## 10. Current Integration Constraints

- `dma_sa` must be 8-byte aligned.
- The AXI and local buffer interfaces use the same clock.
- No AXI IDs are exposed.
- No unaligned or narrow AXI bursts are generated.
- The internal buffer implementation is not yet technology-specific.
