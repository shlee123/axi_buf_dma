`timescale 1ns/1ps

module tb_axi_buf_dma_read_boundary;
  logic clk = 0, rst_n = 0;
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
  integer ar_count;
  integer r_beat_count;
  integer i;

  always #5 clk = ~clk;

  axi_buf_dma dut (.*,
    .m_axi_awaddr(awaddr), .m_axi_awlen(awlen), .m_axi_awsize(awsize),
    .m_axi_awburst(awburst), .m_axi_awvalid(awvalid), .m_axi_awready(awready),
    .m_axi_wdata(wdata), .m_axi_wstrb(wstrb), .m_axi_wlast(wlast),
    .m_axi_wvalid(wvalid), .m_axi_wready(wready), .m_axi_bresp(bresp),
    .m_axi_bvalid(bvalid), .m_axi_bready(bready), .m_axi_araddr(araddr),
    .m_axi_arlen(arlen), .m_axi_arsize(arsize), .m_axi_arburst(arburst),
    .m_axi_arvalid(arvalid), .m_axi_arready(arready), .m_axi_rdata(rdata),
    .m_axi_rresp(rresp), .m_axi_rlast(rlast), .m_axi_rvalid(rvalid),
    .m_axi_rready(rready));

  axi_memory_model mem (.*,
    .s_axi_awaddr(awaddr), .s_axi_awlen(awlen), .s_axi_awsize(awsize),
    .s_axi_awburst(awburst), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
    .s_axi_wdata(wdata), .s_axi_wstrb(wstrb), .s_axi_wlast(wlast),
    .s_axi_wvalid(wvalid), .s_axi_wready(wready), .s_axi_bresp(bresp),
    .s_axi_bvalid(bvalid), .s_axi_bready(bready), .s_axi_araddr(araddr),
    .s_axi_arlen(arlen), .s_axi_arsize(arsize), .s_axi_arburst(arburst),
    .s_axi_arvalid(arvalid), .s_axi_arready(arready), .s_axi_rdata(rdata),
    .s_axi_rresp(rresp), .s_axi_rlast(rlast), .s_axi_rvalid(rvalid),
    .s_axi_rready(rready));

  always @(posedge clk) begin
    if (rst_n && arvalid && arready) begin
      if (ar_count == 0) begin
        if (araddr !== 32'h0000_0ff0 || arlen !== 8'd1)
          $fatal(1, "First AR burst mismatch addr=%h len=%0d", araddr, arlen);
      end else if (ar_count == 1) begin
        if (araddr !== 32'h0000_1000 || arlen !== 8'd61)
          $fatal(1, "Second AR burst mismatch addr=%h len=%0d", araddr, arlen);
      end else begin
        $fatal(1, "Unexpected extra AR burst");
      end
      if ((araddr[11:0] + ((arlen + 1) << 3)) > 4096)
        $fatal(1, "Read burst crosses 4KB boundary");
      ar_count <= ar_count + 1;
    end

    if (rst_n && rvalid && rready)
      r_beat_count <= r_beat_count + 1;
  end

  task automatic buffer_read_check(input logic [6:0] addr, input logic [31:0] expected);
    begin
      @(negedge clk); buf_addr=addr; buf_wr_en=0; buf_csn=0;
      @(posedge clk); #1;
      if (buf_dout !== expected)
        $fatal(1, "Buffer mismatch addr=%0d expected=%h got=%h", addr, expected, buf_dout);
      @(negedge clk); buf_csn=1;
    end
  endtask

  initial begin
    dma_sa='0; dma_length='0; dma_rw=0; dma_start=0;
    irq_done_enable=1; irq_error_enable=1; irq_done_clear=0; irq_error_clear=0;
    buf_addr='0; buf_din='0; buf_wr_en=0; buf_csn=1;
    ar_count=0; r_beat_count=0;
    repeat(5) @(posedge clk); rst_n=1;

    for (i=0; i<512; i=i+1)
      mem.mem[16'h0ff0+i] = (8'h40 + i[7:0]);

    @(negedge clk); dma_sa=32'h0000_0ff0; dma_length=7'd127; dma_rw=0; dma_start=1;
    fork
      begin wait(dma_ready === 1'b1); end
      begin repeat(2000) @(posedge clk); $fatal(1, "Maximum read transfer timeout"); end
    join_any
    disable fork;
    @(negedge clk); dma_start=0;
    repeat(3) @(posedge clk);

    if (dma_error) $fatal(1, "Unexpected DMA error code=%0d", dma_error_code);
    if (ar_count != 2) $fatal(1, "Expected 2 AR bursts, got %0d", ar_count);
    if (r_beat_count != 64) $fatal(1, "Expected 64 R beats, got %0d", r_beat_count);

    for (i=0; i<128; i=i+1)
      buffer_read_check(i[6:0], {8'h43 + ((i*4)>>8), 8'h42 + ((i*4)>>8), 8'h41 + ((i*4)>>8), 8'h40 + ((i*4)>>8)} + (32'h04040404 * (i & 8'h3f)));

    $display("Maximum-length read 4KB boundary test PASSED");
    $finish;
  end
endmodule
