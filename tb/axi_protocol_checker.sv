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

  localparam int unsigned STRB_WIDTH = DATA_WIDTH / 8;

  logic [ADDR_WIDTH-1:0] awaddr_q, araddr_q;
  logic [7:0] awlen_q, arlen_q;
  logic [2:0] awsize_q, arsize_q;
  logic [1:0] awburst_q, arburst_q;
  logic [DATA_WIDTH-1:0] wdata_q, rdata_q;
  logic [STRB_WIDTH-1:0] wstrb_q;
  logic [1:0] rresp_q;
  logic wlast_q, rlast_q;
  logic aw_stalled_q, ar_stalled_q, w_stalled_q, r_stalled_q;
  logic write_active, read_active;

  integer unsigned write_beat_count;
  integer unsigned expected_write_beats;
  integer unsigned read_beat_count;
  integer unsigned expected_read_beats;

  function automatic integer unsigned burst_bytes(
    input logic [7:0] len,
    input logic [2:0] size
  );
    burst_bytes = (integer'(len) + 1) << size;
  endfunction

  function automatic logic strobe_is_contiguous(
    input logic [STRB_WIDTH-1:0] strobe
  );
    logic seen_one;
    logic seen_zero_after_one;
    integer i;
    begin
      seen_one = 1'b0;
      seen_zero_after_one = 1'b0;
      strobe_is_contiguous = 1'b1;
      for (i = 0; i < STRB_WIDTH; i = i + 1) begin
        if (strobe[i]) begin
          if (seen_zero_after_one)
            strobe_is_contiguous = 1'b0;
          seen_one = 1'b1;
        end else if (seen_one) begin
          seen_zero_after_one = 1'b1;
        end
      end
    end
  endfunction

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      aw_stalled_q <= 1'b0;
      ar_stalled_q <= 1'b0;
      w_stalled_q  <= 1'b0;
      r_stalled_q  <= 1'b0;
      write_beat_count <= 0;
      expected_write_beats <= 0;
      read_beat_count <= 0;
      expected_read_beats <= 0;
      write_active <= 1'b0;
      read_active <= 1'b0;
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
      if (r_stalled_q) begin
        assert (rvalid) else $fatal(1, "RVALID dropped before RREADY");
        assert ({rdata,rresp,rlast} === {rdata_q,rresp_q,rlast_q})
          else $fatal(1, "R payload changed while stalled");
      end

      aw_stalled_q <= awvalid && !awready;
      ar_stalled_q <= arvalid && !arready;
      w_stalled_q  <= wvalid && !wready;
      r_stalled_q  <= rvalid && !rready;
      if (awvalid && !awready) begin
        awaddr_q <= awaddr; awlen_q <= awlen; awsize_q <= awsize; awburst_q <= awburst;
      end
      if (arvalid && !arready) begin
        araddr_q <= araddr; arlen_q <= arlen; arsize_q <= arsize; arburst_q <= arburst;
      end
      if (wvalid && !wready) begin
        wdata_q <= wdata; wstrb_q <= wstrb; wlast_q <= wlast;
      end
      if (rvalid && !rready) begin
        rdata_q <= rdata; rresp_q <= rresp; rlast_q <= rlast;
      end

      if (awvalid && awready) begin
        assert (!write_active) else $fatal(1, "New AW accepted before prior W burst completed");
        assert (awburst == 2'b01) else $fatal(1, "Only INCR write bursts are supported");
        assert (awsize == 3'b011) else $fatal(1, "Write beat size must be 8 bytes");
        assert ((awaddr[11:0] + burst_bytes(awlen,awsize)) <= 4096)
          else $fatal(1, "Write burst crosses 4 KB boundary");
        expected_write_beats <= integer'(awlen) + 1;
        write_beat_count <= 0;
        write_active <= 1'b1;
      end

      if (wvalid && wready) begin
        assert (write_active) else $fatal(1, "W beat accepted without an active AW burst");
        assert (wstrb != '0) else $fatal(1, "WSTRB must enable at least one byte lane");
        assert (strobe_is_contiguous(wstrb)) else $fatal(1, "WSTRB byte lanes must be contiguous");
        write_beat_count <= write_beat_count + 1;
        if (wlast) begin
          assert ((write_beat_count + 1) == expected_write_beats)
            else $fatal(1, "WLAST asserted on wrong beat");
          write_active <= 1'b0;
        end else begin
          assert ((write_beat_count + 1) < expected_write_beats)
            else $fatal(1, "Missing WLAST on final beat");
        end
      end

      if (arvalid && arready) begin
        assert (!read_active) else $fatal(1, "New AR accepted before prior R burst completed");
        assert (arburst == 2'b01) else $fatal(1, "Only INCR read bursts are supported");
        assert (arsize == 3'b011) else $fatal(1, "Read beat size must be 8 bytes");
        assert ((araddr[11:0] + burst_bytes(arlen,arsize)) <= 4096)
          else $fatal(1, "Read burst crosses 4 KB boundary");
        expected_read_beats <= integer'(arlen) + 1;
        read_beat_count <= 0;
        read_active <= 1'b1;
      end

      if (rvalid && rready) begin
        assert (read_active) else $fatal(1, "R beat accepted without an active AR burst");
        read_beat_count <= read_beat_count + 1;
        if (rlast) begin
          assert ((read_beat_count + 1) == expected_read_beats)
            else $fatal(1, "RLAST asserted on wrong beat");
          read_active <= 1'b0;
        end else begin
          assert ((read_beat_count + 1) < expected_read_beats)
            else $fatal(1, "Missing RLAST on final beat");
        end
      end
    end
  end
endmodule
