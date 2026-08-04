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

`include "sy_defs.v"



// SY-prefixed private RTL module for the four-core integration.
module sy_ctrl(

    input wire rst,

    // from ex
    input wire jump_flag_i,
    input wire[`SY_InstAddrBus] jump_addr_i,
    input wire hold_flag_ex_i,

    // from rib
    input wire[`SY_Hold_Flag_Bus] hold_flag_rib_i,

    output reg[`SY_Hold_Flag_Bus] hold_flag_o,

    // to pc_reg
    output reg jump_flag_o,
    output reg[`SY_InstAddrBus] jump_addr_o

    );


    always @ (*) begin
        jump_addr_o = jump_addr_i;
        jump_flag_o = jump_flag_i;

        hold_flag_o = `SY_Hold_None;

        if (hold_flag_ex_i == `SY_HoldEnable) begin
            // Multi-cycle rT keeps the instruction resident in ID/EX.
            hold_flag_o = `SY_Hold_Rib;
        end else if (jump_flag_i == `SY_JumpEnable) begin

            hold_flag_o = `SY_Hold_Id;
        end else if (hold_flag_rib_i != `SY_Hold_None) begin
            hold_flag_o = hold_flag_rib_i;
        end else begin
            hold_flag_o = `SY_Hold_None;
        end
    end

endmodule
