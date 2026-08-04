 /*
 Copyright 2020 Blue Liang, liangkangnan@163.com

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
module ldk_id_ex(

    input wire clk,
    input wire rst,

    input wire[`LDK_InstBus] inst_i,
    input wire[`LDK_InstAddrBus] inst_addr_i,
    input wire reg_we_i,
    input wire[`LDK_RegAddrBus] reg_waddr_i,
    input wire[`LDK_RegBus] reg1_rdata_i,
    input wire[`LDK_RegBus] reg2_rdata_i,
    input wire[`LDK_MemAddrBus] op1_i,
    input wire[`LDK_MemAddrBus] op2_i,
    input wire[`LDK_MemAddrBus] op1_jump_i,
    input wire[`LDK_MemAddrBus] op2_jump_i,

    input wire[`LDK_Hold_Flag_Bus] hold_flag_i,

    output wire[`LDK_MemAddrBus] op1_o,
    output wire[`LDK_MemAddrBus] op2_o,
    output wire[`LDK_MemAddrBus] op1_jump_o,
    output wire[`LDK_MemAddrBus] op2_jump_o,
    output wire[`LDK_InstBus] inst_o,
    output wire[`LDK_InstAddrBus] inst_addr_o,
    output wire reg_we_o,
    output wire[`LDK_RegAddrBus] reg_waddr_o,
    output wire[`LDK_RegBus] reg1_rdata_o,
    output wire[`LDK_RegBus] reg2_rdata_o

    );

    wire hold_en = (hold_flag_i >= `LDK_Hold_Id);

    wire[`LDK_InstBus] inst;
    ldk_gen_pipe_dk #(32) inst_ff(clk, rst, hold_en, `LDK_INST_NOP, inst_i, inst);
    assign inst_o = inst;

    wire[`LDK_InstAddrBus] inst_addr;
    ldk_gen_pipe_dk #(32) inst_addr_ff(clk, rst, hold_en, `LDK_ZeroWord, inst_addr_i, inst_addr);
    assign inst_addr_o = inst_addr;

    wire reg_we;
    ldk_gen_pipe_dk #(1) reg_we_ff(clk, rst, hold_en, `LDK_WriteDisable, reg_we_i, reg_we);
    assign reg_we_o = reg_we;

    wire[`LDK_RegAddrBus] reg_waddr;
    ldk_gen_pipe_dk #(5) reg_waddr_ff(clk, rst, hold_en, `LDK_ZeroReg, reg_waddr_i, reg_waddr);
    assign reg_waddr_o = reg_waddr;

    wire[`LDK_RegBus] reg1_rdata;
    ldk_gen_pipe_dk #(32) reg1_rdata_ff(clk, rst, hold_en, `LDK_ZeroWord, reg1_rdata_i, reg1_rdata);
    assign reg1_rdata_o = reg1_rdata;

    wire[`LDK_RegBus] reg2_rdata;
    ldk_gen_pipe_dk #(32) reg2_rdata_ff(clk, rst, hold_en, `LDK_ZeroWord, reg2_rdata_i, reg2_rdata);
    assign reg2_rdata_o = reg2_rdata;

    wire[`LDK_MemAddrBus] op1;
    ldk_gen_pipe_dk #(32) op1_ff(clk, rst, hold_en, `LDK_ZeroWord, op1_i, op1);
    assign op1_o = op1;

    wire[`LDK_MemAddrBus] op2;
    ldk_gen_pipe_dk #(32) op2_ff(clk, rst, hold_en, `LDK_ZeroWord, op2_i, op2);
    assign op2_o = op2;

    wire[`LDK_MemAddrBus] op1_jump;
    ldk_gen_pipe_dk #(32) op1_jump_ff(clk, rst, hold_en, `LDK_ZeroWord, op1_jump_i, op1_jump);
    assign op1_jump_o = op1_jump;

    wire[`LDK_MemAddrBus] op2_jump;
    ldk_gen_pipe_dk #(32) op2_jump_ff(clk, rst, hold_en, `LDK_ZeroWord, op2_jump_i, op2_jump);
    assign op2_jump_o = op2_jump;

endmodule
