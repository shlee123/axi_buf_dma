# Unified Simulation Flow

The repository root `Makefile` is the user-facing dispatcher. Simulator-specific behavior is implemented in `sim/Makefile`.

## Common commands

```sh
make sim
make regression
make synthesis
make gui
make verdi
make help
```

## Simulator selection

```sh
make sim SIM=iverilog TEST=byte_boundary
make sim SIM=vcs TEST=byte_addressing
```

Supported simulators are `iverilog` and `vcs`. GitHub-hosted CI executes Icarus Verilog; VCS command lines are dry-run validated because commercial licenses are not available on the hosted runner.

## FSDB waveform

```sh
make sim SIM=vcs TEST=byte_addressing FSDB=1 VERDI_HOME=/tools/verdi
```

`FSDB=1` adds the Verdi VCS PLI and `sim/fsdb_dump.sv`. The waveform path defaults to `sim/build/wave/<test>.fsdb` and can be overridden with `FSDB_FILE` when invoking `sim/Makefile` directly.

## GUI targets

`make verdi` always starts Synopsys Verdi. `make gui` is a generic dispatcher controlled by `GUI`; currently the only supported value is `GUI=verdi`.

When the selected FSDB file exists, Verdi opens source and waveform. Otherwise it opens the source and test environment only.

## Test selection

Use `TEST=<name>` for a single simulation. The default is `byte_addressing`. Run `make -C sim help` to display examples. The root `make regression` target executes the complete byte-based Icarus regression used by CI.
