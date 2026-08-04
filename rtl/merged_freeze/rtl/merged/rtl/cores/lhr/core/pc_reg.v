/*
 * Copyright 2019 Blue Liang, liangkangnan@163.com
 * Licensed under the Apache License, Version 2.0.
 */

`include "lhr_defs.v"

// Program counter register.
module lhr_pc_reg(
    input wire clk,
    input wire rst,
    input wire jump_flag_i,
    input wire[`LHR_InstAddrBus] jump_addr_i,
    input wire[`LHR_Hold_Flag_Bus] hold_flag_i,
    output reg[`LHR_InstAddrBus] pc_o
    );

    always @ (posedge clk) begin
        if (rst == `LHR_RstEnable) begin
            pc_o <= `LHR_CpuResetAddr;
        end else if (jump_flag_i == `LHR_JumpEnable) begin
            pc_o <= jump_addr_i;
        end else if (hold_flag_i < `LHR_Hold_Pc) begin
            pc_o <= pc_o + 32'd4;
        end
    end

endmodule
