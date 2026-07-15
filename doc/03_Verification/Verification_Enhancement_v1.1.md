# AXI Buffer DMA Verification Enhancement v1.1

## Objective

V1.1 strengthens protocol checking and defines the next regression expansion for the AXI Buffer DMA controller.

## Added checker

`tb/axi_protocol_checker.sv` provides simulation-time checks for:

- AWVALID, ARVALID, and WVALID remaining asserted until handshake.
- Address and write payload stability during backpressure.
- Fixed 64-bit AXI beat size.
- INCR burst type.
- No AXI burst crossing a 4 KB boundary.
- WLAST placement matching AWLEN.
- No unknown read payload while the read channel is stalled.

The checker is simulator-independent procedural SystemVerilog and is compiled by the existing Icarus Verilog CI flow.

## Integration

The checker is intended to be instantiated by each testbench and connected directly to the DMA AXI master signals. It has no effect on synthesizable RTL.

## Regression matrix

The following cases are required before V1.1 verification closure:

| Group | Cases |
|---|---|
| Transfer length | 1 through 128 words |
| Direction | AXI-to-buffer and buffer-to-AXI |
| Parity | Odd and even word counts |
| Boundary | Normal address and 4 KB split address |
| Backpressure | AW, W, B, AR, and R channel stalls |
| AXI errors | BRESP and RRESP errors |
| Read framing | Early RLAST and missing RLAST |
| Timeout | AWREADY, WREADY, BVALID, ARREADY, and RVALID timeout |
| Interrupt | Enable mask, sticky status, W1C clear, simultaneous set/clear |
| Reset | Idle reset and reset during active transfer |

## Exit criteria

- All GitHub Actions jobs pass.
- No protocol checker failure.
- All directed tests pass.
- Tests cover minimum, maximum, odd, even, boundary split, timeout, and AXI error conditions.
- Any RTL change is reflected in the architecture or RTL design document.
