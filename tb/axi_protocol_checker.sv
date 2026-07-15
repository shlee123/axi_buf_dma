`timescale 1ns/1ps

module axi_protocol_checker #(
  parameter int unsigned ADDR_WIDTH = 32,
  parameter int unsigned DATA_WIDTH = 64
) (
  input logic clk,
  input logic rst_n,

  input logic [ADDR_WIDTH-1:0] awaddr,
  input logic [7:0] awlen,
  input logic [2:0] awsize,
  input logic [1:0] awburst,
  input logic awvalid,
  input logic awready,

  input logic [DATA_WIDTH-1:0] wdata,
  input logic [DATA_WIDTH/8-1:0] wstrb,
  input logic wlast,
  input logic wvalid,
  input logic wready,

  input logic [ADDR_WIDTH-1:0] araddr,
  input logic [7:0] arlen,
  input logic [2:0] arsize,
  input logic [1:0] arburst,
  input logic arvalid,
  input logic arready,

  input logic [DATA_WIDTH-1:0] rdata,
  input logic [1:0] rresp,
  input logic rlast,
  input logic rvalid,
  input logic rready
);

  logic [ADDR_WIDTH-1:0] awaddr_q, araddr_q;
  logic [7:0] awlen_q, arlen_q;
  logic [2:0] awsize_q, arsize_q;
  logic [1:0] awburst_q, arburst_q;
  logic [DATA_WIDTH-1:0] wdata_q;
  logic [DATA_WIDTH/8-1:0] wstrb_q;
  logic wlast_q;
  logic aw_stalled_q, ar_stalled_q, w_stalled_q;

  integer unsigned write_beat_count;
  integer unsigned expected_write_beats;

  function automatic integer unsigned burst_bytes(
    input logic [7:0] len,
    input logic [2:0] size
  );
    burst_bytes = (integer'(len) + 1) << size;
  endfunction

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      aw_stalled_q <= 1'b0;
      ar_stalled_q <= 1'b0;
      w_stalled_q  <= 1'b0;
      write_beat_count <= 0;
      expected_write_beats <= 0;
    end else begin
      if (aw_stalled_q) begin
        assert (awvalid) else $fatal(1, "AWVALID dropped before AWREADY");
        assert ({awaddr,awlen,awsize,awburst} == {awaddr_q,awlen_q,awsize_q,awburst_q})
          else $fatal(1, "AW payload changed while stalled");
      end
      if (ar_stalled_q) begin
        assert (arvalid) else $fatal(1, "ARVALID dropped before ARREADY");
        assert ({araddr,arlen,arsize,arburst} == {araddr_q,arlen_q,arsize_q,arburst_q})
          else $fatal(1, "AR payload changed while stalled");
      end
      if (w_stalled_q) begin
        assert (wvalid) else $fatal(1, "WVALID dropped before WREADY");
        assert ({wdata,wstrb,wlast} == {wdata_q,wstrb_q,wlast_q})
          else $fatal(1, "W payload changed while stalled");
      end

      aw_stalled_q <= awvalid && !awready;
      ar_stalled_q <= arvalid && !arready;
      w_stalled_q  <= wvalid && !wready;
      if (awvalid && !awready) begin
        awaddr_q <= awaddr; awlen_q <= awlen; awsize_q <= awsize; awburst_q <= awburst;
      end
      if (arvalid && !arready) begin
        araddr_q <= araddr; arlen_q <= arlen; arsize_q <= arsize; arburst_q <= arburst;
      end
      if (wvalid && !wready) begin
        wdata_q <= wdata; wstrb_q <= wstrb; wlast_q <= wlast;
      end

      if (awvalid && awready) begin
        assert (awburst == 2'b01) else $fatal(1, "Only INCR write bursts are supported");
        assert (awsize == 3'b011) else $fatal(1, "Write beat size must be 8 bytes");
        assert ((awaddr[11:0] + burst_bytes(awlen,awsize)) <= 4096)
          else $fatal(1, "Write burst crosses 4 KB boundary");
        expected_write_beats <= integer'(awlen) + 1;
        write_beat_count <= 0;
      end

      if (wvalid && wready) begin
        write_beat_count <= write_beat_count + 1;
        if (wlast)
          assert ((write_beat_count + 1) == expected_write_beats)
            else $fatal(1, "WLAST asserted on wrong beat");
        else
          assert ((write_beat_count + 1) < expected_write_beats)
            else $fatal(1, "Missing WLAST on final beat");
      end

      if (arvalid && arready) begin
        assert (arburst == 2'b01) else $fatal(1, "Only INCR read bursts are supported");
        assert (arsize == 3'b011) else $fatal(1, "Read beat size must be 8 bytes");
        assert ((araddr[11:0] + burst_bytes(arlen,arsize)) <= 4096)
          else $fatal(1, "Read burst crosses 4 KB boundary");
      end

      if (rvalid && !rready) begin
        assert (!$isunknown({rdata,rresp,rlast}))
          else $fatal(1, "Read payload contains unknown values while stalled");
      end
    end
  end
endmodule
