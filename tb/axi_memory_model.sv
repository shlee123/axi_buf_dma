`timescale 1ns/1ps

module axi_memory_model #(
  parameter int unsigned ADDR_WIDTH        = 32,
  parameter int unsigned DATA_WIDTH        = 64,
  parameter int unsigned MEM_BYTES         = 65536,
  parameter int unsigned AW_STALL_CYCLES   = 0,
  parameter int unsigned W_STALL_EVERY     = 0,
  parameter int unsigned W_STALL_CYCLES    = 0,
  parameter int unsigned AR_STALL_CYCLES   = 0,
  parameter int unsigned R_GAP_CYCLES      = 0,
  parameter logic [1:0]  BRESP_VALUE        = 2'b00,
  parameter logic [1:0]  RRESP_VALUE        = 2'b00,
  parameter int unsigned RLAST_MODE         = 0,
  parameter int unsigned BVALID_DELAY       = 0,
  parameter int unsigned RVALID_DELAY       = 0
) (
  input  logic                       clk,
  input  logic                       rst_n,
  input  logic [ADDR_WIDTH-1:0]      s_axi_awaddr,
  input  logic [7:0]                 s_axi_awlen,
  input  logic [2:0]                 s_axi_awsize,
  input  logic [1:0]                 s_axi_awburst,
  input  logic                       s_axi_awvalid,
  output logic                       s_axi_awready,
  input  logic [DATA_WIDTH-1:0]      s_axi_wdata,
  input  logic [DATA_WIDTH/8-1:0]    s_axi_wstrb,
  input  logic                       s_axi_wlast,
  input  logic                       s_axi_wvalid,
  output logic                       s_axi_wready,
  output logic [1:0]                 s_axi_bresp,
  output logic                       s_axi_bvalid,
  input  logic                       s_axi_bready,
  input  logic [ADDR_WIDTH-1:0]      s_axi_araddr,
  input  logic [7:0]                 s_axi_arlen,
  input  logic [2:0]                 s_axi_arsize,
  input  logic [1:0]                 s_axi_arburst,
  input  logic                       s_axi_arvalid,
  output logic                       s_axi_arready,
  output logic [DATA_WIDTH-1:0]      s_axi_rdata,
  output logic [1:0]                 s_axi_rresp,
  output logic                       s_axi_rlast,
  output logic                       s_axi_rvalid,
  input  logic                       s_axi_rready
);

  localparam int unsigned RLAST_NORMAL  = 0;
  localparam int unsigned RLAST_EARLY   = 1;
  localparam int unsigned RLAST_MISSING = 2;
  localparam int unsigned DATA_BYTES    = DATA_WIDTH/8;

  logic [7:0] mem [0:MEM_BYTES-1];
  logic [ADDR_WIDTH-1:0] write_addr;
  logic [7:0] write_beats_left;
  logic write_active;
  logic write_response_pending;
  logic [ADDR_WIDTH-1:0] read_addr;
  logic [7:0] read_beats_left;
  logic read_active;

  integer unsigned aw_wait_count;
  integer unsigned ar_wait_count;
  integer unsigned w_beat_count;
  integer unsigned w_stall_count;
  integer unsigned r_gap_count;
  integer unsigned bvalid_delay_count;
  integer unsigned rvalid_delay_count;
  integer write_i;
  integer read_i;
  integer init_i;

  function automatic [7:0] safe_mem_read(input logic [ADDR_WIDTH-1:0] addr);
    begin
      if ((addr < MEM_BYTES) && !$isunknown(mem[addr]))
        safe_mem_read = mem[addr];
      else
        safe_mem_read = 8'h00;
    end
  endfunction

  initial begin
    for (init_i = 0; init_i < MEM_BYTES; init_i = init_i + 1)
      mem[init_i] = 8'h00;
  end

  assign s_axi_awready = !write_active && !s_axi_bvalid && !write_response_pending &&
                         (!s_axi_awvalid || (aw_wait_count >= AW_STALL_CYCLES));
  assign s_axi_wready  = write_active && (w_stall_count == 0);
  assign s_axi_arready = !read_active && !s_axi_rvalid &&
                         (!s_axi_arvalid || (ar_wait_count >= AR_STALL_CYCLES));
  assign s_axi_bresp   = BRESP_VALUE;
  assign s_axi_rresp   = RRESP_VALUE;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      aw_wait_count <= 0;
      ar_wait_count <= 0;
    end else begin
      if (s_axi_awvalid && !s_axi_awready)
        aw_wait_count <= aw_wait_count + 1;
      else
        aw_wait_count <= 0;
      if (s_axi_arvalid && !s_axi_arready)
        ar_wait_count <= ar_wait_count + 1;
      else
        ar_wait_count <= 0;
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      write_addr             <= '0;
      write_beats_left       <= '0;
      write_active           <= 1'b0;
      write_response_pending <= 1'b0;
      s_axi_bvalid           <= 1'b0;
      w_beat_count           <= 0;
      w_stall_count          <= 0;
      bvalid_delay_count     <= 0;
    end else begin
      if (w_stall_count != 0)
        w_stall_count <= w_stall_count - 1;

      if (write_response_pending && !s_axi_bvalid) begin
        if (bvalid_delay_count == 0) begin
          s_axi_bvalid           <= 1'b1;
          write_response_pending <= 1'b0;
        end else begin
          bvalid_delay_count <= bvalid_delay_count - 1;
        end
      end

      if (s_axi_awvalid && s_axi_awready) begin
        write_addr       <= {s_axi_awaddr[ADDR_WIDTH-1:3], 3'b000};
        write_beats_left <= s_axi_awlen + 1'b1;
        write_active     <= 1'b1;
        w_beat_count     <= 0;
      end

      if (s_axi_wvalid && s_axi_wready) begin
        for (write_i = 0; write_i < DATA_BYTES; write_i = write_i + 1)
          if (s_axi_wstrb[write_i])
            mem[write_addr + write_i] <= s_axi_wdata[write_i*8 +: 8];

        write_addr       <= write_addr + (1 << s_axi_awsize);
        write_beats_left <= write_beats_left - 1'b1;
        w_beat_count     <= w_beat_count + 1;

        if ((W_STALL_EVERY != 0) &&
            (((w_beat_count + 1) % W_STALL_EVERY) == 0) &&
            !s_axi_wlast)
          w_stall_count <= W_STALL_CYCLES;

        if (s_axi_wlast) begin
          write_active           <= 1'b0;
          write_response_pending <= 1'b1;
          bvalid_delay_count     <= BVALID_DELAY;
        end
      end

      if (s_axi_bvalid && s_axi_bready)
        s_axi_bvalid <= 1'b0;
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      read_addr          <= '0;
      read_beats_left    <= '0;
      read_active        <= 1'b0;
      s_axi_rvalid       <= 1'b0;
      s_axi_rdata        <= '0;
      s_axi_rlast        <= 1'b0;
      r_gap_count        <= 0;
      rvalid_delay_count <= 0;
    end else begin
      if (r_gap_count != 0)
        r_gap_count <= r_gap_count - 1;
      if (rvalid_delay_count != 0)
        rvalid_delay_count <= rvalid_delay_count - 1;

      if (s_axi_arvalid && s_axi_arready) begin
        read_addr          <= {s_axi_araddr[ADDR_WIDTH-1:3], 3'b000};
        read_beats_left    <= s_axi_arlen + 1'b1;
        read_active        <= 1'b1;
        r_gap_count        <= 0;
        rvalid_delay_count <= RVALID_DELAY;
      end

      if (read_active && !s_axi_rvalid &&
          (r_gap_count == 0) && (rvalid_delay_count == 0)) begin
        for (read_i = 0; read_i < DATA_BYTES; read_i = read_i + 1)
          s_axi_rdata[read_i*8 +: 8] <= safe_mem_read(read_addr + read_i);

        case (RLAST_MODE)
          RLAST_EARLY:   s_axi_rlast <= (read_beats_left == 2);
          RLAST_MISSING: s_axi_rlast <= 1'b0;
          default:       s_axi_rlast <= (read_beats_left == 1);
        endcase
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
          r_gap_count     <= R_GAP_CYCLES;
        end
      end
    end
  end

endmodule
