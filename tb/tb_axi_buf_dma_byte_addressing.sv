`timescale 1ns/1ps

module tb_axi_buf_dma_byte_addressing;
  // AXI ID/PROT wildcard compatibility signals
  logic [5:0] m_axi_awid, m_axi_bid, m_axi_arid, m_axi_rid;
  logic [2:0] m_axi_awprot, m_axi_arprot;
  logic [5:0] s_axi_awid, s_axi_bid, s_axi_arid, s_axi_rid;
  logic [2:0] s_axi_awprot, s_axi_arprot;
  assign s_axi_awid = m_axi_awid;
  assign s_axi_awprot = m_axi_awprot;
  assign m_axi_bid = s_axi_bid;
  assign s_axi_arid = m_axi_arid;
  assign s_axi_arprot = m_axi_arprot;
  assign m_axi_rid = s_axi_rid;

  logic clk = 0;
  logic rst_n = 0;
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
  integer aw_count;
  integer ar_count;
  logic [7:0] first_wstrb;
  logic [7:0] last_wstrb;

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
    if (rst_n && awvalid && awready)
      aw_count <= aw_count + 1;
    if (rst_n && arvalid && arready)
      ar_count <= ar_count + 1;
    if (rst_n && wvalid && wready) begin
      if (first_wstrb == 0)
        first_wstrb <= wstrb;
      if (wlast)
        last_wstrb <= wstrb;
    end
  end

  task automatic buffer_write(input [6:0] addr, input [31:0] data);
    begin
      @(negedge clk);
      buf_addr = addr;
      buf_din = data;
      buf_wr_en = 1;
      buf_csn = 0;
      @(negedge clk);
      buf_csn = 1;
      buf_wr_en = 0;
    end
  endtask

  task automatic wait_done;
    begin
      timeout_count = 0;
      while ((dma_ready !== 1'b1) && timeout_count < 3000) begin
        @(posedge clk);
        timeout_count = timeout_count + 1;
      end
      if (timeout_count >= 3000)
        $fatal(1, "DMA timeout");
      if (dma_error)
        $fatal(1, "DMA error code=%0d", dma_error_code);
      @(negedge clk);
      dma_start = 0;
      repeat (3) @(posedge clk);
    end
  endtask

  initial begin
    dma_sa = 0;
    dma_length = 0;
    dma_rw = 0;
    dma_start = 0;
    irq_done_enable = 1;
    irq_error_enable = 1;
    irq_done_clear = 0;
    irq_error_clear = 0;
    buf_addr = 0;
    buf_din = 0;
    buf_wr_en = 0;
    buf_csn = 1;
    aw_count = 0;
    ar_count = 0;
    first_wstrb = 0;
    last_wstrb = 0;

    repeat (5) @(posedge clk);
    rst_n = 1;

    // Write 13 bytes from buffer byte 0 to unaligned AXI address 0x1003.
    buffer_write(0, 32'h0302_0100);
    buffer_write(1, 32'h0706_0504);
    buffer_write(2, 32'h0B0A_0908);
    buffer_write(3, 32'h0000_000C);

    @(negedge clk);
    dma_sa = 32'h0000_1003;
    dma_length = 9'd12; // 13 bytes
    dma_rw = 1;
    dma_start = 1;
    wait_done();

    if (aw_count != 1)
      $fatal(1, "Expected one AW burst, got %0d", aw_count);
    if (first_wstrb != 8'hF8)
      $fatal(1, "Expected first WSTRB=F8, got %02h", first_wstrb);
    if (last_wstrb != 8'hFF)
      $fatal(1, "Expected last WSTRB=FF, got %02h", last_wstrb);
    for (i = 0; i < 13; i = i + 1)
      if (mem.mem[16'h1003 + i] !== i[7:0])
        $fatal(1, "Write byte mismatch index=%0d got=%02h", i, mem.mem[16'h1003+i]);

    // Read 12 bytes from unaligned AXI address 0x2005 into buffer byte 0.
    for (i = 0; i < 12; i = i + 1)
      mem.mem[16'h2005 + i] = 8'h80 + i[7:0];

    @(negedge clk);
    dma_sa = 32'h0000_2005;
    dma_length = 9'd11; // 12 bytes
    dma_rw = 0;
    dma_start = 1;
    wait_done();

    if (ar_count != 1)
      $fatal(1, "Expected one AR burst, got %0d", ar_count);
    for (i = 0; i < 12; i = i + 1)
      if (dut.u_local_buffer.mem[i>>2][(i&3)*8 +: 8] !== (8'h80 + i[7:0]))
        $fatal(1, "Read byte mismatch index=%0d", i);

    $display("Byte-length and byte-aligned DMA regression PASSED");
    $finish;
  end
endmodule
