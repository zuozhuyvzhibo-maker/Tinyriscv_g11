/*
 * Copyright 2019 Blue Liang, liangkangnan@163.com
 * Licensed under the Apache License, Version 2.0.
 */

`include "lhr_defs.v"

// IF-to-ID pipeline register.
module lhr_if_id(
    input wire clk,
    input wire rst,
    input wire[`LHR_InstBus] inst_i,
    input wire[`LHR_InstAddrBus] inst_addr_i,
    input wire[`LHR_Hold_Flag_Bus] hold_flag_i,
    output wire[`LHR_InstBus] inst_o,
    output wire[`LHR_InstAddrBus] inst_addr_o
    );

    wire flush_en = (hold_flag_i >= `LHR_Hold_If) &&
                    (hold_flag_i != `LHR_Hold_Id_Keep) &&
                    (hold_flag_i != `LHR_Hold_Id_Keep_If);
    wire keep_en = (hold_flag_i == `LHR_Hold_Id_Keep);

    lhr_gen_pipe_stall_dff #(32) inst_ff(
        clk, rst, flush_en, keep_en, `LHR_INST_NOP, inst_i, inst_o
    );
    lhr_gen_pipe_stall_dff #(32) inst_addr_ff(
        clk, rst, flush_en, keep_en, `LHR_ZeroWord, inst_addr_i, inst_addr_o
    );

endmodule
