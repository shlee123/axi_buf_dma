`timescale 1ns/1ps

module tb_axi_buf_dma_random_read;
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

  integer ar_bursts, r_beats;
  integer case_idx, i;
  integer words, expected_beats, expected_bursts;
  integer timeout_count;
  integer byte_index;
  logic [15:0] lfsr;
  logic [31:0] start_addr;
  logic [31:0] expected_word;

  always #5 clk = ~clk;

  axi_buf_dma dut (.*,
    .mbist_clk(1'b0), .mode_mbist(1'b0),
    .Test_CEN_sram(1'b1), .Test_WEN_sram(1'b1),
    .Test_A_sram('0), .Test_D_sram('0), .Test_WME_sram('0),
    .Test_Q_sram(),
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
      if (arsize !== 3'd3 || arburst !== 2'b01)
        $fatal(1, "Invalid AR attributes size=%0d burst=%0d", arsize, arburst);
      if ((araddr[11:0] + ((arlen + 1) << 3)) > 4096)
        $fatal(1, "AR burst crosses 4KB boundary addr=%h len=%0d", araddr, arlen);
      ar_bursts <= ar_bursts + 1;
    end
    if (rst_n && rvalid && rready)
      r_beats <= r_beats + 1;
  end

  task automatic buffer_read_check(input logic [6:0] addr, input logic [31:0] expected);
    begin
      @(negedge clk); buf_addr=addr; buf_wr_en=0; buf_csn=0;
      @(posedge clk); #1;
      if (buf_dout !== expected)
        $fatal(1, "Buffer mismatch case=%0d addr=%0d expected=%h got=%h",
               case_idx, addr, expected, buf_dout);
      @(negedge clk); buf_csn=1;
    end
  endtask

  function automatic integer burst_count(input integer beat_count, input integer page_beats);
    integer remaining;
    integer first_beats;
    begin
      remaining = beat_count;
      first_beats = (remaining < page_beats) ? remaining : page_beats;
      remaining = remaining - first_beats;
      burst_count = 1;
      while (remaining > 0) begin
        remaining = remaining - ((remaining > 64) ? 64 : remaining);
        burst_count = burst_count + 1;
      end
    end
  endfunction

  task automatic run_case(input logic [31:0] addr, input integer nwords);
    integer page_beats;
    begin
      rst_n=0; dma_start=0; buf_csn=1; buf_wr_en=0;
      repeat(4) @(posedge clk);
      rst_n=1; ar_bursts=0; r_beats=0;

      for (i=0; i<nwords*4; i=i+1)
        mem.mem[(addr[15:0] + i) & 16'hffff] = (8'h31 + case_idx*8'h13 + i);

      @(negedge clk);
      dma_sa = addr;
      dma_length = nwords - 1;
      dma_rw = 0;
      dma_start = 1;

      timeout_count = 0;
      while ((dma_ready !== 1'b1) && timeout_count < 4000) begin
        @(posedge clk);
        timeout_count = timeout_count + 1;
      end
      if (timeout_count >= 4000)
        $fatal(1, "Random read case %0d timeout addr=%h words=%0d", case_idx, addr, nwords);

      @(negedge clk); dma_start=0;
      repeat(3) @(posedge clk);

      expected_beats = (nwords + 1) / 2;
      page_beats = (4096 - addr[11:0]) / 8;
      expected_bursts = burst_count(expected_beats, page_beats);

      if (dma_error)
        $fatal(1, "Random read case %0d error code=%0d", case_idx, dma_error_code);
      if (r_beats != expected_beats)
        $fatal(1, "Random read case %0d expected %0d R beats, got %0d",
               case_idx, expected_beats, r_beats);
      if (ar_bursts != expected_bursts)
        $fatal(1, "Random read case %0d expected %0d AR bursts, got %0d",
               case_idx, expected_bursts, ar_bursts);

      for (i=0; i<nwords; i=i+1) begin
        byte_index = i*4;
        expected_word = {
          (8'h31 + case_idx*8'h13 + byte_index + 3),
          (8'h31 + case_idx*8'h13 + byte_index + 2),
          (8'h31 + case_idx*8'h13 + byte_index + 1),
          (8'h31 + case_idx*8'h13 + byte_index)
        };
        buffer_read_check(i[6:0], expected_word);
      end

      $display("Random read case %0d PASSED addr=%h words=%0d bursts=%0d",
               case_idx, addr, nwords, ar_bursts);
    end
  endtask

  initial begin
    dma_sa='0; dma_length='0; dma_rw=0; dma_start=0;
    irq_done_enable=1; irq_error_enable=1; irq_done_clear=0; irq_error_clear=0;
    buf_addr='0; buf_din='0; buf_wr_en=0; buf_csn=1;
    ar_bursts=0; r_beats=0; lfsr=16'h6D2B;

    for (case_idx=0; case_idx<12; case_idx=case_idx+1) begin
      lfsr = {lfsr[14:0], lfsr[15]^lfsr[13]^lfsr[12]^lfsr[10]};
      words = (lfsr[6:0] % 127) + 1;
      start_addr = 32'h0000_4000 + {17'd0, lfsr[11:3], 3'b000};
      run_case(start_addr, words);
    end

    $display("Deterministic pseudo-random DMA read regression PASSED");
    $finish;
  end
endmodule
