`timescale 1ns/1ps

module tb_axi_buf_dma_normal_mode;
  logic        clk;
  logic        mbist_clk;
  logic        rst_n;
  logic [6:0]  buf_addr;
  logic [31:0] buf_din;
  wire  [31:0] buf_dout;
  logic        buf_wr_en;
  logic        buf_csn;

  logic        mode_mbist;
  logic        Test_CEN_sram;
  logic        Test_WEN_sram;
  logic [6:0]  Test_A_sram;
  logic [31:0] Test_D_sram;
  logic [31:0] Test_WME_sram;
  wire  [31:0] Test_Q_sram;

  axi_buf_dma dut (
    .clk(clk),
    .mbist_clk(mbist_clk),
    .rst_n(rst_n),
    .dma_sa(32'b0),
    .dma_length(9'b0),
    .dma_rw(1'b0),
    .dma_start(1'b0),
    .i_axi_prot(3'b0),
    .irq_done_enable(1'b0),
    .irq_error_enable(1'b0),
    .irq_done_clear(1'b0),
    .irq_error_clear(1'b0),
    .buf_addr(buf_addr),
    .buf_din(buf_din),
    .buf_dout(buf_dout),
    .buf_wr_en(buf_wr_en),
    .buf_csn(buf_csn),
    .m_axi_awready(1'b0),
    .m_axi_wready(1'b0),
    .m_axi_bid(6'b0),
    .m_axi_bresp(2'b0),
    .m_axi_bvalid(1'b0),
    .m_axi_arready(1'b0),
    .m_axi_rid(6'b0),
    .m_axi_rdata(64'b0),
    .m_axi_rresp(2'b0),
    .m_axi_rlast(1'b0),
    .m_axi_rvalid(1'b0),
    .mode_mbist(mode_mbist),
    .Test_CEN_sram(Test_CEN_sram),
    .Test_WEN_sram(Test_WEN_sram),
    .Test_A_sram(Test_A_sram),
    .Test_D_sram(Test_D_sram),
    .Test_WME_sram(Test_WME_sram),
    .Test_Q_sram(Test_Q_sram)
  );

  always #5 clk = ~clk;
  always #2 mbist_clk = ~mbist_clk;

  task automatic normal_write(
    input logic [6:0] address,
    input logic [31:0] data
  );
    begin
      @(negedge clk);
      buf_addr = address;
      buf_din = data;
      buf_wr_en = 1'b1;
      buf_csn = 1'b0;
      @(negedge clk);
      buf_wr_en = 1'b0;
      buf_csn = 1'b1;
    end
  endtask

  task automatic normal_read_check(
    input logic [6:0] address,
    input logic [31:0] expected
  );
    begin
      @(negedge clk);
      buf_addr = address;
      buf_wr_en = 1'b0;
      buf_csn = 1'b0;
      @(posedge clk);
      #1;
      if (buf_dout !== expected)
        $fatal(1, "normal-mode read mismatch: got %08h expected %08h",
               buf_dout, expected);
      if (Test_Q_sram !== expected)
        $fatal(1, "Test_Q_sram mismatch: got %08h expected %08h",
               Test_Q_sram, expected);
      @(negedge clk);
      buf_csn = 1'b1;
    end
  endtask

  initial begin
    clk = 1'b0;
    mbist_clk = 1'b0;
    rst_n = 1'b0;
    buf_addr = 7'b0;
    buf_din = 32'b0;
    buf_wr_en = 1'b0;
    buf_csn = 1'b1;

    mode_mbist = 1'b0;
    Test_CEN_sram = 1'b0;
    Test_WEN_sram = 1'b0;
    Test_A_sram = 7'h05;
    Test_D_sram = 32'hDEAD_BEEF;
    Test_WME_sram = 32'hFFFF_FFFF;

    repeat (3) @(posedge clk);
    rst_n = 1'b1;

    normal_write(7'h05, 32'h1234_5678);
    normal_read_check(7'h05, 32'h1234_5678);

    // Active MBIST pins and mbist_clk edges must not alter SRAM in normal mode.
    repeat (4) @(posedge mbist_clk);
    normal_read_check(7'h05, 32'h1234_5678);

    normal_write(7'h09, 32'hCAFE_BABE);
    normal_read_check(7'h09, 32'hCAFE_BABE);

    $display("AXI_BUF_DMA_NORMAL_MODE_TEST_PASS");
    $finish;
  end
endmodule
