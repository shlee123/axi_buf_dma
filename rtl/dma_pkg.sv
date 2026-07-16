package dma_pkg;

  parameter int unsigned AXI_ADDR_WIDTH_DEFAULT    = 32;
  parameter int unsigned AXI_DATA_WIDTH_DEFAULT    = 64;
  parameter int unsigned BUFFER_ADDR_WIDTH_DEFAULT = 7;
  parameter int unsigned BUFFER_DATA_WIDTH_DEFAULT = 32;
  parameter int unsigned AXI_MAX_BURST_DEFAULT     = 64;
  parameter int unsigned AXI_TIMEOUT_DEFAULT       = 1024;

  typedef enum logic [4:0] {
    DMA_IDLE,
    DMA_CHECK,
    DMA_PREP,
    DMA_W_AW,
    DMA_W_BUF_REQ,
    DMA_W_BUF_CAPTURE,
    DMA_W_SEND,
    DMA_W_RESP,
    DMA_R_AR,
    DMA_R_DATA,
    DMA_R_UNPACK,
    DMA_DONE,
    DMA_ERROR
  } dma_state_t;

  typedef enum logic [3:0] {
    DMA_ERR_NONE,
    DMA_ERR_ALIGN,
    DMA_ERR_BRESP,
    DMA_ERR_RRESP,
    DMA_ERR_RLAST_EARLY,
    DMA_ERR_RLAST_MISSING,
    DMA_ERR_TIMEOUT,
    DMA_ERR_ILLEGAL_STATE
  } dma_error_code_t;

endpackage
