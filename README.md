# AXI Buffer DMA

AXI Buffer DMA is a synthesizable DMA controller that transfers byte streams between a 64-bit AXI4 memory-mapped master interface and a 128 x 32-bit local buffer.

## V2 capabilities

- 32-bit AXI byte addresses
- transfer length programmed in bytes
- aligned and unaligned read/write commands
- partial first and last beats
- contiguous `WSTRB` generation
- AXI INCR burst generation
- automatic 4 KB boundary splitting
- interrupt, AXI response error, protocol error, and timeout handling
- directed backpressure and fault regression
- deterministic non-aligned random write/readback regression
- reusable AXI protocol assertions

## Repository layout

- `rtl/` - synthesizable DMA RTL
- `tb/` - testbenches, AXI memory model, and protocol checker
- `sim/` - regression makefiles and simulation flow
- `doc/architecture.md` - block architecture and transfer model
- `doc/design.md` - detailed channel and burst behavior
- `doc/verification.md` - verification strategy and pass criteria
- `doc/programmer_guide.md` - software programming sequence
- `RELEASE_NOTES.md` - V2 compatibility and release summary

## Byte-based programming model

V2 interprets the programmed address and length in bytes. Transfers may begin and end on any byte lane. Software written for the original word-based model must convert word counts to byte counts.

## Verification

GitHub Actions runs the RTL Regression workflow. A change is accepted only after regression succeeds and the pull request is mergeable without unresolved review blockers.

See the documents under `doc/` and `RELEASE_NOTES.md` for integration details.