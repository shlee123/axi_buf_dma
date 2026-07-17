`timescale 1ns/1ps

module fsdb_dump;
`ifdef ENABLE_FSDB
  string fsdb_file;

  initial begin
    if (!$value$plusargs("FSDB_FILE=%s", fsdb_file))
      fsdb_file = "wave.fsdb";

    $fsdbDumpfile(fsdb_file);
    $fsdbDumpvars(0);
    $fsdbDumpMDA();
  end
`endif
endmodule
