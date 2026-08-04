/*
 * Copyright 2019 Blue Liang, liangkangnan@163.com
 * Licensed under the Apache License, Version 2.0.
 */

`include "lhr_defs.v"

// Pipeline control for execution redirects and RIB stalls.
module lhr_ctrl(
    input wire rst,
    input wire jump_flag_i,
    input wire[`LHR_InstAddrBus] jump_addr_i,
    input wire hold_flag_ex_i,
    input wire[`LHR_Hold_Flag_Bus] hold_flag_rib_i,
    output reg[`LHR_Hold_Flag_Bus] hold_flag_o,
    output reg jump_flag_o,
    output reg[`LHR_InstAddrBus] jump_addr_o
    );

    always @ (*) begin
        jump_flag_o = jump_flag_i;
        jump_addr_o = jump_addr_i;
        hold_flag_o = `LHR_Hold_None;

        if (rst == `LHR_RstEnable) begin
            jump_flag_o = `LHR_JumpDisable;
            jump_addr_o = `LHR_ZeroWord;
        end else if ((jump_flag_i == `LHR_JumpEnable) ||
                     (hold_flag_ex_i == `LHR_HoldEnable)) begin
            hold_flag_o = `LHR_Hold_Id;
        end else if (hold_flag_rib_i != `LHR_Hold_None) begin
            hold_flag_o = hold_flag_rib_i;
        end
    end

endmodule
