`timescale 1ns/1ps

// AXI protection defaults are compile-time configurable.
// AXPROT[0]: 0=unprivileged, 1=privileged
// AXPROT[1]: 0=secure,       1=non-secure
// AXPROT[2]: 0=data,         1=instruction
`ifndef AXI_DMA_AWPROT
  `define AXI_DMA_AWPROT 3'b000
`endif

`ifndef AXI_DMA_ARPROT
  `define AXI_DMA_ARPROT 3'b000
`endif

module axi_buf_dma #(
  parameter int unsigned AXI_ADDR_WIDTH     = 32,
  parameter int unsigned AXI_DATA_WIDTH     = 64,
  parameter int unsigned AXI_ID_WIDTH       = 6,
  parameter logic [AXI_ID_WIDTH-1:0] AXI_ID_VALUE = '0,
  parameter int unsigned BUFFER_ADDR_WIDTH  = 7,
  parameter int unsigned AXI_MAX_BURST_LEN  = 64,
  parameter int unsigned AXI_TIMEOUT_CYCLES = 1024
) (
  input  logic                         clk,
  input  logic                         rst_n,
  input  logic [31:0]                  dma_sa,
  input  logic [8:0]                   dma_length,
  input  logic                         dma_rw,
  input  logic                         dma_start,
  output logic                         dma_ready,
  output logic                         dma_busy,
  output logic                         dma_error,
  output logic [3:0]                   dma_error_code,
  output logic                         timeout_status,
  input  logic                         irq_done_enable,
  input  logic                         irq_error_enable,
  input  logic                         irq_done_clear,
  input  logic                         irq_error_clear,
  output logic                         irq_done_status,
  output logic                         irq_error_status,
  output logic                         dma_irq,
  input  logic [BUFFER_ADDR_WIDTH-1:0] buf_addr,
  input  logic [31:0]                  buf_din,
  output logic [31:0]                  buf_dout,
  input  logic                         buf_wr_en,
  input  logic                         buf_csn,
  output logic [AXI_ID_WIDTH-1:0]      m_axi_awid,
  output logic [AXI_ADDR_WIDTH-1:0]    m_axi_awaddr,
  output logic [7:0]                   m_axi_awlen,
  output logic [2:0]                   m_axi_awsize,
  output logic [1:0]                   m_axi_awburst,
  output logic [2:0]                   m_axi_awprot,
  output logic                         m_axi_awvalid,
  input  logic                         m_axi_awready,
  output logic [AXI_DATA_WIDTH-1:0]    m_axi_wdata,
  output logic [AXI_DATA_WIDTH/8-1:0]  m_axi_wstrb,
  output logic                         m_axi_wlast,
  output logic                         m_axi_wvalid,
  input  logic                         m_axi_wready,
  input  logic [AXI_ID_WIDTH-1:0]      m_axi_bid,
  input  logic [1:0]                   m_axi_bresp,
  input  logic                         m_axi_bvalid,
  output logic                         m_axi_bready,
  output logic [AXI_ID_WIDTH-1:0]      m_axi_arid,
  output logic [AXI_ADDR_WIDTH-1:0]    m_axi_araddr,
  output logic [7:0]                   m_axi_arlen,
  output logic [2:0]                   m_axi_arsize,
  output logic [1:0]                   m_axi_arburst,
  output logic [2:0]                   m_axi_arprot,
  output logic                         m_axi_arvalid,
  input  logic                         m_axi_arready,
  input  logic [AXI_ID_WIDTH-1:0]      m_axi_rid,
  input  logic [AXI_DATA_WIDTH-1:0]    m_axi_rdata,
  input  logic [1:0]                   m_axi_rresp,
  input  logic                         m_axi_rlast,
  input  logic                         m_axi_rvalid,
  output logic                         m_axi_rready
);

  import dma_pkg::*;

  localparam logic [1:0] AXI_RESP_OKAY = 2'b00;
  localparam int unsigned AXI_BYTES = AXI_DATA_WIDTH/8;
  localparam int unsigned BUFFER_BYTES = (1 << BUFFER_ADDR_WIDTH) * 4;
  localparam int unsigned TIMEOUT_W = (AXI_TIMEOUT_CYCLES <= 1) ? 1 : $clog2(AXI_TIMEOUT_CYCLES);

  dma_state_t state;
  logic [AXI_ADDR_WIDTH-1:0] current_addr;
  logic [9:0] remaining_bytes;
  logic [9:0] buffer_byte_index;
  logic direction_write;
  logic [7:0] burst_beats;
  logic [12:0] burst_bytes;
  logic [7:0] beat_index;

  logic [AXI_DATA_WIDTH-1:0] wdata_reg, wdata_stage, wdata_with_byte;
  logic [AXI_DATA_WIDTH/8-1:0] wstrb_reg, packed_wstrb;
  logic wlast_reg;
  logic [3:0] lane_start, bytes_this_beat, w_load_count;
  logic [7:0] sram_read_byte;
  logic [9:0] w_source_byte_index;

  logic [AXI_DATA_WIDTH-1:0] rdata_reg;
  logic rlast_reg;
  logic [3:0] r_lane_start, r_payload_count, r_payload_index;
  logic [31:0] read_word_stage, read_word_with_byte;
  logic [7:0] current_r_byte;
  logic r_word_write;

  logic [BUFFER_ADDR_WIDTH-1:0] sram_address;
  logic sram_wr_en, sram_csn;
  logic [31:0] sram_din, sram_dout;

  logic [TIMEOUT_W-1:0] timeout_count;
  logic wait_state, forward_progress, timeout_hit;
  logic done_event, error_event;

  function automatic [12:0] calc_burst_bytes(
    input logic [AXI_ADDR_WIDTH-1:0] addr,
    input logic [9:0] bytes_left
  );
    integer unsigned page_bytes, max_payload, selected_bytes;
    begin
      page_bytes = 4096 - addr[11:0];
      max_payload = AXI_MAX_BURST_LEN * AXI_BYTES - addr[2:0];
      selected_bytes = bytes_left;
      if (selected_bytes > page_bytes) selected_bytes = page_bytes;
      if (selected_bytes > max_payload) selected_bytes = max_payload;
      calc_burst_bytes = selected_bytes[12:0];
    end
  endfunction

  function automatic [7:0] calc_burst_beats(
    input logic [AXI_ADDR_WIDTH-1:0] addr,
    input logic [12:0] selected_bytes
  );
    integer unsigned beats;
    begin
      beats = (addr[2:0] + selected_bytes + AXI_BYTES - 1) / AXI_BYTES;
      calc_burst_beats = beats[7:0];
    end
  endfunction

  axi_buf_dma_buffer #(
    .ADDR_WIDTH(BUFFER_ADDR_WIDTH),
    .DATA_WIDTH(32)
  ) u_local_buffer (
    .clk(clk),
    .address(sram_address),
    .wr_en(sram_wr_en),
    .csn(sram_csn),
    .din(sram_din),
    .dout(sram_dout)
  );

  assign buf_dout = sram_dout;
  assign dma_irq = (irq_done_status & irq_done_enable) |
                   (irq_error_status & irq_error_enable);

  // This DMA currently permits only one outstanding transaction, so AWID and
  // ARID use one fixed configurable value. BID/RID are exposed for complete
  // AXI connectivity; response-ID checking is intentionally deferred until
  // multiple outstanding transactions are supported.

  // Use always @* rather than always_comb for combinational logic that contains
  // constant/part selects. This preserves combinational behavior while avoiding
  // the known Icarus elaboration diagnostic that expands sensitivity to all bits.
  always @* begin
    lane_start = (beat_index == 0) ? {1'b0, current_addr[2:0]} : 4'd0;
    if (remaining_bytes < (AXI_BYTES - lane_start))
      bytes_this_beat = remaining_bytes[3:0];
    else
      bytes_this_beat = AXI_BYTES - lane_start;
  end

  integer strb_lane;
  always @* begin
    packed_wstrb = '0;
    for (strb_lane = 0; strb_lane < AXI_BYTES; strb_lane = strb_lane + 1)
      if ((strb_lane >= lane_start) && ((strb_lane-lane_start) < bytes_this_beat))
        packed_wstrb[strb_lane] = 1'b1;
  end

  assign w_source_byte_index = buffer_byte_index + w_load_count;
  assign sram_read_byte = sram_dout[w_source_byte_index[1:0]*8 +: 8];

  always @* begin
    wdata_with_byte = wdata_stage;
    wdata_with_byte[(lane_start+w_load_count)*8 +: 8] = sram_read_byte;
  end

  assign current_r_byte = rdata_reg[(r_lane_start+r_payload_index)*8 +: 8];
  always @* begin
    read_word_with_byte = (buffer_byte_index[1:0] == 2'd0) ? 32'd0 : read_word_stage;
    read_word_with_byte[buffer_byte_index[1:0]*8 +: 8] = current_r_byte;
    r_word_write = (state == DMA_R_UNPACK) &&
                   ((buffer_byte_index[1:0] == 2'd3) || (remaining_bytes == 10'd1));
  end

  always @* begin
    sram_address = buf_addr;
    sram_wr_en = buf_wr_en;
    sram_csn = buf_csn;
    sram_din = buf_din;

    if (dma_busy) begin
      sram_address = '0;
      sram_wr_en = 1'b0;
      sram_csn = 1'b1;
      sram_din = '0;
      if (state == DMA_W_BUF_REQ) begin
        sram_address = w_source_byte_index[BUFFER_ADDR_WIDTH+1:2];
        sram_csn = 1'b0;
      end else if (r_word_write) begin
        sram_address = buffer_byte_index[BUFFER_ADDR_WIDTH+1:2];
        sram_wr_en = 1'b1;
        sram_csn = 1'b0;
        sram_din = read_word_with_byte;
      end
    end
  end

  always @* begin
    m_axi_awid    = AXI_ID_VALUE;
    m_axi_awaddr  = current_addr;
    m_axi_awlen   = burst_beats - 1'b1;
    m_axi_awsize  = 3'b011;
    m_axi_awburst = 2'b01;
    m_axi_awprot  = `AXI_DMA_AWPROT;
    m_axi_awvalid = (state == DMA_W_AW);
    m_axi_wdata   = wdata_reg;
    m_axi_wstrb   = wstrb_reg;
    m_axi_wlast   = wlast_reg;
    m_axi_wvalid  = (state == DMA_W_SEND);
    m_axi_bready  = (state == DMA_W_RESP);
    m_axi_arid    = AXI_ID_VALUE;
    m_axi_araddr  = current_addr;
    m_axi_arlen   = burst_beats - 1'b1;
    m_axi_arsize  = 3'b011;
    m_axi_arburst = 2'b01;
    m_axi_arprot  = `AXI_DMA_ARPROT;
    m_axi_arvalid = (state == DMA_R_AR);
    m_axi_rready  = (state == DMA_R_DATA);
  end

  always @* begin
    wait_state = 1'b0;
    forward_progress = 1'b0;
    case (state)
      DMA_W_AW:   begin wait_state = 1'b1; forward_progress = m_axi_awready; end
      DMA_W_SEND: begin wait_state = 1'b1; forward_progress = m_axi_wready; end
      DMA_W_RESP: begin wait_state = 1'b1; forward_progress = m_axi_bvalid; end
      DMA_R_AR:   begin wait_state = 1'b1; forward_progress = m_axi_arready; end
      DMA_R_DATA: begin wait_state = 1'b1; forward_progress = m_axi_rvalid; end
      default:    begin wait_state = 1'b0; forward_progress = 1'b0; end
    endcase
  end

  assign timeout_hit = wait_state && !forward_progress &&
                       (timeout_count >= AXI_TIMEOUT_CYCLES-1);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      timeout_count <= '0;
    else if (!wait_state || forward_progress)
      timeout_count <= '0;
    else if (!timeout_hit)
      timeout_count <= timeout_count + 1'b1;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      irq_done_status <= 1'b0;
      irq_error_status <= 1'b0;
    end else begin
      if (done_event) irq_done_status <= 1'b1;
      else if (irq_done_clear) irq_done_status <= 1'b0;
      if (error_event) irq_error_status <= 1'b1;
      else if (irq_error_clear) irq_error_status <= 1'b0;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= DMA_IDLE;
      dma_ready <= 1'b0;
      dma_busy <= 1'b0;
      dma_error <= 1'b0;
      dma_error_code <= DMA_ERR_NONE;
      timeout_status <= 1'b0;
      current_addr <= '0;
      remaining_bytes <= '0;
      buffer_byte_index <= '0;
      direction_write <= 1'b0;
      burst_beats <= 8'd1;
      burst_bytes <= 13'd1;
      beat_index <= '0;
      wdata_reg <= '0;
      wdata_stage <= '0;
      wstrb_reg <= '0;
      wlast_reg <= 1'b0;
      w_load_count <= '0;
      rdata_reg <= '0;
      rlast_reg <= 1'b0;
      r_lane_start <= '0;
      r_payload_count <= '0;
      r_payload_index <= '0;
      read_word_stage <= '0;
      done_event <= 1'b0;
      error_event <= 1'b0;
    end else begin
      done_event <= 1'b0;
      error_event <= 1'b0;
      if (!dma_start && !dma_busy) dma_ready <= 1'b0;

      if (timeout_hit) begin
        state <= DMA_ERROR;
        dma_error <= 1'b1;
        dma_error_code <= DMA_ERR_TIMEOUT;
        timeout_status <= 1'b1;
      end else begin
        case (state)
          DMA_IDLE: begin
            dma_busy <= 1'b0;
            if (dma_start && !dma_ready) begin
              current_addr <= dma_sa;
              remaining_bytes <= {1'b0, dma_length} + 10'd1;
              buffer_byte_index <= 10'd0;
              direction_write <= dma_rw;
              dma_error <= 1'b0;
              dma_error_code <= DMA_ERR_NONE;
              timeout_status <= 1'b0;
              dma_busy <= 1'b1;
              read_word_stage <= '0;
              state <= DMA_CHECK;
            end
          end

          DMA_CHECK: begin
            if (({1'b0, dma_length} + 10'd1) > BUFFER_BYTES) begin
              dma_error <= 1'b1;
              dma_error_code <= DMA_ERR_ALIGN;
              state <= DMA_ERROR;
            end else state <= DMA_PREP;
          end

          DMA_PREP: begin
            burst_bytes <= calc_burst_bytes(current_addr, remaining_bytes);
            burst_beats <= calc_burst_beats(current_addr, calc_burst_bytes(current_addr, remaining_bytes));
            beat_index <= 8'd0;
            if (direction_write) state <= DMA_W_AW;
            else state <= DMA_R_AR;
          end

          DMA_W_AW: if (m_axi_awready) begin
            wdata_stage <= '0;
            w_load_count <= 4'd0;
            state <= DMA_W_BUF_REQ;
          end

          DMA_W_BUF_REQ: state <= DMA_W_BUF_CAPTURE;

          DMA_W_BUF_CAPTURE: begin
            wdata_stage <= wdata_with_byte;
            if (w_load_count == bytes_this_beat-1'b1) begin
              wdata_reg <= wdata_with_byte;
              wstrb_reg <= packed_wstrb;
              wlast_reg <= (beat_index == burst_beats-1'b1);
              state <= DMA_W_SEND;
            end else begin
              w_load_count <= w_load_count + 1'b1;
              state <= DMA_W_BUF_REQ;
            end
          end

          DMA_W_SEND: if (m_axi_wready) begin
            remaining_bytes <= remaining_bytes - bytes_this_beat;
            buffer_byte_index <= buffer_byte_index + bytes_this_beat;
            if (wlast_reg) state <= DMA_W_RESP;
            else begin
              beat_index <= beat_index + 1'b1;
              wdata_stage <= '0;
              w_load_count <= '0;
              state <= DMA_W_BUF_REQ;
            end
          end

          DMA_W_RESP: if (m_axi_bvalid) begin
            if (m_axi_bresp != AXI_RESP_OKAY) begin
              dma_error <= 1'b1;
              dma_error_code <= DMA_ERR_BRESP;
              state <= DMA_ERROR;
            end else if (remaining_bytes == 0) state <= DMA_DONE;
            else begin
              current_addr <= current_addr + burst_bytes;
              state <= DMA_PREP;
            end
          end

          DMA_R_AR: if (m_axi_arready) state <= DMA_R_DATA;

          DMA_R_DATA: if (m_axi_rvalid) begin
            if (m_axi_rresp != AXI_RESP_OKAY) begin
              dma_error <= 1'b1;
              dma_error_code <= DMA_ERR_RRESP;
              state <= DMA_ERROR;
            end else if (m_axi_rlast && (beat_index != burst_beats-1'b1)) begin
              dma_error <= 1'b1;
              dma_error_code <= DMA_ERR_RLAST_EARLY;
              state <= DMA_ERROR;
            end else if (!m_axi_rlast && (beat_index == burst_beats-1'b1)) begin
              dma_error <= 1'b1;
              dma_error_code <= DMA_ERR_RLAST_MISSING;
              state <= DMA_ERROR;
            end else begin
              rdata_reg <= m_axi_rdata;
              rlast_reg <= m_axi_rlast;
              r_lane_start <= lane_start;
              r_payload_count <= bytes_this_beat;
              r_payload_index <= '0;
              state <= DMA_R_UNPACK;
            end
          end

          DMA_R_UNPACK: begin
            read_word_stage <= read_word_with_byte;
            remaining_bytes <= remaining_bytes - 1'b1;
            buffer_byte_index <= buffer_byte_index + 1'b1;
            if ((buffer_byte_index[1:0] == 2'd3) || (remaining_bytes == 10'd1))
              read_word_stage <= '0;

            if (r_payload_index == r_payload_count-1'b1) begin
              if (rlast_reg) begin
                if (remaining_bytes == 10'd1) state <= DMA_DONE;
                else begin
                  current_addr <= current_addr + burst_bytes;
                  state <= DMA_PREP;
                end
              end else begin
                beat_index <= beat_index + 1'b1;
                state <= DMA_R_DATA;
              end
            end else begin
              r_payload_index <= r_payload_index + 1'b1;
            end
          end

          DMA_DONE: begin
            dma_busy <= 1'b0;
            dma_ready <= 1'b1;
            done_event <= 1'b1;
            state <= DMA_IDLE;
          end

          DMA_ERROR: begin
            dma_busy <= 1'b0;
            dma_ready <= 1'b1;
            error_event <= 1'b1;
            state <= DMA_IDLE;
          end

          default: begin
            dma_error <= 1'b1;
            dma_error_code <= DMA_ERR_ILLEGAL_STATE;
            state <= DMA_ERROR;
          end
        endcase
      end
    end
  end

endmodule
