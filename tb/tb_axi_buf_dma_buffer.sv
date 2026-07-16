`timescale 1ns/1ps

module tb_axi_buf_dma_buffer;
  localparam int ADDR_WIDTH = 3;
  localparam int DATA_WIDTH = 32;

  logic clk = 1'b0;
  logic [ADDR_WIDTH-1:0] address;
  logic wr_en;
  logic csn;
  logic [DATA_WIDTH-1:0] din;
  logic [DATA_WIDTH-1:0] dout;

  axi_buf_dma_buffer #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) dut (
    .clk(clk),
    .address(address),
    .wr_en(wr_en),
    .csn(csn),
    .din(din),
    .dout(dout)
  );

  always #5 clk = ~clk;

  task automatic write_word(input logic [ADDR_WIDTH-1:0] addr,
                            input logic [DATA_WIDTH-1:0] data);
    begin
      @(negedge clk);
      address = addr;
      din = data;
      wr_en = 1'b1;
      csn = 1'b0;
      @(posedge clk);
      #1;
      csn = 1'b1;
      wr_en = 1'b0;
    end
  endtask

  task automatic read_word(input logic [ADDR_WIDTH-1:0] addr,
                           input logic [DATA_WIDTH-1:0] expected);
    begin
      @(negedge clk);
      address = addr;
      wr_en = 1'b0;
      csn = 1'b0;
      @(posedge clk);
      #1;
      if (dout !== expected) begin
        $error("SRAM read mismatch addr=%0d expected=%08x actual=%08x", addr, expected, dout);
        $fatal(1);
      end
      csn = 1'b1;
    end
  endtask

  initial begin
    address = '0;
    wr_en = 1'b0;
    csn = 1'b1;
    din = '0;

    repeat (2) @(posedge clk);

    write_word(3'd0, 32'h1122_3344);
    write_word(3'd3, 32'hA5A5_5A5A);
    write_word(3'd7, 32'hDEAD_BEEF);

    read_word(3'd0, 32'h1122_3344);
    read_word(3'd3, 32'hA5A5_5A5A);
    read_word(3'd7, 32'hDEAD_BEEF);

    // A write cycle must not update dout; this checks write-first behavior is not implied.
    @(negedge clk);
    address = 3'd3;
    din = 32'hCAFE_BABE;
    wr_en = 1'b1;
    csn = 1'b0;
    @(posedge clk);
    #1;
    if (dout !== 32'hDEAD_BEEF) begin
      $error("dout changed during SRAM write cycle: %08x", dout);
      $fatal(1);
    end
    csn = 1'b1;
    wr_en = 1'b0;

    read_word(3'd3, 32'hCAFE_BABE);

    // csn high must hold the registered output.
    @(negedge clk);
    address = 3'd0;
    csn = 1'b1;
    repeat (2) @(posedge clk);
    #1;
    if (dout !== 32'hCAFE_BABE) begin
      $error("dout did not hold while csn was high: %08x", dout);
      $fatal(1);
    end

    $display("SRAM_WRAPPER_TEST_PASS");
    $finish;
  end
endmodule
