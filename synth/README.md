# Vendor synthesis entrypoints

These scripts provide reproducible starting points for licensed-tool sign-off. They do not replace project-specific timing, library, power, or physical constraints.

## Vivado

```sh
vivado -mode batch -source synth/vivado_synth.tcl
```

The default part is `xc7a35tcpg236-1`. Override the script for the actual FPGA target before sign-off. Reports and the synthesized checkpoint are written below `build/vivado/`.

## Synopsys Design Compiler

```sh
dc_shell -f synth/dc_synth.tcl
```

Configure `target_library`, `link_library`, operating conditions, clock period, IO delays, loads, and wire-load or physical-topographical inputs in the invoking environment. Reports and netlists are written below `build/dc/`.

## Sign-off limitations

The repository CI validates generic elaboration, lint, SRAM interface integrity, and open-source synthesis. Vivado and Design Compiler execution remains pending until licensed tools and the intended technology constraints are available.
