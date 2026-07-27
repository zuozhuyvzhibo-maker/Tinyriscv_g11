/*
 * Copyright 2020 Blue Liang, liangkangnan@163.com
 * Licensed under the Apache License, Version 2.0.
 */

`include "defines.v"

// ID-to-EX pipeline register.
module id_ex(
    input wire clk,
    input wire rst,
    input wire[`InstBus] inst_i,
    input wire[`InstAddrBus] inst_addr_i,
    input wire reg_we_i,
    input wire[`RegAddrBus] reg_waddr_i,
    input wire[`RegBus] reg1_rdata_i,
    input wire[`RegBus] reg2_rdata_i,
    input wire[`MemAddrBus] op1_i,
    input wire[`MemAddrBus] op2_i,
    input wire[`MemAddrBus] op1_jump_i,
    input wire[`MemAddrBus] op2_jump_i,
    input wire[`Hold_Flag_Bus] hold_flag_i,
    output wire[`InstBus] inst_o,
    output wire[`InstAddrBus] inst_addr_o,
    output wire reg_we_o,
    output wire[`RegAddrBus] reg_waddr_o,
    output wire[`RegBus] reg1_rdata_o,
    output wire[`RegBus] reg2_rdata_o,
    output wire[`MemAddrBus] op1_o,
    output wire[`MemAddrBus] op2_o,
    output wire[`MemAddrBus] op1_jump_o,
    output wire[`MemAddrBus] op2_jump_o
    );

    wire flush_en = (hold_flag_i >= `Hold_Id) &&
                    (hold_flag_i != `Hold_Id_Keep) &&
                    (hold_flag_i != `Hold_Id_Keep_If);
    wire keep_en = (hold_flag_i == `Hold_Id_Keep) ||
                   (hold_flag_i == `Hold_Id_Keep_If);

    gen_pipe_stall_dff #(32) inst_ff(
        clk, rst, flush_en, keep_en, `INST_NOP, inst_i, inst_o
    );
    gen_pipe_stall_dff #(32) inst_addr_ff(
        clk, rst, flush_en, keep_en, `ZeroWord, inst_addr_i, inst_addr_o
    );
    gen_pipe_stall_dff #(1) reg_we_ff(
        clk, rst, flush_en, keep_en, `WriteDisable, reg_we_i, reg_we_o
    );
    gen_pipe_stall_dff #(5) reg_waddr_ff(
        clk, rst, flush_en, keep_en, `ZeroReg, reg_waddr_i, reg_waddr_o
    );
    gen_pipe_stall_dff #(32) reg1_rdata_ff(
        clk, rst, flush_en, keep_en, `ZeroWord, reg1_rdata_i, reg1_rdata_o
    );
    gen_pipe_stall_dff #(32) reg2_rdata_ff(
        clk, rst, flush_en, keep_en, `ZeroWord, reg2_rdata_i, reg2_rdata_o
    );
    gen_pipe_stall_dff #(32) op1_ff(
        clk, rst, flush_en, keep_en, `ZeroWord, op1_i, op1_o
    );
    gen_pipe_stall_dff #(32) op2_ff(
        clk, rst, flush_en, keep_en, `ZeroWord, op2_i, op2_o
    );
    gen_pipe_stall_dff #(32) op1_jump_ff(
        clk, rst, flush_en, keep_en, `ZeroWord, op1_jump_i, op1_jump_o
    );
    gen_pipe_stall_dff #(32) op2_jump_ff(
        clk, rst, flush_en, keep_en, `ZeroWord, op2_jump_i, op2_jump_o
    );

endmodule
