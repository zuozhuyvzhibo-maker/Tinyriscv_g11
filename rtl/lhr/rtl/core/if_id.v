/*
 * Copyright 2019 Blue Liang, liangkangnan@163.com
 * Licensed under the Apache License, Version 2.0.
 */

`include "defines.v"

// IF-to-ID pipeline register.
module if_id(
    input wire clk,
    input wire rst,
    input wire[`InstBus] inst_i,
    input wire[`InstAddrBus] inst_addr_i,
    input wire[`Hold_Flag_Bus] hold_flag_i,
    output wire[`InstBus] inst_o,
    output wire[`InstAddrBus] inst_addr_o
    );

    wire flush_en = (hold_flag_i >= `Hold_If) &&
                    (hold_flag_i != `Hold_Id_Keep) &&
                    (hold_flag_i != `Hold_Id_Keep_If);
    wire keep_en = (hold_flag_i == `Hold_Id_Keep);

    gen_pipe_stall_dff #(32) inst_ff(
        clk, rst, flush_en, keep_en, `INST_NOP, inst_i, inst_o
    );
    gen_pipe_stall_dff #(32) inst_addr_ff(
        clk, rst, flush_en, keep_en, `ZeroWord, inst_addr_i, inst_addr_o
    );

endmodule
