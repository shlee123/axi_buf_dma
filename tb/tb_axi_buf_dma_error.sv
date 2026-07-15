`timescale 1ns/1ps

module tb_axi_buf_dma_error #(
  parameter int TEST_KIND = 1
);

  localparam logic [1:0] BRESP_CFG = (TEST_KIND == 1) ? 2'b10 : 2'b00;
  localparam logic [1:0] RRESP_CFG = (TEST_KIND == 2) ? 2'b10 : 2'b00;
  localparam int RLAST_CFG = (TEST_KIND == 3) ? 1 : ((TEST_KIND == 4) ? 2 : 0);
  localparam int BDELAY_CFG = (TEST_KIND == 5) ? 64 : 0;
  localparam int RDELAY_CFG = (TEST_KIND == 6) ? 64 : 0;

  logic clk = 0;
  logic rst_n = 0;
  logic [31:0] dma_sa;
  logic [6:0] dma_length;
  logic dma_rw, dma_start, dma_ready, dma_busy, dma_error;
  logic [3:0] dma_error_code;
  logic timeout_status;
  logic irq_done_enable, irq_error_enable, irq_done_clear, irq_error_clear;
  logic irq_done_status, irq_error_status, dma_irq;
  logic [6:0] buf_addr;
  logic [31:0] buf_din, buf_dout;
  logic buf_wr_en, buf_csn;
  logic [31:0] awaddr, araddr;
  logic [7:0] awlen, arlen;
  logic [2:0] awsize, arsize;
  logic [1:0] awburst, arburst;
  logic awvalid, awready, arvalid, arready;
  logic [63:0] wdata, rdata;
  logic [7:0] wstrb;
  logic wlast, wvalid, wready;
  logic [1:0] bresp, rresp;
  logic bvalid, bready, rlast, rvalid, rready;

  always #5 clk = ~clk;

  axi_buf_dma #(.AXI_TIMEOUT_CYCLES(16)) dut (.*,
    .m_axi_awaddr(awaddr), .m_axi_awlen(awlen), .m_axi_awsize(awsize),
    .m_axi_awburst(awburst), .m_axi_awvalid(awvalid), .m_axi_awready(awready),
    .m_axi_wdata(wdata), .m_axi_wstrb(wstrb), .m_axi_wlast(wlast),
    .m_axi_wvalid(wvalid), .m_axi_wready(wready), .m_axi_bresp(bresp),
    .m_axi_bvalid(bvalid), .m_axi_bready(bready), .m_axi_araddr(araddr),
    .m_axi_arlen(arlen), .m_axi_arsize(arsize), .m_axi_arburst(arburst),
    .m_axi_arvalid(arvalid), .m_axi_arready(arready), .m_axi_rdata(rdata),
    .m_axi_rresp(rresp), .m_axi_rlast(rlast), .m_axi_rvalid(rvalid),
    .m_axi_rready(rready));

  axi_memory_model #(
    .BRESP_VALUE(BRESP_CFG), .RRESP_VALUE(RRESP_CFG), .RLAST_MODE(RLAST_CFG),
    .BVALID_DELAY(BDELAY_CFG), .RVALID_DELAY(RDELAY_CFG)
  ) mem (
    .clk, .rst_n,
    .s_axi_awaddr(awaddr), .s_axi_awlen(awlen), .s_axi_awsize(awsize),
    .s_axi_awburst(awburst), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
    .s_axi_wdata(wdata), .s_axi_wstrb(wstrb), .s_axi_wlast(wlast),
    .s_axi_wvalid(wvalid), .s_axi_wready(wready), .s_axi_bresp(bresp),
    .s_axi_bvalid(bvalid), .s_axi_bready(bready), .s_axi_araddr(araddr),
    .s_axi_arlen(arlen), .s_axi_arsize(arsize), .s_axi_arburst(arburst),
    .s_axi_arvalid(arvalid), .s_axi_arready(arready), .s_axi_rdata(rdata),
    .s_axi_rresp(rresp), .s_axi_rlast(rlast), .s_axi_rvalid(rvalid),
    .s_axi_rready(rready));

  task automatic buffer_write(input logic [6:0] addr, input logic [31:0] data);
    begin
      @(negedge clk); buf_addr=addr; buf_din=data; buf_wr_en=1; buf_csn=0;
      @(negedge clk); buf_csn=1; buf_wr_en=0;
    end
  endtask

  task automatic start_dma(input logic direction);
    begin
      @(negedge clk); dma_start=0; dma_sa=32'h100; dma_length=7'd3; dma_rw=direction;
      @(negedge clk); dma_start=1;
      fork
        begin wait(dma_ready === 1'b1); end
        begin repeat(200) @(posedge clk); $display("RESULT kind=%0d timeout_wait=1", TEST_KIND); $finish; end
      join_any
      disable fork;
      @(negedge clk); dma_start = 0;
      repeat (3) @(posedge clk);
    end
  endtask

  initial begin
    dma_sa='0; dma_length='0; dma_rw=0; dma_start=0;
    irq_done_enable=1; irq_error_enable=1; irq_done_clear=0; irq_error_clear=0;
    buf_addr='0; buf_din='0; buf_wr_en=0; buf_csn=1;
    repeat(5) @(posedge clk); rst_n=1;

    buffer_write(0,32'h11112222); buffer_write(1,32'h33334444);
    buffer_write(2,32'h55556666); buffer_write(3,32'h77778888);

    case (TEST_KIND)
      1: start_dma(1);
      2: start_dma(0);
      3: start_dma(0);
      4: start_dma(0);
      5: start_dma(1);
      6: start_dma(0);
      default: begin $display("RESULT kind=%0d unsupported=1", TEST_KIND); $finish; end
    endcase

    $display("RESULT kind=%0d error=%0b code=%0d irq=%0b dma_irq=%0b timeout=%0b",
             TEST_KIND, dma_error, dma_error_code, irq_error_status, dma_irq, timeout_status);
    $finish;
  end
endmodule
