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

`include "wje_defs.v"



// WJE-prefixed private RTL module for the four-core integration.
module wje_ctrl(

    input wire rst,

    // from ex
    input wire jump_flag_i,
    input wire[`WJE_InstAddrBus] jump_addr_i,
    input wire hold_flag_ex_i,
    input wire hold_flag_temp_i,

    // from rib
    input wire hold_flag_rib_i,
    input wire hold_flag_mem_i,

    output reg[`WJE_Hold_Flag_Bus] hold_flag_o,

    // to pc_reg
    output reg jump_flag_o,
    output reg[`WJE_InstAddrBus] jump_addr_o

    );


    always @ (*) begin
        jump_addr_o = jump_addr_i;
        jump_flag_o = jump_flag_i;

        hold_flag_o = `WJE_Hold_None;

        if (jump_flag_i == `WJE_JumpEnable) begin

            hold_flag_o = `WJE_Hold_Id;
        end else if ((hold_flag_temp_i == `WJE_HoldEnable) || (hold_flag_mem_i == `WJE_HoldEnable)) begin
            hold_flag_o = `WJE_Hold_Mem;
        end else if (hold_flag_ex_i == `WJE_HoldEnable) begin

            hold_flag_o = `WJE_Hold_Id;
        end else if (hold_flag_rib_i == `WJE_HoldEnable) begin

            hold_flag_o = `WJE_Hold_Pc;
        end else begin
            hold_flag_o = `WJE_Hold_None;
        end
    end

endmodule
