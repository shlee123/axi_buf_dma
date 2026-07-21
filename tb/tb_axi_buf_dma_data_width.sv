`timescale 1ns/1ps

module tb_axi_buf_dma_data_width #(
  parameter int unsigned AXI_DATA_WIDTH = 32,
  parameter bit SINGLE_LENGTH = 1'b1
);
  localparam int unsigned AXI_BYTES = AXI_DATA_WIDTH/8;
  localparam int unsigned AXI_ADDR_LSB = $clog2(AXI_BYTES);
  localparam int unsigned TEST_BYTES = 37;
  localparam logic [31:0] WRITE_BASE = 32'h0000_0103;
  localparam logic [31:0] READ_BASE  = 32'h0000_0205;

  logic clk, rst_n;
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

  logic [5:0] awid, bid, arid, rid;
  logic [31:0] awaddr, araddr;
  logic [7:0] awlen, arlen;
  logic [2:0] awsize, arsize, awprot, arprot;
  logic [1:0] awburst, arburst, bresp, rresp;
  logic awvalid, awready, wlast, wvalid, wready, bvalid, bready;
  logic arvalid, arready, rlast, rvalid, rready;
  logic [AXI_DATA_WIDTH-1:0] wdata, rdata;
  logic [AXI_BYTES-1:0] wstrb;

  integer i;
  logic [31:0] rd_word;
  logic [7:0] expected_byte;

  axi_buf_dma #(
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .SINGLE_LENGTH(SINGLE_LENGTH),
    .AXI_TIMEOUT_CYCLES(128)
  ) dut (
    .clk, .rst_n, .dma_sa, .dma_length, .dma_rw, .dma_start,
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

  axi_memory_model #(
    .DATA_WIDTH(AXI_DATA_WIDTH),
    .ID_WIDTH(6)
  ) mem (
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

  always @(posedge clk) begin
    if (rst_n && awvalid) begin
      if (awaddr[AXI_ADDR_LSB-1:0] != '0)
        $fatal(1, "AWADDR alignment failure width=%0d addr=%08h", AXI_DATA_WIDTH, awaddr);
      if (awsize != AXI_ADDR_LSB)
        $fatal(1, "AWSIZE failure width=%0d size=%0d", AXI_DATA_WIDTH, awsize);
      if (SINGLE_LENGTH && awlen != 0)
        $fatal(1, "AWLEN failure in single mode width=%0d len=%0d", AXI_DATA_WIDTH, awlen);
    end
    if (rst_n && arvalid) begin
      if (araddr[AXI_ADDR_LSB-1:0] != '0)
        $fatal(1, "ARADDR alignment failure width=%0d addr=%08h", AXI_DATA_WIDTH, araddr);
      if (arsize != AXI_ADDR_LSB)
        $fatal(1, "ARSIZE failure width=%0d size=%0d", AXI_DATA_WIDTH, arsize);
      if (SINGLE_LENGTH && arlen != 0)
        $fatal(1, "ARLEN failure in single mode width=%0d len=%0d", AXI_DATA_WIDTH, arlen);
    end
  end

  task automatic buffer_write(input integer byte_index, input logic [7:0] value);
    integer word_index;
    integer lane;
    logic [31:0] word_value;
    begin
      word_index = byte_index / 4;
      lane = byte_index % 4;
      word_value = 32'h0;
      if (lane != 0) begin
        @(negedge clk); buf_addr = word_index[6:0]; buf_wr_en = 1'b0; buf_csn = 1'b0;
        @(posedge clk); #1 word_value = buf_dout;
        @(negedge clk); buf_csn = 1'b1;
      end
      word_value[lane*8 +: 8] = value;
      @(negedge clk); buf_addr = word_index[6:0]; buf_din = word_value; buf_wr_en = 1'b1; buf_csn = 1'b0;
      @(negedge clk); buf_csn = 1'b1; buf_wr_en = 1'b0;
    end
  endtask

  task automatic buffer_read_word(input integer word_index, output logic [31:0] value);
    begin
      @(negedge clk); buf_addr = word_index[6:0]; buf_wr_en = 1'b0; buf_csn = 1'b0;
      @(posedge clk); #1 value = buf_dout;
      @(negedge clk); buf_csn = 1'b1;
    end
  endtask

  task automatic start_dma(input logic [31:0] address, input logic direction);
    begin
      @(negedge clk);
      dma_sa = address;
      dma_length = TEST_BYTES-1;
      dma_rw = direction;
      dma_start = 1'b1;
      wait (dma_ready === 1'b1);
      @(negedge clk);
      dma_start = 1'b0;
      wait (dma_ready === 1'b0);
      if (dma_error)
        $fatal(1, "DMA error width=%0d single=%0d code=%0d", AXI_DATA_WIDTH, SINGLE_LENGTH, dma_error_code);
    end
  endtask

  initial begin
    clk = 0; rst_n = 0;
    dma_sa = 0; dma_length = 0; dma_rw = 0; dma_start = 0;
    irq_done_enable = 1; irq_error_enable = 1;
    irq_done_clear = 0; irq_error_clear = 0;
    buf_addr = 0; buf_din = 0; buf_wr_en = 0; buf_csn = 1;

    repeat (5) @(posedge clk);
    rst_n = 1;

    for (i = 0; i < TEST_BYTES; i = i + 1)
      buffer_write(i, 8'h40 + i[7:0]);

    start_dma(WRITE_BASE, 1'b1);
    for (i = 0; i < TEST_BYTES; i = i + 1)
      if (mem.mem[WRITE_BASE+i] !== (8'h40 + i[7:0]))
        $fatal(1, "Write mismatch width=%0d single=%0d byte=%0d got=%02h exp=%02h",
               AXI_DATA_WIDTH, SINGLE_LENGTH, i, mem.mem[WRITE_BASE+i], 8'h40+i[7:0]);

    for (i = 0; i < TEST_BYTES; i = i + 1)
      mem.mem[READ_BASE+i] = 8'hA0 ^ i[7:0];

    start_dma(READ_BASE, 1'b0);
    for (i = 0; i < TEST_BYTES; i = i + 1) begin
      buffer_read_word(i/4, rd_word);
      expected_byte = 8'hA0 ^ i[7:0];
      if (rd_word[(i%4)*8 +: 8] !== expected_byte)
        $fatal(1, "Read mismatch width=%0d single=%0d byte=%0d got=%02h exp=%02h",
               AXI_DATA_WIDTH, SINGLE_LENGTH, i, rd_word[(i%4)*8 +: 8], expected_byte);
    end

    $display("M6 data-width regression PASSED width=%0d single=%0d", AXI_DATA_WIDTH, SINGLE_LENGTH);
    $finish;
  end
endmodule
