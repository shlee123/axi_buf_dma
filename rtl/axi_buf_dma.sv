`timescale 1ns/1ps

module axi_buf_dma #(
  parameter int unsigned AXI_ADDR_WIDTH     = 32,
  parameter int unsigned AXI_DATA_WIDTH     = 64,
  parameter int unsigned BUFFER_ADDR_WIDTH  = 7,
  parameter int unsigned AXI_MAX_BURST_LEN  = 64,
  parameter int unsigned AXI_TIMEOUT_CYCLES = 1024
) (
  input  logic                      clk,
  input  logic                      rst_n,
  input  logic [31:0]               dma_sa,
  input  logic [6:0]                dma_length,
  input  logic                      dma_rw,
  input  logic                      dma_start,
  output logic                      dma_ready,
  output logic                      dma_busy,
  output logic                      dma_error,
  output logic [3:0]                dma_error_code,
  output logic                      timeout_status,
  input  logic                      irq_done_enable,
  input  logic                      irq_error_enable,
  input  logic                      irq_done_clear,
  input  logic                      irq_error_clear,
  output logic                      irq_done_status,
  output logic                      irq_error_status,
  output logic                      dma_irq,
  input  logic [BUFFER_ADDR_WIDTH-1:0] buf_addr,
  input  logic [31:0]               buf_din,
  output logic [31:0]               buf_dout,
  input  logic                      buf_wr_en,
  input  logic                      buf_csn,
  output logic [AXI_ADDR_WIDTH-1:0] m_axi_awaddr,
  output logic [7:0]                m_axi_awlen,
  output logic [2:0]                m_axi_awsize,
  output logic [1:0]                m_axi_awburst,
  output logic                      m_axi_awvalid,
  input  logic                      m_axi_awready,
  output logic [AXI_DATA_WIDTH-1:0] m_axi_wdata,
  output logic [AXI_DATA_WIDTH/8-1:0] m_axi_wstrb,
  output logic                      m_axi_wlast,
  output logic                      m_axi_wvalid,
  input  logic                      m_axi_wready,
  input  logic [1:0]                m_axi_bresp,
  input  logic                      m_axi_bvalid,
  output logic                      m_axi_bready,
  output logic [AXI_ADDR_WIDTH-1:0] m_axi_araddr,
  output logic [7:0]                m_axi_arlen,
  output logic [2:0]                m_axi_arsize,
  output logic [1:0]                m_axi_arburst,
  output logic                      m_axi_arvalid,
  input  logic                      m_axi_arready,
  input  logic [AXI_DATA_WIDTH-1:0] m_axi_rdata,
  input  logic [1:0]                m_axi_rresp,
  input  logic                      m_axi_rlast,
  input  logic                      m_axi_rvalid,
  output logic                      m_axi_rready
);

  import dma_pkg::*;
  localparam logic [1:0] AXI_RESP_OKAY = 2'b00;

  dma_state_t state;
  logic [31:0] buffer_mem [0:(1<<BUFFER_ADDR_WIDTH)-1];
  logic [AXI_ADDR_WIDTH-1:0] current_addr;
  logic [7:0] remaining_words;
  logic [BUFFER_ADDR_WIDTH:0] buffer_word_index;
  logic direction_write;
  logic [AXI_ADDR_WIDTH-1:0] burst_beats;
  logic [7:0] beat_index;
  logic [AXI_DATA_WIDTH-1:0] wdata_reg;
  logic [AXI_DATA_WIDTH/8-1:0] wstrb_reg;
  logic wlast_reg;
  integer unsigned timeout_count;
  logic wait_state;
  logic forward_progress;
  logic timeout_hit;
  logic done_event;
  logic error_event;

  function automatic [7:0] calc_burst_beats(
    input logic [AXI_ADDR_WIDTH-1:0] addr,
    input logic [7:0] words_left
  );
    integer unsigned total_beats;
    integer unsigned boundary_beats;
    integer unsigned selected_beats;
    begin
      total_beats = (words_left + 1) >> 1;
      boundary_beats = (4096 - addr[11:0]) >> 3;
      if (boundary_beats == 0)
        boundary_beats = 512;
      selected_beats = total_beats;
      if (selected_beats > AXI_MAX_BURST_LEN)
        selected_beats = AXI_MAX_BURST_LEN;
      if (selected_beats > boundary_beats)
        selected_beats = boundary_beats;
      calc_burst_beats = selected_beats[7:0];
    end
  endfunction

  assign dma_irq = (irq_done_status & irq_done_enable) |
                   (irq_error_status & irq_error_enable);

  always_comb begin
    m_axi_awaddr  = current_addr;
    m_axi_awlen   = burst_beats[7:0] - 1'b1;
    m_axi_awsize  = 3'b011;
    m_axi_awburst = 2'b01;
    m_axi_awvalid = (state == DMA_W_AW);
    m_axi_wdata   = wdata_reg;
    m_axi_wstrb   = wstrb_reg;
    m_axi_wlast   = wlast_reg;
    m_axi_wvalid  = (state == DMA_W_SEND);
    m_axi_bready  = (state == DMA_W_RESP);
    m_axi_araddr  = current_addr;
    m_axi_arlen   = burst_beats[7:0] - 1'b1;
    m_axi_arsize  = 3'b011;
    m_axi_arburst = 2'b01;
    m_axi_arvalid = (state == DMA_R_AR);
    m_axi_rready  = (state == DMA_R_DATA);
  end

  always_comb begin
    wait_state = 1'b0;
    forward_progress = 1'b0;
    case (state)
      DMA_W_AW: begin wait_state = 1'b1; forward_progress = m_axi_awready; end
      DMA_W_SEND: begin wait_state = 1'b1; forward_progress = m_axi_wready; end
      DMA_W_RESP: begin wait_state = 1'b1; forward_progress = m_axi_bvalid; end
      DMA_R_AR: begin wait_state = 1'b1; forward_progress = m_axi_arready; end
      DMA_R_DATA: begin wait_state = 1'b1; forward_progress = m_axi_rvalid; end
      default: begin wait_state = 1'b0; forward_progress = 1'b0; end
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
    if (!rst_n)
      buf_dout <= 32'b0;
    else if (!dma_busy && !buf_csn && !buf_wr_en)
      buf_dout <= buffer_mem[buf_addr];
  end

  always_ff @(posedge clk) begin
    if (rst_n && !dma_busy && !buf_csn && buf_wr_en)
      buffer_mem[buf_addr] <= buf_din;
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
      remaining_words   <= '0;
      buffer_word_index <= '0;
      direction_write   <= 1'b0;
      burst_beats       <= 1;
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
              remaining_words   <= {1'b0, dma_length} + 8'd1;
              buffer_word_index <= '0;
              direction_write   <= dma_rw;
              dma_error         <= 1'b0;
              dma_error_code    <= DMA_ERR_NONE;
              timeout_status    <= 1'b0;
              dma_busy          <= 1'b1;
              state             <= DMA_CHECK;
            end
          end

          DMA_CHECK: begin
            if (current_addr[2:0] != 3'b000) begin
              dma_error      <= 1'b1;
              dma_error_code <= DMA_ERR_ALIGN;
              state          <= DMA_ERROR;
            end else
              state <= DMA_PREP;
          end

          DMA_PREP: begin
            burst_beats <= calc_burst_beats(current_addr, remaining_words);
            beat_index  <= 8'd0;
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
            wdata_reg[31:0] <= buffer_mem[buffer_word_index[BUFFER_ADDR_WIDTH-1:0]];
            if (remaining_words > 1) begin
              wdata_reg[63:32] <= buffer_mem[buffer_word_index[BUFFER_ADDR_WIDTH-1:0] + 1'b1];
              wstrb_reg <= 8'hFF;
            end else begin
              wdata_reg[63:32] <= 32'b0;
              wstrb_reg <= 8'h0F;
            end
            wlast_reg <= (beat_index == (burst_beats[7:0] - 1'b1));
            state <= DMA_W_SEND;
          end

          DMA_W_SEND: begin
            if (m_axi_wready) begin
              if (remaining_words > 1) begin
                remaining_words   <= remaining_words - 8'd2;
                buffer_word_index <= buffer_word_index + 2'd2;
              end else begin
                remaining_words   <= 8'd0;
                buffer_word_index <= buffer_word_index + 1'b1;
              end
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
              end else if (remaining_words == 0)
                state <= DMA_DONE;
              else begin
                current_addr <= current_addr + (burst_beats << 3);
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
              end else if (m_axi_rlast && (beat_index != (burst_beats[7:0] - 1'b1))) begin
                dma_error      <= 1'b1;
                dma_error_code <= DMA_ERR_RLAST_EARLY;
                state          <= DMA_ERROR;
              end else if (!m_axi_rlast && (beat_index == (burst_beats[7:0] - 1'b1))) begin
                dma_error      <= 1'b1;
                dma_error_code <= DMA_ERR_RLAST_MISSING;
                state          <= DMA_ERROR;
              end else begin
                buffer_mem[buffer_word_index[BUFFER_ADDR_WIDTH-1:0]] <= m_axi_rdata[31:0];
                if (remaining_words > 1)
                  buffer_mem[buffer_word_index[BUFFER_ADDR_WIDTH-1:0] + 1'b1] <= m_axi_rdata[63:32];
                if (remaining_words > 1) begin
                  remaining_words   <= remaining_words - 8'd2;
                  buffer_word_index <= buffer_word_index + 2'd2;
                end else begin
                  remaining_words   <= 8'd0;
                  buffer_word_index <= buffer_word_index + 1'b1;
                end
                if (m_axi_rlast) begin
                  if (remaining_words <= 2)
                    state <= DMA_DONE;
                  else begin
                    current_addr <= current_addr + (burst_beats << 3);
                    state <= DMA_PREP;
                  end
                end else
                  beat_index <= beat_index + 1'b1;
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
