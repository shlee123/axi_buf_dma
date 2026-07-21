`timescale 1ns/1ps

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

  localparam int unsigned DEPTH = 1 << ADDR_WIDTH;

  logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

  always @(posedge clk) begin
    if (!csn) begin
      if (wr_en)
        mem[address] <= din;
      else
        dout <= mem[address];
    end
  end

endmodule
