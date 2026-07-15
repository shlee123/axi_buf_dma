`timescale 1ns/1ps

module axi_memory_model #(
  parameter int unsigned ADDR_WIDTH = 32,
  parameter int unsigned DATA_WIDTH = 64,
  parameter int unsigned MEM_BYTES  = 65536
) (
  input  logic                  clk,
  input  logic                  rst_n,

  input  logic [ADDR_WIDTH-1:0] s_axi_awaddr,
  input  logic [7:0]            s_axi_awlen,
  input  logic [2:0]            s_axi_awsize,
  input  logic [1:0]            s_axi_awburst,
  input  logic                  s_axi_awvalid,
  output logic                  s_axi_awready,

  input  logic [DATA_WIDTH-1:0] s_axi_wdata,
  input  logic [DATA_WIDTH/8-1:0] s_axi_wstrb,
  input  logic                  s_axi_wlast,
  input  logic                  s_axi_wvalid,
  output logic                  s_axi_wready,

  output logic [1:0]            s_axi_bresp,
  output logic                  s_axi_bvalid,
  input  logic                  s_axi_bready,

  input  logic [ADDR_WIDTH-1:0] s_axi_araddr,
  input  logic [7:0]            s_axi_arlen,
  input  logic [2:0]            s_axi_arsize,
  input  logic [1:0]            s_axi_arburst,
  input  logic                  s_axi_arvalid,
  output logic                  s_axi_arready,

  output logic [DATA_WIDTH-1:0] s_axi_rdata,
  output logic [1:0]            s_axi_rresp,
  output logic                  s_axi_rlast,
  output logic                  s_axi_rvalid,
  input  logic                  s_axi_rready
);

  logic [7:0] mem [0:MEM_BYTES-1];
  logic [ADDR_WIDTH-1:0] write_addr;
  logic [7:0] write_beats_left;
  logic write_active;

  logic [ADDR_WIDTH-1:0] read_addr;
  logic [7:0] read_beats_left;
  logic read_active;

  integer i;

  assign s_axi_awready = !write_active && !s_axi_bvalid;
  assign s_axi_wready  = write_active;
  assign s_axi_arready = !read_active && !s_axi_rvalid;
  assign s_axi_bresp   = 2'b00;
  assign s_axi_rresp   = 2'b00;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      write_addr       <= '0;
      write_beats_left <= '0;
      write_active     <= 1'b0;
      s_axi_bvalid     <= 1'b0;
    end else begin
      if (s_axi_awvalid && s_axi_awready) begin
        write_addr       <= s_axi_awaddr;
        write_beats_left <= s_axi_awlen + 1'b1;
        write_active     <= 1'b1;
      end

      if (s_axi_wvalid && s_axi_wready) begin
        for (i = 0; i < DATA_WIDTH/8; i = i + 1)
          if (s_axi_wstrb[i])
            mem[write_addr + i] <= s_axi_wdata[i*8 +: 8];

        write_addr       <= write_addr + (1 << s_axi_awsize);
        write_beats_left <= write_beats_left - 1'b1;

        if (s_axi_wlast) begin
          write_active <= 1'b0;
          s_axi_bvalid <= 1'b1;
        end
      end

      if (s_axi_bvalid && s_axi_bready)
        s_axi_bvalid <= 1'b0;
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      read_addr       <= '0;
      read_beats_left <= '0;
      read_active     <= 1'b0;
      s_axi_rvalid    <= 1'b0;
      s_axi_rdata     <= '0;
      s_axi_rlast     <= 1'b0;
    end else begin
      if (s_axi_arvalid && s_axi_arready) begin
        read_addr       <= s_axi_araddr;
        read_beats_left <= s_axi_arlen + 1'b1;
        read_active     <= 1'b1;
      end

      if (read_active && !s_axi_rvalid) begin
        for (i = 0; i < DATA_WIDTH/8; i = i + 1)
          s_axi_rdata[i*8 +: 8] <= mem[read_addr + i];
        s_axi_rlast  <= (read_beats_left == 1);
        s_axi_rvalid <= 1'b1;
      end

      if (s_axi_rvalid && s_axi_rready) begin
        s_axi_rvalid <= 1'b0;
        if (read_beats_left == 1) begin
          read_active <= 1'b0;
          s_axi_rlast <= 1'b0;
        end else begin
          read_addr       <= read_addr + (1 << s_axi_arsize);
          read_beats_left <= read_beats_left - 1'b1;
        end
      end
    end
  end

endmodule
