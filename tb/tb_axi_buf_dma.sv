`timescale 1ns/1ps

module tb_axi_buf_dma;

  localparam int unsigned AXI_ID_WIDTH = 6;
  localparam logic [AXI_ID_WIDTH-1:0] TEST_AXI_ID = 6'h15;

  logic clk;
  logic rst_n;
  logic [31:0] dma_sa;
  logic [8:0]  dma_length;
  logic dma_rw, dma_start, dma_ready, dma_busy, dma_error;
  logic [2:0] i_axi_prot = 3'b101;
  logic [3:0] dma_error_code;
  logic timeout_status;
  logic irq_done_enable, irq_error_enable, irq_done_clear, irq_error_clear;
  logic irq_done_status, irq_error_status, dma_irq;
  logic [6:0] buf_addr;
  logic [31:0] buf_din, buf_dout;
  logic buf_wr_en, buf_csn;

  logic [AXI_ID_WIDTH-1:0] awid, bid, arid, rid;
  logic [31:0] awaddr, araddr;
  logic [7:0] awlen, arlen;
  logic [2:0] awsize, arsize, awprot, arprot;
  logic [1:0] awburst, arburst, bresp, rresp;
  logic awvalid, awready, wlast, wvalid, wready, bvalid, bready;
  logic arvalid, arready, rlast, rvalid, rready;
  logic [63:0] wdata, rdata;
  logic [7:0] wstrb;

  axi_buf_dma #(
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXI_ID_VALUE(TEST_AXI_ID),
    .AXI_TIMEOUT_CYCLES(32)
  ) dut (
    .mbist_clk(1'b0), .mode_mbist(1'b0),
    .Test_CEN_sram(1'b1), .Test_WEN_sram(1'b1),
    .Test_A_sram('0), .Test_D_sram('0), .Test_WME_sram('0),
    .Test_Q_sram(),
    .clk, .rst_n, .dma_sa, .dma_length, .dma_rw, .dma_start,
    .i_axi_prot(i_axi_prot),
    .dma_ready, .dma_busy, .dma_error, .dma_error_code, .timeout_status,
    .irq_done_enable, .irq_error_enable, .irq_done_clear, .irq_error_clear,
    .irq_done_status, .irq_error_status, .dma_irq,
    .buf_addr, .buf_din, .buf_dout, .buf_wr_en, .buf_csn,
    .m_axi_awid(awid), .m_axi_awaddr(awaddr), .m_axi_awlen(awlen),
    .m_axi_awsize(awsize), .m_axi_awburst(awburst), .m_axi_awprot(awprot),
    .m_axi_awvalid(awvalid), .m_axi_awready(awready),
    .m_axi_wdata(wdata), .m_axi_wstrb(wstrb), .m_axi_wlast(wlast),
    .m_axi_wvalid(wvalid), .m_axi_wready(wready),
    .m_axi_bid(bid), .m_axi_bresp(bresp), .m_axi_bvalid(bvalid), .m_axi_bready(bready),
    .m_axi_arid(arid), .m_axi_araddr(araddr), .m_axi_arlen(arlen),
    .m_axi_arsize(arsize), .m_axi_arburst(arburst), .m_axi_arprot(arprot),
    .m_axi_arvalid(arvalid), .m_axi_arready(arready),
    .m_axi_rid(rid), .m_axi_rdata(rdata), .m_axi_rresp(rresp),
    .m_axi_rlast(rlast), .m_axi_rvalid(rvalid), .m_axi_rready(rready)
  );

  axi_memory_model #(.ID_WIDTH(AXI_ID_WIDTH)) mem (
    .clk, .rst_n,
    .s_axi_awid(awid), .s_axi_awaddr(awaddr), .s_axi_awlen(awlen),
    .s_axi_awsize(awsize), .s_axi_awburst(awburst), .s_axi_awprot(awprot),
    .s_axi_awvalid(awvalid), .s_axi_awready(awready),
    .s_axi_wdata(wdata), .s_axi_wstrb(wstrb), .s_axi_wlast(wlast),
    .s_axi_wvalid(wvalid), .s_axi_wready(wready),
    .s_axi_bid(bid), .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
    .s_axi_arid(arid), .s_axi_araddr(araddr), .s_axi_arlen(arlen),
    .s_axi_arsize(arsize), .s_axi_arburst(arburst), .s_axi_arprot(arprot),
    .s_axi_arvalid(arvalid), .s_axi_arready(arready),
    .s_axi_rid(rid), .s_axi_rdata(rdata), .s_axi_rresp(rresp),
    .s_axi_rlast(rlast), .s_axi_rvalid(rvalid), .s_axi_rready(rready)
  );

  always #5 clk = ~clk;

  // AXI addresses must be aligned to the current 64-bit (8-byte) data width.
  always @(posedge clk) begin
    if (rst_n && awvalid && (awaddr[2:0] != 3'b000))
      $fatal(1, "AWADDR is not 8-byte aligned: %08h", awaddr);
    if (rst_n && arvalid && (araddr[2:0] != 3'b000))
      $fatal(1, "ARADDR is not 8-byte aligned: %08h", araddr);
  end

  always @(posedge clk) begin
    if (rst_n && awvalid) begin
      if (awid !== TEST_AXI_ID)
        $fatal(1, "AWID mismatch: got %0h expected %0h", awid, TEST_AXI_ID);
      if (awprot !== i_axi_prot)
        $fatal(1, "AWPROT mismatch: got %03b expected %03b", awprot, i_axi_prot);
    end
    if (rst_n && arvalid) begin
      if (arid !== TEST_AXI_ID)
        $fatal(1, "ARID mismatch: got %0h expected %0h", arid, TEST_AXI_ID);
      if (arprot !== i_axi_prot)
        $fatal(1, "ARPROT mismatch: got %03b expected %03b", arprot, i_axi_prot);
    end
    if (rst_n && bvalid && (bid !== TEST_AXI_ID))
      $fatal(1, "BID did not echo AWID: got %0h expected %0h", bid, TEST_AXI_ID);
    if (rst_n && rvalid && (rid !== TEST_AXI_ID))
      $fatal(1, "RID did not echo ARID: got %0h expected %0h", rid, TEST_AXI_ID);
  end

  task automatic buffer_write(input logic [6:0] addr, input logic [31:0] data);
    begin
      @(negedge clk); buf_addr = addr; buf_din = data; buf_wr_en = 1'b1; buf_csn = 1'b0;
      @(negedge clk); buf_csn = 1'b1; buf_wr_en = 1'b0;
    end
  endtask

  task automatic buffer_read(input logic [6:0] addr, output logic [31:0] data);
    begin
      @(negedge clk); buf_addr = addr; buf_wr_en = 1'b0; buf_csn = 1'b0;
      @(posedge clk); #1 data = buf_dout;
      @(negedge clk); buf_csn = 1'b1;
    end
  endtask

  task automatic start_dma(
    input logic [31:0] address,
    input logic [8:0] length_m1,
    input logic direction
  );
    begin
      @(negedge clk);
      dma_start = 1'b0; dma_sa = address; dma_length = length_m1; dma_rw = direction;
      @(negedge clk);
      dma_start = 1'b1;
      wait (dma_ready === 1'b1);
      @(negedge clk);
      dma_start = 1'b0;
      wait (dma_ready === 1'b0);
    end
  endtask

  logic [31:0] rd;

  // SINGLE_LENGTH defaults to one, so every AXI request must be a single-beat burst.
  always @(posedge clk) begin
    if (rst_n && awvalid && (awlen != 8'd0))
      $fatal(1, "SINGLE_LENGTH violation: AWLEN=%0d", awlen);
    if (rst_n && arvalid && (arlen != 8'd0))
      $fatal(1, "SINGLE_LENGTH violation: ARLEN=%0d", arlen);
  end

  initial begin
    clk = 1'b0; rst_n = 1'b0;
    dma_sa = '0; dma_length = '0; dma_rw = 1'b0; dma_start = 1'b0;
    irq_done_enable = 1'b1; irq_error_enable = 1'b1;
    irq_done_clear = 1'b0; irq_error_clear = 1'b0;
    buf_addr = '0; buf_din = '0; buf_wr_en = 1'b0; buf_csn = 1'b1;

    repeat (5) @(posedge clk);
    rst_n = 1'b1;

    buffer_write(7'd0, 32'h11223344);
    buffer_write(7'd1, 32'h55667788);

    // Default SINGLE_LENGTH=1: one 8-byte write request with AWLEN=0.
    start_dma(32'h0000_0100, 9'd7, 1'b1);
    if (dma_error)
      $fatal(1, "Unexpected DMA write error code %0d", dma_error_code);

    mem.mem[16'h200] = 8'hA5;

    // One-byte read request also requires ARLEN=0.
    start_dma(32'h0000_0200, 9'd0, 1'b0);
    if (dma_error)
      $fatal(1, "Unexpected DMA read error code %0d", dma_error_code);

    $display("AXI Buffer DMA ID/PROT smoke test PASSED");
    $finish;
  end

endmodule
