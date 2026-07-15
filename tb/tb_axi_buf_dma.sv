`timescale 1ns/1ps

module tb_axi_buf_dma;

  logic clk;
  logic rst_n;

  logic [31:0] dma_sa;
  logic [6:0]  dma_length;
  logic        dma_rw;
  logic        dma_start;
  logic        dma_ready;
  logic        dma_busy;
  logic        dma_error;
  logic [3:0]  dma_error_code;
  logic        timeout_status;

  logic irq_done_enable;
  logic irq_error_enable;
  logic irq_done_clear;
  logic irq_error_clear;
  logic irq_done_status;
  logic irq_error_status;
  logic dma_irq;

  logic [6:0]  buf_addr;
  logic [31:0] buf_din;
  logic [31:0] buf_dout;
  logic        buf_wr_en;
  logic        buf_csn;

  logic [31:0] awaddr;
  logic [7:0]  awlen;
  logic [2:0]  awsize;
  logic [1:0]  awburst;
  logic        awvalid;
  logic        awready;
  logic [63:0] wdata;
  logic [7:0]  wstrb;
  logic        wlast;
  logic        wvalid;
  logic        wready;
  logic [1:0]  bresp;
  logic        bvalid;
  logic        bready;
  logic [31:0] araddr;
  logic [7:0]  arlen;
  logic [2:0]  arsize;
  logic [1:0]  arburst;
  logic        arvalid;
  logic        arready;
  logic [63:0] rdata;
  logic [1:0]  rresp;
  logic        rlast;
  logic        rvalid;
  logic        rready;

  axi_buf_dma #(
    .AXI_TIMEOUT_CYCLES(32)
  ) dut (
    .clk,
    .rst_n,
    .dma_sa,
    .dma_length,
    .dma_rw,
    .dma_start,
    .dma_ready,
    .dma_busy,
    .dma_error,
    .dma_error_code,
    .timeout_status,
    .irq_done_enable,
    .irq_error_enable,
    .irq_done_clear,
    .irq_error_clear,
    .irq_done_status,
    .irq_error_status,
    .dma_irq,
    .buf_addr,
    .buf_din,
    .buf_dout,
    .buf_wr_en,
    .buf_csn,
    .m_axi_awaddr(awaddr),
    .m_axi_awlen(awlen),
    .m_axi_awsize(awsize),
    .m_axi_awburst(awburst),
    .m_axi_awvalid(awvalid),
    .m_axi_awready(awready),
    .m_axi_wdata(wdata),
    .m_axi_wstrb(wstrb),
    .m_axi_wlast(wlast),
    .m_axi_wvalid(wvalid),
    .m_axi_wready(wready),
    .m_axi_bresp(bresp),
    .m_axi_bvalid(bvalid),
    .m_axi_bready(bready),
    .m_axi_araddr(araddr),
    .m_axi_arlen(arlen),
    .m_axi_arsize(arsize),
    .m_axi_arburst(arburst),
    .m_axi_arvalid(arvalid),
    .m_axi_arready(arready),
    .m_axi_rdata(rdata),
    .m_axi_rresp(rresp),
    .m_axi_rlast(rlast),
    .m_axi_rvalid(rvalid),
    .m_axi_rready(rready)
  );

  axi_memory_model mem (
    .clk,
    .rst_n,
    .s_axi_awaddr(awaddr),
    .s_axi_awlen(awlen),
    .s_axi_awsize(awsize),
    .s_axi_awburst(awburst),
    .s_axi_awvalid(awvalid),
    .s_axi_awready(awready),
    .s_axi_wdata(wdata),
    .s_axi_wstrb(wstrb),
    .s_axi_wlast(wlast),
    .s_axi_wvalid(wvalid),
    .s_axi_wready(wready),
    .s_axi_bresp(bresp),
    .s_axi_bvalid(bvalid),
    .s_axi_bready(bready),
    .s_axi_araddr(araddr),
    .s_axi_arlen(arlen),
    .s_axi_arsize(arsize),
    .s_axi_arburst(arburst),
    .s_axi_arvalid(arvalid),
    .s_axi_arready(arready),
    .s_axi_rdata(rdata),
    .s_axi_rresp(rresp),
    .s_axi_rlast(rlast),
    .s_axi_rvalid(rvalid),
    .s_axi_rready(rready)
  );

  always #5 clk = ~clk;

  task automatic buffer_write(input logic [6:0] addr, input logic [31:0] data);
    begin
      @(negedge clk);
      buf_addr  = addr;
      buf_din   = data;
      buf_wr_en = 1'b1;
      buf_csn   = 1'b0;
      @(negedge clk);
      buf_csn   = 1'b1;
      buf_wr_en = 1'b0;
    end
  endtask

  task automatic buffer_read(input logic [6:0] addr, output logic [31:0] data);
    begin
      @(negedge clk);
      buf_addr  = addr;
      buf_wr_en = 1'b0;
      buf_csn   = 1'b0;
      @(posedge clk);
      #1 data = buf_dout;
      @(negedge clk);
      buf_csn = 1'b1;
    end
  endtask

  task automatic start_dma(
    input logic [31:0] address,
    input logic [6:0] length_m1,
    input logic direction
  );
    begin
      @(negedge clk);
      dma_start  = 1'b0;
      dma_sa     = address;
      dma_length = length_m1;
      dma_rw     = direction;
      @(negedge clk);
      dma_start = 1'b1;
      wait (dma_ready === 1'b1);
      @(negedge clk);
      dma_start = 1'b0;
      wait (dma_ready === 1'b0);
    end
  endtask

  logic [31:0] rd;

  initial begin
    clk              = 1'b0;
    rst_n            = 1'b0;
    dma_sa           = '0;
    dma_length       = '0;
    dma_rw           = 1'b0;
    dma_start        = 1'b0;
    irq_done_enable  = 1'b1;
    irq_error_enable = 1'b1;
    irq_done_clear   = 1'b0;
    irq_error_clear  = 1'b0;
    buf_addr         = '0;
    buf_din          = '0;
    buf_wr_en        = 1'b0;
    buf_csn          = 1'b1;

    repeat (5) @(posedge clk);
    rst_n = 1'b1;

    buffer_write(7'd0, 32'h11223344);
    buffer_write(7'd1, 32'h55667788);
    buffer_write(7'd2, 32'hA5A55A5A);

    start_dma(32'h0000_0100, 7'd2, 1'b1);
    if (dma_error)
      $fatal(1, "Unexpected DMA write error code %0d", dma_error_code);

    if ({mem.mem[16'h107],mem.mem[16'h106],mem.mem[16'h105],mem.mem[16'h104],
         mem.mem[16'h103],mem.mem[16'h102],mem.mem[16'h101],mem.mem[16'h100]} !==
        64'h55667788_11223344)
      $fatal(1, "First AXI write beat mismatch");

    if ({mem.mem[16'h10B],mem.mem[16'h10A],mem.mem[16'h109],mem.mem[16'h108]} !==
        32'hA5A55A5A)
      $fatal(1, "Odd final word mismatch");

    mem.mem[16'h200] = 8'hEF;
    mem.mem[16'h201] = 8'hBE;
    mem.mem[16'h202] = 8'hAD;
    mem.mem[16'h203] = 8'hDE;
    mem.mem[16'h204] = 8'h78;
    mem.mem[16'h205] = 8'h56;
    mem.mem[16'h206] = 8'h34;
    mem.mem[16'h207] = 8'h12;

    start_dma(32'h0000_0200, 7'd1, 1'b0);
    if (dma_error)
      $fatal(1, "Unexpected DMA read error code %0d", dma_error_code);

    buffer_read(7'd0, rd);
    if (rd !== 32'hDEADBEEF)
      $fatal(1, "Buffer word 0 mismatch: %08x", rd);

    buffer_read(7'd1, rd);
    if (rd !== 32'h12345678)
      $fatal(1, "Buffer word 1 mismatch: %08x", rd);

    start_dma(32'h0000_0104, 7'd0, 1'b1);
    if (!dma_error || dma_error_code != dma_pkg::DMA_ERR_ALIGN)
      $fatal(1, "Alignment error was not reported");

    if (!irq_error_status || !dma_irq)
      $fatal(1, "Error interrupt was not asserted");

    @(negedge clk);
    irq_error_clear = 1'b1;
    @(negedge clk);
    irq_error_clear = 1'b0;

    $display("AXI Buffer DMA V1 smoke test PASSED");
    $finish;
  end

endmodule
