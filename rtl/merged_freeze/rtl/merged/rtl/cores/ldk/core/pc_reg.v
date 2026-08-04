 /*
 Copyright 2019 Blue Liang, liangkangnan@163.com

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

`include "ldk_defs.v"


// LDK-prefixed private RTL module for the four-core integration.
module ldk_pc_reg(

    input wire clk,
    input wire rst,

    input wire jump_flag_i,
    input wire[`LDK_InstAddrBus] jump_addr_i,
    input wire[`LDK_Hold_Flag_Bus] hold_flag_i,

    output reg[`LDK_InstAddrBus] pc_o

    );


    always @ (posedge clk) begin

        if (rst == `LDK_RstEnable) begin
            pc_o <= `LDK_CpuResetAddr;

        end else if (jump_flag_i == `LDK_JumpEnable) begin
            pc_o <= jump_addr_i;

        end else if (hold_flag_i >= `LDK_Hold_Pc) begin
            pc_o <= pc_o;

        end else begin
            pc_o <= pc_o + 4'h4;
        end
    end

endmodule
