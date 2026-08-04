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
module sy_if_id(

    input wire clk,
    input wire rst,

    input wire[`SY_InstBus] inst_i,
    input wire[`SY_InstAddrBus] inst_addr_i,

    input wire[`SY_Hold_Flag_Bus] hold_flag_i,

    output wire[`SY_InstBus] inst_o,
    output wire[`SY_InstAddrBus] inst_addr_o

    );

    wire stall_en = (hold_flag_i == `SY_Hold_Rib);
    wire flush_en = (hold_flag_i >= `SY_Hold_If) && (stall_en == 1'b0);

    wire[`SY_InstBus] inst;
    sy_gen_pipe_hold_dff #(32) inst_ff(clk, rst, stall_en, flush_en, `SY_INST_NOP, inst_i, inst);
    assign inst_o = inst;

    wire[`SY_InstAddrBus] inst_addr;
    sy_gen_pipe_hold_dff #(32) inst_addr_ff(clk, rst, stall_en, flush_en, `SY_ZeroWord, inst_addr_i, inst_addr);
    assign inst_addr_o = inst_addr;

endmodule
