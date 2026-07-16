`timescale 1ns/1ps

module axi_buf_dma #(
  parameter int unsigned AXI_ADDR_WIDTH     = 32,
  parameter int unsigned AXI_DATA_WIDTH     = 64,
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
  output logic [AXI_ADDR_WIDTH-1:0]    m_axi_awaddr,
  output logic [7:0]                   m_axi_awlen,
  output logic [2:0]                   m_axi_awsize,
  output logic [1:0]                   m_axi_awburst,
  output logic                         m_axi_awvalid,
  input  logic                         m_axi_awready,
  output logic [AXI_DATA_WIDTH-1:0]    m_axi_wdata,
  output logic [AXI_DATA_WIDTH/8-1:0]  m_axi_wstrb,
  output logic                         m_axi_wlast,
  output logic                         m_axi_wvalid,
  input  logic                         m_axi_wready,
  input  logic [1:0]                   m_axi_bresp,
  input  logic                         m_axi_bvalid,
  output logic                         m_axi_bready,
  output logic [AXI_ADDR_WIDTH-1:0]    m_axi_araddr,
  output logic [7:0]                   m_axi_arlen,
  output logic [2:0]                   m_axi_arsize,
  output logic [1:0]                   m_axi_arburst,
  output logic                         m_axi_arvalid,
  input  logic                         m_axi_arready,
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

  dma_state_t state;

  logic [AXI_ADDR_WIDTH-1:0] current_addr;
  logic [9:0] remaining_bytes;
  logic [9:0] buffer_byte_index;
  logic direction_write;
  logic [7:0] burst_beats;
  logic [12:0] burst_bytes;
  logic [7:0] beat_index;
  logic [AXI_DATA_WIDTH-1:0] wdata_reg;
  logic [AXI_DATA_WIDTH/8-1:0] wstrb_reg;
  logic wlast_reg;
  logic [3:0] lane_start;
  logic [3:0] bytes_this_beat;
  logic [AXI_DATA_WIDTH-1:0] packed_wdata;
  logic [AXI_DATA_WIDTH/8-1:0] packed_wstrb;

  logic [AXI_DATA_WIDTH-1:0] buffer_dma_read_data;
  logic buffer_dma_write_enable;
  logic [BUFFER_ADDR_WIDTH+1:0] buffer_dma_write_addr;
  logic [AXI_DATA_WIDTH-1:0] buffer_dma_write_data;
  logic [AXI_DATA_WIDTH/8-1:0] buffer_dma_write_strb;
  logic read_beat_accept;

  integer unsigned timeout_count;
  logic wait_state;
  logic forward_progress;
  logic timeout_hit;
  logic done_event;
  logic error_event;

  function automatic [12:0] calc_burst_bytes(
    input logic [AXI_ADDR_WIDTH-1:0] addr,
    input logic [9:0] bytes_left
  );
    integer unsigned page_bytes;
    integer unsigned max_payload;
    integer unsigned selected_bytes;
    begin
      page_bytes = 4096 - addr[11:0];
      max_payload = AXI_MAX_BURST_LEN * AXI_BYTES - addr[2:0];
      selected_bytes = bytes_left;
      if (selected_bytes > page_bytes)
        selected_bytes = page_bytes;
      if (selected_bytes > max_payload)
        selected_bytes = max_payload;
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
    .ADDR_WIDTH     (BUFFER_ADDR_WIDTH),
    .DMA_DATA_WIDTH (AXI_DATA_WIDTH)
  ) u_local_buffer (
    .clk                 (clk),
    .rst_n               (rst_n),
    .host_enable         (!dma_busy),
    .host_addr           (buf_addr),
    .host_wdata          (buf_din),
    .host_we             (buf_wr_en),
    .host_csn            (buf_csn),
    .host_rdata          (buf_dout),
    .dma_read_byte_addr  (buffer_byte_index[BUFFER_ADDR_WIDTH+1:0]),
    .dma_read_data       (buffer_dma_read_data),
    .dma_write_enable    (buffer_dma_write_enable),
    .dma_write_byte_addr (buffer_dma_write_addr),
    .dma_write_data      (buffer_dma_write_data),
    .dma_write_strb      (buffer_dma_write_strb)
  );

  assign dma_irq = (irq_done_status & irq_done_enable) |
                   (irq_error_status & irq_error_enable);

  always_comb begin
    lane_start = (beat_index == 0) ? {1'b0, current_addr[2:0]} : 4'd0;
    if (remaining_bytes < (AXI_BYTES - lane_start))
      bytes_this_beat = remaining_bytes[3:0];
    else
      bytes_this_beat = AXI_BYTES - lane_start;
  end

  integer pack_lane;
  integer pack_offset;
  always_comb begin
    packed_wdata = '0;
    packed_wstrb = '0;
    for (pack_lane = 0; pack_lane < AXI_BYTES; pack_lane = pack_lane + 1) begin
      pack_offset = pack_lane - lane_start;
      if ((pack_lane >= lane_start) && (pack_offset < remaining_bytes)) begin
        packed_wdata[pack_lane*8 +: 8] = buffer_dma_read_data[pack_offset*8 +: 8];
        packed_wstrb[pack_lane] = 1'b1;
      end
    end
  end

  assign read_beat_accept = (state == DMA_R_DATA) && m_axi_rvalid &&
                            (m_axi_rresp == AXI_RESP_OKAY) &&
                            !(m_axi_rlast && (beat_index != (burst_beats - 1'b1))) &&
                            !(!m_axi_rlast && (beat_index == (burst_beats - 1'b1)));

  integer read_lane;
  integer read_offset;
  always_comb begin
    buffer_dma_write_enable = read_beat_accept;
    buffer_dma_write_addr = buffer_byte_index[BUFFER_ADDR_WIDTH+1:0];
    buffer_dma_write_data = '0;
    buffer_dma_write_strb = '0;
    for (read_lane = 0; read_lane < AXI_BYTES; read_lane = read_lane + 1) begin
      read_offset = read_lane - lane_start;
      if ((read_lane >= lane_start) && (read_offset < remaining_bytes)) begin
        buffer_dma_write_data[read_offset*8 +: 8] = m_axi_rdata[read_lane*8 +: 8];
        buffer_dma_write_strb[read_offset] = 1'b1;
      end
    end
  end

  always_comb begin
    m_axi_awaddr  = current_addr;
    m_axi_awlen   = burst_beats - 1'b1;
    m_axi_awsize  = 3'b011;
    m_axi_awburst = 2'b01;
    m_axi_awvalid = (state == DMA_W_AW);
    m_axi_wdata   = wdata_reg;
    m_axi_wstrb   = wstrb_reg;
    m_axi_wlast   = wlast_reg;
    m_axi_wvalid  = (state == DMA_W_SEND);
    m_axi_bready  = (state == DMA_W_RESP);
    m_axi_araddr  = current_addr;
    m_axi_arlen   = burst_beats - 1'b1;
    m_axi_arsize  = 3'b011;
    m_axi_arburst = 2'b01;
    m_axi_arvalid = (state == DMA_R_AR);
    m_axi_rready  = (state == DMA_R_DATA);
  end

  always_comb begin
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
                       (timeout_count >= (AXI_TIMEOUT_CYCLES-1));

  always_ff @(posedge clk) begin
    if (!rst_n)
      timeout_count <= 0;
    else if (!wait_state || forward_progress)
      timeout_count <= 0;
    else if (!timeout_hit)
      timeout_count <= timeout_count + 1;
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      irq_done_status  <= 1'b0;
      irq_error_status <= 1'b0;
    end else begin
      if (done_event)
        irq_done_status <= 1'b1;
      else if (irq_done_clear)
        irq_done_status <= 1'b0;
      if (error_event)
        irq_error_status <= 1'b1;
      else if (irq_error_clear)
        irq_error_status <= 1'b0;
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      state             <= DMA_IDLE;
      dma_ready         <= 1'b0;
      dma_busy          <= 1'b0;
      dma_error         <= 1'b0;
      dma_error_code    <= DMA_ERR_NONE;
      timeout_status    <= 1'b0;
      current_addr      <= '0;
      remaining_bytes   <= '0;
      buffer_byte_index <= '0;
      direction_write   <= 1'b0;
      burst_beats       <= 8'd1;
      burst_bytes       <= 13'd1;
      beat_index        <= '0;
      wdata_reg         <= '0;
      wstrb_reg         <= '0;
      wlast_reg         <= 1'b0;
      done_event        <= 1'b0;
      error_event       <= 1'b0;
    end else begin
      done_event  <= 1'b0;
      error_event <= 1'b0;

      if (!dma_start && !dma_busy)
        dma_ready <= 1'b0;

      if (timeout_hit) begin
        state          <= DMA_ERROR;
        dma_error      <= 1'b1;
        dma_error_code <= DMA_ERR_TIMEOUT;
        timeout_status <= 1'b1;
      end else begin
        case (state)
          DMA_IDLE: begin
            dma_busy <= 1'b0;
            if (dma_start && !dma_ready) begin
              current_addr      <= dma_sa;
              remaining_bytes   <= {1'b0, dma_length} + 10'd1;
              buffer_byte_index <= 10'd0;
              direction_write   <= dma_rw;
              dma_error         <= 1'b0;
              dma_error_code    <= DMA_ERR_NONE;
              timeout_status    <= 1'b0;
              dma_busy          <= 1'b1;
              state             <= DMA_CHECK;
            end
          end

          DMA_CHECK: begin
            if (({1'b0, dma_length} + 10'd1) > BUFFER_BYTES) begin
              dma_error      <= 1'b1;
              dma_error_code <= DMA_ERR_ALIGN;
              state          <= DMA_ERROR;
            end else begin
              state <= DMA_PREP;
            end
          end

          DMA_PREP: begin
            burst_bytes <= calc_burst_bytes(current_addr, remaining_bytes);
            burst_beats <= calc_burst_beats(current_addr,
                             calc_burst_bytes(current_addr, remaining_bytes));
            beat_index <= 8'd0;
            if (direction_write)
              state <= DMA_W_AW;
            else
              state <= DMA_R_AR;
          end

          DMA_W_AW: begin
            if (m_axi_awready)
              state <= DMA_W_LOAD;
          end

          DMA_W_LOAD: begin
            wdata_reg <= packed_wdata;
            wstrb_reg <= packed_wstrb;
            wlast_reg <= (beat_index == (burst_beats - 1'b1));
            state <= DMA_W_SEND;
          end

          DMA_W_SEND: begin
            if (m_axi_wready) begin
              remaining_bytes   <= remaining_bytes - bytes_this_beat;
              buffer_byte_index <= buffer_byte_index + bytes_this_beat;
              if (wlast_reg)
                state <= DMA_W_RESP;
              else begin
                beat_index <= beat_index + 1'b1;
                state <= DMA_W_LOAD;
              end
            end
          end

          DMA_W_RESP: begin
            if (m_axi_bvalid) begin
              if (m_axi_bresp != AXI_RESP_OKAY) begin
                dma_error      <= 1'b1;
                dma_error_code <= DMA_ERR_BRESP;
                state          <= DMA_ERROR;
              end else if (remaining_bytes == 0) begin
                state <= DMA_DONE;
              end else begin
                current_addr <= current_addr + burst_bytes;
                state <= DMA_PREP;
              end
            end
          end

          DMA_R_AR: begin
            if (m_axi_arready)
              state <= DMA_R_DATA;
          end

          DMA_R_DATA: begin
            if (m_axi_rvalid) begin
              if (m_axi_rresp != AXI_RESP_OKAY) begin
                dma_error      <= 1'b1;
                dma_error_code <= DMA_ERR_RRESP;
                state          <= DMA_ERROR;
              end else if (m_axi_rlast && (beat_index != (burst_beats - 1'b1))) begin
                dma_error      <= 1'b1;
                dma_error_code <= DMA_ERR_RLAST_EARLY;
                state          <= DMA_ERROR;
              end else if (!m_axi_rlast && (beat_index == (burst_beats - 1'b1))) begin
                dma_error      <= 1'b1;
                dma_error_code <= DMA_ERR_RLAST_MISSING;
                state          <= DMA_ERROR;
              end else begin
                remaining_bytes   <= remaining_bytes - bytes_this_beat;
                buffer_byte_index <= buffer_byte_index + bytes_this_beat;
                if (m_axi_rlast) begin
                  if (remaining_bytes <= bytes_this_beat)
                    state <= DMA_DONE;
                  else begin
                    current_addr <= current_addr + burst_bytes;
                    state <= DMA_PREP;
                  end
                end else begin
                  beat_index <= beat_index + 1'b1;
                end
              end
            end
          end

          DMA_DONE: begin
            dma_busy   <= 1'b0;
            dma_ready  <= 1'b1;
            done_event <= 1'b1;
            state      <= DMA_IDLE;
          end

          DMA_ERROR: begin
            dma_busy    <= 1'b0;
            dma_ready   <= 1'b1;
            error_event <= 1'b1;
            state       <= DMA_IDLE;
          end

          default: begin
            dma_error      <= 1'b1;
            dma_error_code <= DMA_ERR_ILLEGAL_STATE;
            state          <= DMA_ERROR;
          end
        endcase
      end
    end
  end

endmodule
