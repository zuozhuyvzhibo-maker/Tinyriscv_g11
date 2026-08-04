`ifndef MERGED_VCS_FSDB_DUMP_VH
`define MERGED_VCS_FSDB_DUMP_VH

// Keep the same source TBs usable by Icarus and VCS.  VCS defines
// VCS_FSDB for the formal server run; the default remains VCD for Icarus.
`ifdef VCS_FSDB
`define MERGED_DUMPFILE(path) $fsdbDumpfile(path)
`define MERGED_DUMPVARS(scope) $fsdbDumpvars(0, scope)
`else
`define MERGED_DUMPFILE(path) $dumpfile(path)
`define MERGED_DUMPVARS(scope) $dumpvars(0, scope)
`endif

`endif
