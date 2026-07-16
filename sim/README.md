# Simulation environment

The simulation flow is intentionally contained under `sim/`. The repository root does not provide a Makefile.

## Entry point

Run from the repository root:

```sh
make -C sim regression
make -C sim run
make -C sim clean
```

Or enter this directory and invoke the targets directly:

```sh
cd sim
make regression
```

## Directory conventions

- `Makefile` - primary compile, run, regression, and clean targets
- `filelist/` - optional simulator file lists
- `scripts/` - simulator-specific helper scripts
- `build/` - generated executables and intermediate compilation output
- `log/` - generated simulation logs
- `wave/` - generated waveform databases

`build/`, `log/`, and `wave/` are generated work areas and are excluded from version control.
