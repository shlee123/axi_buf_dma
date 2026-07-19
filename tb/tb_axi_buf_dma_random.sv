`timescale 1ns/1ps

module tb_axi_buf_dma_random;
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

  localparam int NUM_CASES = 16;

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

  integer w_beats, aw_bursts;
  integer case_idx, i, nwords, expected_beats, timeout_count;
  logic [15:0] lfsr;
  logic [31:0] start_addr;

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
    if (rst_n && awvalid && awready) begin
      aw_bursts <= aw_bursts + 1;
      if (awsize !== 3'd3 || awburst !== 2'b01)
        $fatal(1, "Illegal AW attributes size=%0d burst=%0d", awsize, awburst);
      if ((awaddr[11:0] + ((awlen + 1) << 3)) > 4096)
        $fatal(1, "AW burst crosses 4KB boundary addr=%h len=%0d", awaddr, awlen);
    end
    if (rst_n && wvalid && wready)
      w_beats <= w_beats + 1;
  end

  task automatic buffer_write(input logic [6:0] addr, input logic [31:0] data);
    begin
      @(negedge clk); buf_addr=addr; buf_din=data; buf_wr_en=1; buf_csn=0;
      @(negedge clk); buf_csn=1; buf_wr_en=0;
    end
  endtask

  task automatic run_case(input integer words, input logic [31:0] addr);
    begin
      rst_n=0; dma_start=0; buf_csn=1; buf_wr_en=0;
      repeat(4) @(posedge clk);
      rst_n=1; w_beats=0; aw_bursts=0;

      for (i=0; i<words; i=i+1)
        buffer_write(i[6:0], 32'hC000_0000 ^ (case_idx << 16) ^ i);

      @(negedge clk);
      dma_sa=addr; dma_length=words-1; dma_rw=1; dma_start=1;
      timeout_count=0;
      while ((dma_ready !== 1'b1) && timeout_count < 4000) begin
        @(posedge clk); timeout_count=timeout_count+1;
      end
      if (timeout_count >= 4000)
        $fatal(1, "Random case %0d timeout words=%0d addr=%h", case_idx, words, addr);
      @(negedge clk); dma_start=0;
      repeat(3) @(posedge clk);

      expected_beats=(words+1)/2;
      if (dma_error)
        $fatal(1, "Random case %0d error=%0d words=%0d addr=%h", case_idx, dma_error_code, words, addr);
      if (w_beats != expected_beats)
        $fatal(1, "Random case %0d expected %0d beats got %0d", case_idx, expected_beats, w_beats);
      if (aw_bursts < 1 || aw_bursts > 2)
        $fatal(1, "Random case %0d unexpected AW burst count=%0d", case_idx, aw_bursts);
      $display("Random case %0d PASSED words=%0d addr=%h bursts=%0d", case_idx, words, addr, aw_bursts);
    end
  endtask

  initial begin
    dma_sa='0; dma_length='0; dma_rw=0; dma_start=0;
    irq_done_enable=1; irq_error_enable=1; irq_done_clear=0; irq_error_clear=0;
    buf_addr='0; buf_din='0; buf_wr_en=0; buf_csn=1;
    w_beats=0; aw_bursts=0; lfsr=16'h1ACE;

    for (case_idx=0; case_idx<NUM_CASES; case_idx=case_idx+1) begin
      lfsr = {lfsr[14:0], lfsr[15]^lfsr[13]^lfsr[12]^lfsr[10]};
      nwords = (lfsr[6:0] == 0) ? 1 : lfsr[6:0];
      start_addr = {20'h00002, lfsr[11:3], 3'b000};
      run_case(nwords, start_addr);
    end

    $display("Deterministic pseudo-random DMA regression PASSED");
    $finish;
  end
endmodule
