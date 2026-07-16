# Synopsys Design Compiler batch synthesis for AXI Buffer DMA
set script_dir [file dirname [file normalize [info script]]]
set root_dir   [file normalize [file join $script_dir ..]]
set out_dir    [file join $root_dir build dc]
file mkdir $out_dir

set_app_var search_path [list [file join $root_dir rtl] $search_path]
analyze -format sverilog [list \
  [file join $root_dir rtl dma_pkg.sv] \
  [file join $root_dir rtl axi_buf_dma_buffer.sv] \
  [file join $root_dir rtl axi_buf_dma.sv]]
elaborate axi_buf_dma
current_design axi_buf_dma
link

# Technology libraries and operating conditions must be supplied by the user environment.
if {[sizeof_collection [get_ports clk -quiet]] > 0} {
  create_clock -name clk -period 10.000 [get_ports clk]
}
set_fix_multiple_port_nets -all -buffer_constants
check_design > [file join $out_dir check_design.rpt]
compile_ultra

write -format ddc -hierarchy -output [file join $out_dir axi_buf_dma.ddc]
write -format verilog -hierarchy -output [file join $out_dir axi_buf_dma_netlist.v]
report_qor > [file join $out_dir qor.rpt]
report_area > [file join $out_dir area.rpt]
report_timing -max_paths 20 > [file join $out_dir timing.rpt]
