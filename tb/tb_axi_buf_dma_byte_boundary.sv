`timescale 1ns/1ps

module tb_axi_buf_dma_byte_boundary;
  logic clk = 0, rst_n = 0;
  logic [31:0] dma_sa;
  logic [8:0] dma_length;
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

  integer i;
  integer timeout_count;
  integer aw_count, ar_count;
  logic [7:0] awlen_first, awlen_second;
  logic [7:0] arlen_first, arlen_second;

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

  axi_protocol_checker checker (
    .clk(clk), .rst_n(rst_n),
    .awaddr(awaddr), .awlen(awlen), .awsize(awsize), .awburst(awburst),
    .awvalid(awvalid), .awready(awready),
    .wdata(wdata), .wstrb(wstrb), .wlast(wlast), .wvalid(wvalid), .wready(wready),
    .araddr(araddr), .arlen(arlen), .arsize(arsize), .arburst(arburst),
    .arvalid(arvalid), .arready(arready),
    .rdata(rdata), .rresp(rresp), .rlast(rlast), .rvalid(rvalid), .rready(rready));

  always @(posedge clk) begin
    if (rst_n && awvalid && awready) begin
      aw_count <= aw_count + 1;
      if (aw_count == 0) awlen_first <= awlen;
      if (aw_count == 1) awlen_second <= awlen;
      if ((awaddr[11:0] + ((awlen + 1) << 3)) > 4096)
        $fatal(1, "Write burst crosses 4KB boundary");
    end
    if (rst_n && arvalid && arready) begin
      ar_count <= ar_count + 1;
      if (ar_count == 0) arlen_first <= arlen;
      if (ar_count == 1) arlen_second <= arlen;
      if ((araddr[11:0] + ((arlen + 1) << 3)) > 4096)
        $fatal(1, "Read burst crosses 4KB boundary");
    end
  end

  task automatic buffer_write(input [6:0] addr, input [31:0] data);
    begin
      @(negedge clk); buf_addr=addr; buf_din=data; buf_wr_en=1; buf_csn=0;
      @(negedge clk); buf_csn=1; buf_wr_en=0;
    end
  endtask

  task automatic wait_done;
    begin
      timeout_count = 0;
      while ((dma_ready !== 1'b1) && timeout_count < 10000) begin
        @(posedge clk); timeout_count = timeout_count + 1;
      end
      if (timeout_count >= 10000) $fatal(1, "DMA timeout");
      if (dma_error) $fatal(1, "DMA error code=%0d", dma_error_code);
      @(negedge clk); dma_start = 0;
      repeat (3) @(posedge clk);
    end
  endtask

  initial begin
    dma_sa=0; dma_length=0; dma_rw=0; dma_start=0;
    irq_done_enable=1; irq_error_enable=1; irq_done_clear=0; irq_error_clear=0;
    buf_addr=0; buf_din=0; buf_wr_en=0; buf_csn=1;
    aw_count=0; ar_count=0; awlen_first=0; awlen_second=0;
    arlen_first=0; arlen_second=0;

    repeat (5) @(posedge clk); rst_n=1;

    for (i=0; i<128; i=i+1)
      buffer_write(i[6:0], 32'hA500_0000 + i);

    @(negedge clk);
    dma_sa = 32'h0000_0FF8;
    dma_length = 9'd511;
    dma_rw = 1;
    dma_start = 1;
    wait_done();

    if (aw_count != 2) $fatal(1, "Expected 2 AW bursts, got %0d", aw_count);
    if (awlen_first != 8'd0 || awlen_second != 8'd62)
      $fatal(1, "Unexpected AWLEN sequence %0d,%0d", awlen_first, awlen_second);
    for (i=0; i<512; i=i+1)
      if (mem.mem[16'h0FF8+i] !== dut.buffer_mem[i>>2][(i&3)*8 +: 8])
        $fatal(1, "Write byte mismatch at %0d", i);

    for (i=0; i<512; i=i+1)
      mem.mem[16'h1FF8+i] = (8'h40 + i[7:0]);

    @(negedge clk);
    dma_sa = 32'h0000_1FF8;
    dma_length = 9'd511;
    dma_rw = 0;
    dma_start = 1;
    wait_done();

    if (ar_count != 2) $fatal(1, "Expected 2 AR bursts, got %0d", ar_count);
    if (arlen_first != 8'd0 || arlen_second != 8'd62)
      $fatal(1, "Unexpected ARLEN sequence %0d,%0d", arlen_first, arlen_second);
    for (i=0; i<512; i=i+1)
      if (dut.buffer_mem[i>>2][(i&3)*8 +: 8] !== (8'h40 + i[7:0]))
        $fatal(1, "Read byte mismatch at %0d", i);

    $display("512-byte 4KB boundary regression PASSED");
    $finish;
  end
endmodule
