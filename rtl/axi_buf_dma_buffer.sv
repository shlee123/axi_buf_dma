`timescale 1ns/1ps

module axi_buf_dma_buffer #(
  parameter int unsigned ADDR_WIDTH = 7,
  parameter int unsigned DMA_DATA_WIDTH = 64
) (
  input  logic                          clk,
  input  logic                          rst_n,

  input  logic                          host_enable,
  input  logic [ADDR_WIDTH-1:0]         host_addr,
  input  logic [31:0]                   host_wdata,
  input  logic                          host_we,
  input  logic                          host_csn,
  output logic [31:0]                   host_rdata,

  input  logic [ADDR_WIDTH+1:0]         dma_read_byte_addr,
  output logic [DMA_DATA_WIDTH-1:0]     dma_read_data,

  input  logic                          dma_write_enable,
  input  logic [ADDR_WIDTH+1:0]         dma_write_byte_addr,
  input  logic [DMA_DATA_WIDTH-1:0]     dma_write_data,
  input  logic [DMA_DATA_WIDTH/8-1:0]   dma_write_strb
);

  localparam int unsigned DEPTH = 1 << ADDR_WIDTH;
  localparam int unsigned DMA_BYTES = DMA_DATA_WIDTH / 8;
  localparam int unsigned TOTAL_BYTES = DEPTH * 4;

  logic [31:0] mem [0:DEPTH-1];

  integer read_lane;
  integer read_byte_addr;
  always_comb begin
    dma_read_data = '0;
    for (read_lane = 0; read_lane < DMA_BYTES; read_lane = read_lane + 1) begin
      read_byte_addr = dma_read_byte_addr + read_lane;
      if (read_byte_addr < TOTAL_BYTES)
        dma_read_data[read_lane*8 +: 8] =
          mem[read_byte_addr >> 2][(read_byte_addr & 3)*8 +: 8];
    end
  end

  integer write_lane;
  integer write_byte_addr;
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      host_rdata <= 32'b0;
    end else begin
      if (host_enable && !host_csn && !host_we)
        host_rdata <= mem[host_addr];

      if (dma_write_enable) begin
        for (write_lane = 0; write_lane < DMA_BYTES; write_lane = write_lane + 1) begin
          write_byte_addr = dma_write_byte_addr + write_lane;
          if (dma_write_strb[write_lane] && (write_byte_addr < TOTAL_BYTES))
            mem[write_byte_addr >> 2][(write_byte_addr & 3)*8 +: 8]
              <= dma_write_data[write_lane*8 +: 8];
        end
      end else if (host_enable && !host_csn && host_we) begin
        mem[host_addr] <= host_wdata;
      end
    end
  end

endmodule
