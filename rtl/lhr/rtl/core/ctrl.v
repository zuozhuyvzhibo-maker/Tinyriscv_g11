/*
 * Copyright 2019 Blue Liang, liangkangnan@163.com
 * Licensed under the Apache License, Version 2.0.
 */

`include "defines.v"

// Pipeline control for execution redirects and RIB stalls.
module ctrl(
    input wire rst,
    input wire jump_flag_i,
    input wire[`InstAddrBus] jump_addr_i,
    input wire hold_flag_ex_i,
    input wire[`Hold_Flag_Bus] hold_flag_rib_i,
    output reg[`Hold_Flag_Bus] hold_flag_o,
    output reg jump_flag_o,
    output reg[`InstAddrBus] jump_addr_o
    );

    always @ (*) begin
        jump_flag_o = jump_flag_i;
        jump_addr_o = jump_addr_i;
        hold_flag_o = `Hold_None;

        if (rst == `RstEnable) begin
            jump_flag_o = `JumpDisable;
            jump_addr_o = `ZeroWord;
        end else if ((jump_flag_i == `JumpEnable) ||
                     (hold_flag_ex_i == `HoldEnable)) begin
            hold_flag_o = `Hold_Id;
        end else if (hold_flag_rib_i != `Hold_None) begin
            hold_flag_o = hold_flag_rib_i;
        end
    end

endmodule
