`timescale 1ns/1ps

`ifndef FSDB_TOP
  `define FSDB_TOP tb_axi_buf_dma_byte_addressing
`endif

module fsdb_dump;
`ifdef ENABLE_FSDB
  string fsdb_file;

  initial begin
    if (!$value$plusargs("FSDB_FILE=%s", fsdb_file))
      fsdb_file = "wave.fsdb";

    $fsdbDumpfile(fsdb_file);
    $fsdbDumpvars(0, `FSDB_TOP);
    $fsdbDumpMDA();
  end
`endif
endmodule

bind `FSDB_TOP fsdb_dump u_fsdb_dump();
