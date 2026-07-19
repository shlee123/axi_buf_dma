`timescale 1ns/1ps

module tb_axi_buf_dma_byte_random;
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

  localparam int DEFAULT_NUM_CASES = 16;

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

  integer case_idx, i;
  integer transfer_bytes;
  integer timeout_count;
  integer aw_bursts, ar_bursts;
  integer w_payload_bytes;
  integer runtime_cases;
  integer seed_arg;
  logic [15:0] lfsr;
  logic [31:0] start_addr;
  logic [7:0] expected_byte;

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
        $fatal(1, "case=%0d invalid AW attributes", case_idx);
      if (({1'b0, awaddr[11:3], 3'b000} + ((awlen + 1) << 3)) > 4096)
        $fatal(1, "case=%0d AW burst crosses 4KB boundary", case_idx);
    end
    if (rst_n && arvalid && arready) begin
      ar_bursts <= ar_bursts + 1;
      if (arsize !== 3'd3 || arburst !== 2'b01)
        $fatal(1, "case=%0d invalid AR attributes", case_idx);
      if (({1'b0, araddr[11:3], 3'b000} + ((arlen + 1) << 3)) > 4096)
        $fatal(1, "case=%0d AR burst crosses 4KB boundary", case_idx);
    end
    if (rst_n && wvalid && wready)
      w_payload_bytes <= w_payload_bytes + $countones(wstrb);
  end

  function automatic [7:0] pattern_byte(input integer c, input integer index);
    pattern_byte = (8'h35 + c*8'h17 + index*8'h0B) & 8'hff;
  endfunction

  task automatic buffer_write(input logic [6:0] addr, input logic [31:0] data);
    begin
      @(negedge clk); buf_addr=addr; buf_din=data; buf_wr_en=1; buf_csn=0;
      @(negedge clk); buf_csn=1; buf_wr_en=0;
    end
  endtask

  task automatic wait_done;
    begin
      timeout_count = 0;
      while ((dma_ready !== 1'b1) && timeout_count < 12000) begin
        @(posedge clk); timeout_count = timeout_count + 1;
      end
      if (timeout_count >= 12000)
        $fatal(1, "case=%0d DMA timeout addr=%h bytes=%0d", case_idx, start_addr, transfer_bytes);
      if (dma_error || timeout_status)
        $fatal(1, "case=%0d DMA error code=%0d timeout=%0b", case_idx, dma_error_code, timeout_status);
      @(negedge clk); dma_start=0;
      repeat (3) @(posedge clk);
    end
  endtask

  task automatic run_case(input logic [31:0] addr, input integer nbytes);
    integer word_idx;
    integer byte_idx;
    logic [31:0] word_data;
    begin
      rst_n=0; dma_start=0; buf_csn=1; buf_wr_en=0;
      repeat(4) @(posedge clk);
      rst_n=1;
      aw_bursts=0; ar_bursts=0; w_payload_bytes=0;

      for (word_idx=0; word_idx<128; word_idx=word_idx+1) begin
        word_data = '0;
        for (byte_idx=0; byte_idx<4; byte_idx=byte_idx+1)
          word_data[byte_idx*8 +: 8] = pattern_byte(case_idx, word_idx*4+byte_idx);
        buffer_write(word_idx[6:0], word_data);
      end

      @(negedge clk);
      dma_sa=addr; dma_length=nbytes-1; dma_rw=1; dma_start=1;
      wait_done();

      if (w_payload_bytes != nbytes)
        $fatal(1, "case=%0d expected %0d write bytes, got %0d", case_idx, nbytes, w_payload_bytes);
      if (aw_bursts < 1)
        $fatal(1, "case=%0d missing AW burst", case_idx);
      for (i=0; i<nbytes; i=i+1) begin
        expected_byte = pattern_byte(case_idx, i);
        if (mem.mem[(addr[15:0]+i) & 16'hffff] !== expected_byte)
          $fatal(1, "case=%0d write mismatch index=%0d expected=%02h got=%02h",
                 case_idx, i, expected_byte, mem.mem[(addr[15:0]+i) & 16'hffff]);
      end

      for (i=0; i<nbytes; i=i+1)
        mem.mem[(addr[15:0]+i) & 16'hffff] = pattern_byte(case_idx+19, i);

      @(negedge clk);
      dma_sa=addr; dma_length=nbytes-1; dma_rw=0; dma_start=1;
      wait_done();

      if (ar_bursts < 1)
        $fatal(1, "case=%0d missing AR burst", case_idx);
      for (i=0; i<nbytes; i=i+1) begin
        expected_byte = pattern_byte(case_idx+19, i);
        if (dut.u_local_buffer.mem[i>>2][(i&3)*8 +: 8] !== expected_byte)
          $fatal(1, "case=%0d read mismatch index=%0d expected=%02h got=%02h",
                 case_idx, i, expected_byte, dut.u_local_buffer.mem[i>>2][(i&3)*8 +: 8]);
      end

      $display("Byte random case %0d PASSED addr=%h bytes=%0d AW=%0d AR=%0d",
               case_idx, addr, nbytes, aw_bursts, ar_bursts);
    end
  endtask

  initial begin
    dma_sa='0; dma_length='0; dma_rw=0; dma_start=0;
    irq_done_enable=1; irq_error_enable=1; irq_done_clear=0; irq_error_clear=0;
    buf_addr='0; buf_din='0; buf_wr_en=0; buf_csn=1;
    aw_bursts=0; ar_bursts=0; w_payload_bytes=0;
    runtime_cases = DEFAULT_NUM_CASES;
    seed_arg = 16'hB4D3;
    if (!$value$plusargs("RANDOM_CASES=%d", runtime_cases))
      runtime_cases = DEFAULT_NUM_CASES;
    if (!$value$plusargs("RANDOM_SEED=%h", seed_arg))
      seed_arg = 16'hB4D3;
    if ((runtime_cases < 1) || (runtime_cases > 256))
      $fatal(1, "RANDOM_CASES must be in the range 1..256, got %0d", runtime_cases);
    lfsr = seed_arg[15:0];
    if (lfsr == 16'h0000)
      $fatal(1, "RANDOM_SEED must be non-zero");

    $display("Byte random regression seed=%04h cases=%0d", lfsr, runtime_cases);
    for (case_idx=0; case_idx<runtime_cases; case_idx=case_idx+1) begin
      lfsr = {lfsr[14:0], lfsr[15]^lfsr[13]^lfsr[12]^lfsr[10]};
      transfer_bytes = (lfsr[8:0] % 512) + 1;
      start_addr = 32'h0000_3000 + {17'd0, lfsr[11:0]};
      run_case(start_addr, transfer_bytes);
    end

    $display("Deterministic byte-address random write/read regression PASSED seed=%04h cases=%0d", seed_arg[15:0], runtime_cases);
    $finish;
  end
endmodule
