# Vivado batch synthesis for AXI Buffer DMA
set script_dir [file dirname [file normalize [info script]]]
set root_dir   [file normalize [file join $script_dir ..]]
set out_dir    [file join $root_dir build vivado]
file mkdir $out_dir

read_verilog -sv [file join $root_dir rtl dma_pkg.sv]
read_verilog -sv [file join $root_dir rtl axi_buf_dma_buffer.sv]
read_verilog -sv [file join $root_dir rtl axi_buf_dma.sv]

synth_design -top axi_buf_dma -part xc7a35tcpg236-1 -flatten_hierarchy rebuilt
report_utilization -file [file join $out_dir utilization.rpt]
report_timing_summary -file [file join $out_dir timing_summary.rpt]
write_checkpoint -force [file join $out_dir axi_buf_dma_synth.dcp]
