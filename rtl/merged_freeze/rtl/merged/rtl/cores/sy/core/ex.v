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
module sy_ex(

    input wire rst,

    // from id
    input wire[`SY_InstBus] inst_i,
    input wire[`SY_InstAddrBus] inst_addr_i,
    input wire reg_we_i,
    input wire[`SY_RegAddrBus] reg_waddr_i,
    input wire[`SY_RegBus] reg1_rdata_i,
    input wire[`SY_RegBus] reg2_rdata_i,
    input wire[`SY_MemAddrBus] op1_i,
    input wire[`SY_MemAddrBus] op2_i,
    input wire[`SY_MemAddrBus] op1_jump_i,
    input wire[`SY_MemAddrBus] op2_jump_i,

    // from mem
    input wire[`SY_MemBus] mem_rdata_i,
    input wire temp_busy_i,
    input wire temp_done_i,
    input wire temp_ack_error_i,
    input wire[15:0] temp_raw_i,

    // to mem
    output reg[`SY_MemBus] mem_wdata_o,
    output reg[`SY_MemAddrBus] mem_raddr_o,
    output reg[`SY_MemAddrBus] mem_waddr_o,
    output wire mem_we_o,
    output wire mem_req_o,
    output wire[3:0] mem_byte_en_o,
    output wire temp_req_o,
    output wire temp_accept_o,

    // to regs
    output wire[`SY_RegBus] reg_wdata_o,
    output wire reg_we_o,
    output wire[`SY_RegAddrBus] reg_waddr_o,

    // to ctrl
    output wire hold_flag_o,
    output wire jump_flag_o,
    output wire[`SY_InstAddrBus] jump_addr_o

    );

    wire[1:0] mem_raddr_index;
    wire[1:0] mem_waddr_index;
    wire[31:0] sr_shift;
    wire[31:0] sri_shift;
    wire[31:0] sr_shift_mask;
    wire[31:0] sri_shift_mask;
    wire[31:0] op1_add_op2_res;
    wire[31:0] op1_add_imm_res;
    wire[31:0] op1_jump_add_op2_jump_res;
    wire op1_ge_op2_signed;
    wire op1_ge_op2_unsigned;
    wire op1_eq_op2;
    wire[6:0] opcode;
    wire[2:0] funct3;
    wire[6:0] funct7;
    wire[4:0] rd;
    wire[11:0] imm;
    reg[`SY_RegBus] reg_wdata;
    reg reg_we;
    reg[`SY_RegAddrBus] reg_waddr;
    reg hold_flag;
    reg jump_flag;
    reg[`SY_InstAddrBus] jump_addr;
    reg mem_we;
    reg mem_req;
    reg[3:0] mem_byte_en;
    reg temp_req;
    reg temp_accept;

    assign opcode = inst_i[6:0];
    assign funct3 = inst_i[14:12];
    assign funct7 = inst_i[31:25];
    assign rd = inst_i[11:7];
    assign imm = inst_i[31:20];

    assign sr_shift = reg1_rdata_i >> reg2_rdata_i[4:0];
    assign sri_shift = reg1_rdata_i >> inst_i[24:20];
    assign sr_shift_mask = 32'hffffffff >> reg2_rdata_i[4:0];
    assign sri_shift_mask = 32'hffffffff >> inst_i[24:20];

    assign op1_add_op2_res = op1_i + op2_i;
    assign op1_jump_add_op2_jump_res = op1_jump_i + op2_jump_i;
    assign op1_add_imm_res = op1_i + {{20{imm[11]}}, imm};


    assign op1_ge_op2_signed = $signed(op1_i) >= $signed(op2_i);

    assign op1_ge_op2_unsigned = op1_i >= op2_i;
    assign op1_eq_op2 = (op1_i == op2_i);

    assign mem_raddr_index = (reg1_rdata_i + {{20{inst_i[31]}}, inst_i[31:20]}) & 2'b11;
    assign mem_waddr_index = (reg1_rdata_i + {{20{inst_i[31]}}, inst_i[31:25], inst_i[11:7]}) & 2'b11;

    assign reg_wdata_o = reg_wdata;
    assign reg_we_o = reg_we;
    assign reg_waddr_o = reg_waddr;

    assign mem_we_o = mem_we;
    assign mem_req_o = mem_req;
    assign mem_byte_en_o = mem_byte_en;
    assign temp_req_o = temp_req;
    assign temp_accept_o = temp_accept;

    assign hold_flag_o = hold_flag;
    assign jump_flag_o = jump_flag;
    assign jump_addr_o = jump_addr;
    always @ (*) begin
        reg_we = reg_we_i;
        reg_waddr = reg_waddr_i;
        mem_req = `SY_RIB_NREQ;
        mem_byte_en = 4'b1111;
        temp_req = 1'b0;
        temp_accept = 1'b0;
        case (opcode)
            `SY_INST_TYPE_I: begin
                case (funct3)
                    `SY_INST_ADDI: begin
                        jump_flag = `SY_JumpDisable;
                        hold_flag = `SY_HoldDisable;
                        jump_addr = `SY_ZeroWord;
                        mem_wdata_o = `SY_ZeroWord;
                        mem_raddr_o = `SY_ZeroWord;
                        mem_waddr_o = `SY_ZeroWord;
                        mem_we = `SY_WriteDisable;
                        reg_wdata = op1_add_op2_res;
                    end
                    `SY_INST_SLTI: begin
                        jump_flag = `SY_JumpDisable;
                        hold_flag = `SY_HoldDisable;
                        jump_addr = `SY_ZeroWord;
                        mem_wdata_o = `SY_ZeroWord;
                        mem_raddr_o = `SY_ZeroWord;
                        mem_waddr_o = `SY_ZeroWord;
                        mem_we = `SY_WriteDisable;
                        reg_wdata = {32{(~op1_ge_op2_signed)}} & 32'h1;
                    end
                    `SY_INST_SLTIU: begin
                        jump_flag = `SY_JumpDisable;
                        hold_flag = `SY_HoldDisable;
                        jump_addr = `SY_ZeroWord;
                        mem_wdata_o = `SY_ZeroWord;
                        mem_raddr_o = `SY_ZeroWord;
                        mem_waddr_o = `SY_ZeroWord;
                        mem_we = `SY_WriteDisable;
                        reg_wdata = {32{(~op1_ge_op2_unsigned)}} & 32'h1;
                    end
                    `SY_INST_XORI: begin
                        jump_flag = `SY_JumpDisable;
                        hold_flag = `SY_HoldDisable;
                        jump_addr = `SY_ZeroWord;
                        mem_wdata_o = `SY_ZeroWord;
                        mem_raddr_o = `SY_ZeroWord;
                        mem_waddr_o = `SY_ZeroWord;
                        mem_we = `SY_WriteDisable;
                        reg_wdata = op1_i ^ op2_i;
                    end
                    `SY_INST_ORI: begin
                        jump_flag = `SY_JumpDisable;
                        hold_flag = `SY_HoldDisable;
                        jump_addr = `SY_ZeroWord;
                        mem_wdata_o = `SY_ZeroWord;
                        mem_raddr_o = `SY_ZeroWord;
                        mem_waddr_o = `SY_ZeroWord;
                        mem_we = `SY_WriteDisable;
                        reg_wdata = op1_i | op2_i;
                    end
                    `SY_INST_ANDI: begin
                        jump_flag = `SY_JumpDisable;
                        hold_flag = `SY_HoldDisable;
                        jump_addr = `SY_ZeroWord;
                        mem_wdata_o = `SY_ZeroWord;
                        mem_raddr_o = `SY_ZeroWord;
                        mem_waddr_o = `SY_ZeroWord;
                        mem_we = `SY_WriteDisable;
                        reg_wdata = op1_i & op2_i;
                    end
                    `SY_INST_SLLI: begin
                        jump_flag = `SY_JumpDisable;
                        hold_flag = `SY_HoldDisable;
                        jump_addr = `SY_ZeroWord;
                        mem_wdata_o = `SY_ZeroWord;
                        mem_raddr_o = `SY_ZeroWord;
                        mem_waddr_o = `SY_ZeroWord;
                        mem_we = `SY_WriteDisable;
                        reg_wdata = reg1_rdata_i << inst_i[24:20];
                    end
                    `SY_INST_SRI: begin
                        jump_flag = `SY_JumpDisable;
                        hold_flag = `SY_HoldDisable;
                        jump_addr = `SY_ZeroWord;
                        mem_wdata_o = `SY_ZeroWord;
                        mem_raddr_o = `SY_ZeroWord;
                        mem_waddr_o = `SY_ZeroWord;
                        mem_we = `SY_WriteDisable;
                        if (inst_i[30] == 1'b1) begin
                            reg_wdata = (sri_shift & sri_shift_mask) | ({32{reg1_rdata_i[31]}} & (~sri_shift_mask));
                        end else begin
                            reg_wdata = reg1_rdata_i >> inst_i[24:20];
                        end
                    end
                    default: begin
                        jump_flag = `SY_JumpDisable;
                        hold_flag = `SY_HoldDisable;
                        jump_addr = `SY_ZeroWord;
                        mem_wdata_o = `SY_ZeroWord;
                        mem_raddr_o = `SY_ZeroWord;
                        mem_waddr_o = `SY_ZeroWord;
                        mem_we = `SY_WriteDisable;
                        reg_wdata = `SY_ZeroWord;
                    end
                endcase
            end
            `SY_INST_TYPE_R_M: begin
                if ((funct7 == 7'b0000000) || (funct7 == 7'b0100000)) begin
                    case (funct3)
                        `SY_INST_ADD_SUB: begin
                            jump_flag = `SY_JumpDisable;
                            hold_flag = `SY_HoldDisable;
                            jump_addr = `SY_ZeroWord;
                            mem_wdata_o = `SY_ZeroWord;
                            mem_raddr_o = `SY_ZeroWord;
                            mem_waddr_o = `SY_ZeroWord;
                            mem_we = `SY_WriteDisable;
                            if (inst_i[30] == 1'b0) begin
                                reg_wdata = op1_add_op2_res;
                            end else begin
                                reg_wdata = op1_i - op2_i;
                            end
                        end
                        `SY_INST_SLL: begin
                            jump_flag = `SY_JumpDisable;
                            hold_flag = `SY_HoldDisable;
                            jump_addr = `SY_ZeroWord;
                            mem_wdata_o = `SY_ZeroWord;
                            mem_raddr_o = `SY_ZeroWord;
                            mem_waddr_o = `SY_ZeroWord;
                            mem_we = `SY_WriteDisable;
                            reg_wdata = op1_i << op2_i[4:0];
                        end
                        `SY_INST_SLT: begin
                            jump_flag = `SY_JumpDisable;
                            hold_flag = `SY_HoldDisable;
                            jump_addr = `SY_ZeroWord;
                            mem_wdata_o = `SY_ZeroWord;
                            mem_raddr_o = `SY_ZeroWord;
                            mem_waddr_o = `SY_ZeroWord;
                            mem_we = `SY_WriteDisable;
                            reg_wdata = {32{(~op1_ge_op2_signed)}} & 32'h1;
                        end
                        `SY_INST_SLTU: begin
                            jump_flag = `SY_JumpDisable;
                            hold_flag = `SY_HoldDisable;
                            jump_addr = `SY_ZeroWord;
                            mem_wdata_o = `SY_ZeroWord;
                            mem_raddr_o = `SY_ZeroWord;
                            mem_waddr_o = `SY_ZeroWord;
                            mem_we = `SY_WriteDisable;
                            reg_wdata = {32{(~op1_ge_op2_unsigned)}} & 32'h1;
                        end
                        `SY_INST_XOR: begin
                            jump_flag = `SY_JumpDisable;
                            hold_flag = `SY_HoldDisable;
                            jump_addr = `SY_ZeroWord;
                            mem_wdata_o = `SY_ZeroWord;
                            mem_raddr_o = `SY_ZeroWord;
                            mem_waddr_o = `SY_ZeroWord;
                            mem_we = `SY_WriteDisable;
                            reg_wdata = op1_i ^ op2_i;
                        end
                        `SY_INST_SR: begin
                            jump_flag = `SY_JumpDisable;
                            hold_flag = `SY_HoldDisable;
                            jump_addr = `SY_ZeroWord;
                            mem_wdata_o = `SY_ZeroWord;
                            mem_raddr_o = `SY_ZeroWord;
                            mem_waddr_o = `SY_ZeroWord;
                            mem_we = `SY_WriteDisable;
                            if (inst_i[30] == 1'b1) begin
                                reg_wdata = (sr_shift & sr_shift_mask) | ({32{reg1_rdata_i[31]}} & (~sr_shift_mask));
                            end else begin
                                reg_wdata = reg1_rdata_i >> reg2_rdata_i[4:0];
                            end
                        end
                        `SY_INST_OR: begin
                            jump_flag = `SY_JumpDisable;
                            hold_flag = `SY_HoldDisable;
                            jump_addr = `SY_ZeroWord;
                            mem_wdata_o = `SY_ZeroWord;
                            mem_raddr_o = `SY_ZeroWord;
                            mem_waddr_o = `SY_ZeroWord;
                            mem_we = `SY_WriteDisable;
                            reg_wdata = op1_i | op2_i;
                        end
                        `SY_INST_AND: begin
                            jump_flag = `SY_JumpDisable;
                            hold_flag = `SY_HoldDisable;
                            jump_addr = `SY_ZeroWord;
                            mem_wdata_o = `SY_ZeroWord;
                            mem_raddr_o = `SY_ZeroWord;
                            mem_waddr_o = `SY_ZeroWord;
                            mem_we = `SY_WriteDisable;
                            reg_wdata = op1_i & op2_i;
                        end
                        default: begin
                            jump_flag = `SY_JumpDisable;
                            hold_flag = `SY_HoldDisable;
                            jump_addr = `SY_ZeroWord;
                            mem_wdata_o = `SY_ZeroWord;
                            mem_raddr_o = `SY_ZeroWord;
                            mem_waddr_o = `SY_ZeroWord;
                            mem_we = `SY_WriteDisable;
                            reg_wdata = `SY_ZeroWord;
                        end
                    endcase
                end else begin
                    jump_flag = `SY_JumpDisable;
                    hold_flag = `SY_HoldDisable;
                    jump_addr = `SY_ZeroWord;
                    mem_wdata_o = `SY_ZeroWord;
                    mem_raddr_o = `SY_ZeroWord;
                    mem_waddr_o = `SY_ZeroWord;
                    mem_we = `SY_WriteDisable;
                    reg_wdata = `SY_ZeroWord;
                end
            end
            `SY_INST_TYPE_L: begin
                case (funct3)
                    `SY_INST_LB: begin
                        jump_flag = `SY_JumpDisable;
                        hold_flag = `SY_HoldDisable;
                        jump_addr = `SY_ZeroWord;
                        mem_wdata_o = `SY_ZeroWord;
                        mem_waddr_o = `SY_ZeroWord;
                        mem_we = `SY_WriteDisable;
                        mem_req = `SY_RIB_REQ;
                        mem_raddr_o = op1_add_op2_res;
                        case (mem_raddr_index)
                            2'b00: begin
                                reg_wdata = {{24{mem_rdata_i[7]}}, mem_rdata_i[7:0]};
                            end
                            2'b01: begin
                                reg_wdata = {{24{mem_rdata_i[15]}}, mem_rdata_i[15:8]};
                            end
                            2'b10: begin
                                reg_wdata = {{24{mem_rdata_i[23]}}, mem_rdata_i[23:16]};
                            end
                            default: begin
                                reg_wdata = {{24{mem_rdata_i[31]}}, mem_rdata_i[31:24]};
                            end
                        endcase
                    end
                    `SY_INST_LH: begin
                        jump_flag = `SY_JumpDisable;
                        hold_flag = `SY_HoldDisable;
                        jump_addr = `SY_ZeroWord;
                        mem_wdata_o = `SY_ZeroWord;
                        mem_waddr_o = `SY_ZeroWord;
                        mem_we = `SY_WriteDisable;
                        mem_req = `SY_RIB_REQ;
                        mem_raddr_o = op1_add_op2_res;
                        if (mem_raddr_index == 2'b0) begin
                            reg_wdata = {{16{mem_rdata_i[15]}}, mem_rdata_i[15:0]};
                        end else begin
                            reg_wdata = {{16{mem_rdata_i[31]}}, mem_rdata_i[31:16]};
                        end
                    end
                    `SY_INST_LW: begin
                        jump_flag = `SY_JumpDisable;
                        hold_flag = `SY_HoldDisable;
                        jump_addr = `SY_ZeroWord;
                        mem_wdata_o = `SY_ZeroWord;
                        mem_waddr_o = `SY_ZeroWord;
                        mem_we = `SY_WriteDisable;
                        mem_req = `SY_RIB_REQ;
                        mem_raddr_o = op1_add_op2_res;
                        reg_wdata = mem_rdata_i;
                    end
                    `SY_INST_LBU: begin
                        jump_flag = `SY_JumpDisable;
                        hold_flag = `SY_HoldDisable;
                        jump_addr = `SY_ZeroWord;
                        mem_wdata_o = `SY_ZeroWord;
                        mem_waddr_o = `SY_ZeroWord;
                        mem_we = `SY_WriteDisable;
                        mem_req = `SY_RIB_REQ;
                        mem_raddr_o = op1_add_op2_res;
                        case (mem_raddr_index)
                            2'b00: begin
                                reg_wdata = {24'h0, mem_rdata_i[7:0]};
                            end
                            2'b01: begin
                                reg_wdata = {24'h0, mem_rdata_i[15:8]};
                            end
                            2'b10: begin
                                reg_wdata = {24'h0, mem_rdata_i[23:16]};
                            end
                            default: begin
                                reg_wdata = {24'h0, mem_rdata_i[31:24]};
                            end
                        endcase
                    end
                    `SY_INST_LHU: begin
                        jump_flag = `SY_JumpDisable;
                        hold_flag = `SY_HoldDisable;
                        jump_addr = `SY_ZeroWord;
                        mem_wdata_o = `SY_ZeroWord;
                        mem_waddr_o = `SY_ZeroWord;
                        mem_we = `SY_WriteDisable;
                        mem_req = `SY_RIB_REQ;
                        mem_raddr_o = op1_add_op2_res;
                        if (mem_raddr_index == 2'b0) begin
                            reg_wdata = {16'h0, mem_rdata_i[15:0]};
                        end else begin
                            reg_wdata = {16'h0, mem_rdata_i[31:16]};
                        end
                    end
                    default: begin
                        jump_flag = `SY_JumpDisable;
                        hold_flag = `SY_HoldDisable;
                        jump_addr = `SY_ZeroWord;
                        mem_wdata_o = `SY_ZeroWord;
                        mem_raddr_o = `SY_ZeroWord;
                        mem_waddr_o = `SY_ZeroWord;
                        mem_we = `SY_WriteDisable;
                        reg_wdata = `SY_ZeroWord;
                    end
                endcase
            end
            `SY_INST_TYPE_S: begin
                case (funct3)
                    `SY_INST_SB: begin
                        jump_flag = `SY_JumpDisable;
                        hold_flag = `SY_HoldDisable;
                        jump_addr = `SY_ZeroWord;
                        reg_wdata = `SY_ZeroWord;
                        mem_we = `SY_WriteEnable;
                        mem_req = `SY_RIB_REQ;
                        mem_waddr_o = op1_add_op2_res;
                        mem_raddr_o = op1_add_op2_res;
                        case (mem_waddr_index)
                            2'b00: begin
                                mem_wdata_o = {24'h0, reg2_rdata_i[7:0]};
                                mem_byte_en = 4'b0001;
                            end
                            2'b01: begin
                                mem_wdata_o = {16'h0, reg2_rdata_i[7:0], 8'h0};
                                mem_byte_en = 4'b0010;
                            end
                            2'b10: begin
                                mem_wdata_o = {8'h0, reg2_rdata_i[7:0], 16'h0};
                                mem_byte_en = 4'b0100;
                            end
                            default: begin
                                mem_wdata_o = {reg2_rdata_i[7:0], 24'h0};
                                mem_byte_en = 4'b1000;
                            end
                        endcase
                    end
                    `SY_INST_SH: begin
                        jump_flag = `SY_JumpDisable;
                        hold_flag = `SY_HoldDisable;
                        jump_addr = `SY_ZeroWord;
                        reg_wdata = `SY_ZeroWord;
                        mem_we = `SY_WriteEnable;
                        mem_req = `SY_RIB_REQ;
                        mem_waddr_o = op1_add_op2_res;
                        mem_raddr_o = op1_add_op2_res;
                        if (mem_waddr_index == 2'b00) begin
                            mem_wdata_o = {16'h0, reg2_rdata_i[15:0]};
                            mem_byte_en = 4'b0011;
                        end else begin
                            mem_wdata_o = {reg2_rdata_i[15:0], 16'h0};
                            mem_byte_en = 4'b1100;
                        end
                    end
                    `SY_INST_SW: begin
                        jump_flag = `SY_JumpDisable;
                        hold_flag = `SY_HoldDisable;
                        jump_addr = `SY_ZeroWord;
                        reg_wdata = `SY_ZeroWord;
                        mem_we = `SY_WriteEnable;
                        mem_req = `SY_RIB_REQ;
                        mem_waddr_o = op1_add_op2_res;
                        mem_raddr_o = op1_add_op2_res;
                        mem_wdata_o = reg2_rdata_i;
                    end
                    default: begin
                        jump_flag = `SY_JumpDisable;
                        hold_flag = `SY_HoldDisable;
                        jump_addr = `SY_ZeroWord;
                        mem_wdata_o = `SY_ZeroWord;
                        mem_raddr_o = `SY_ZeroWord;
                        mem_waddr_o = `SY_ZeroWord;
                        mem_we = `SY_WriteDisable;
                        reg_wdata = `SY_ZeroWord;
                    end
                endcase
            end
            `SY_INST_TYPE_B: begin
                case (funct3)
                    `SY_INST_BEQ: begin
                        hold_flag = `SY_HoldDisable;
                        mem_wdata_o = `SY_ZeroWord;
                        mem_raddr_o = `SY_ZeroWord;
                        mem_waddr_o = `SY_ZeroWord;
                        mem_we = `SY_WriteDisable;
                        reg_wdata = `SY_ZeroWord;
                        jump_flag = op1_eq_op2 & `SY_JumpEnable;
                        jump_addr = {32{op1_eq_op2}} & op1_jump_add_op2_jump_res;
                    end
                    `SY_INST_BNE: begin
                        hold_flag = `SY_HoldDisable;
                        mem_wdata_o = `SY_ZeroWord;
                        mem_raddr_o = `SY_ZeroWord;
                        mem_waddr_o = `SY_ZeroWord;
                        mem_we = `SY_WriteDisable;
                        reg_wdata = `SY_ZeroWord;
                        jump_flag = (~op1_eq_op2) & `SY_JumpEnable;
                        jump_addr = {32{(~op1_eq_op2)}} & op1_jump_add_op2_jump_res;
                    end
                    `SY_INST_BLT: begin
                        hold_flag = `SY_HoldDisable;
                        mem_wdata_o = `SY_ZeroWord;
                        mem_raddr_o = `SY_ZeroWord;
                        mem_waddr_o = `SY_ZeroWord;
                        mem_we = `SY_WriteDisable;
                        reg_wdata = `SY_ZeroWord;
                        jump_flag = (~op1_ge_op2_signed) & `SY_JumpEnable;
                        jump_addr = {32{(~op1_ge_op2_signed)}} & op1_jump_add_op2_jump_res;
                    end
                    `SY_INST_BGE: begin
                        hold_flag = `SY_HoldDisable;
                        mem_wdata_o = `SY_ZeroWord;
                        mem_raddr_o = `SY_ZeroWord;
                        mem_waddr_o = `SY_ZeroWord;
                        mem_we = `SY_WriteDisable;
                        reg_wdata = `SY_ZeroWord;
                        jump_flag = (op1_ge_op2_signed) & `SY_JumpEnable;
                        jump_addr = {32{(op1_ge_op2_signed)}} & op1_jump_add_op2_jump_res;
                    end
                    `SY_INST_BLTU: begin
                        hold_flag = `SY_HoldDisable;
                        mem_wdata_o = `SY_ZeroWord;
                        mem_raddr_o = `SY_ZeroWord;
                        mem_waddr_o = `SY_ZeroWord;
                        mem_we = `SY_WriteDisable;
                        reg_wdata = `SY_ZeroWord;
                        jump_flag = (~op1_ge_op2_unsigned) & `SY_JumpEnable;
                        jump_addr = {32{(~op1_ge_op2_unsigned)}} & op1_jump_add_op2_jump_res;
                    end
                    `SY_INST_BGEU: begin
                        hold_flag = `SY_HoldDisable;
                        mem_wdata_o = `SY_ZeroWord;
                        mem_raddr_o = `SY_ZeroWord;
                        mem_waddr_o = `SY_ZeroWord;
                        mem_we = `SY_WriteDisable;
                        reg_wdata = `SY_ZeroWord;
                        jump_flag = (op1_ge_op2_unsigned) & `SY_JumpEnable;
                        jump_addr = {32{(op1_ge_op2_unsigned)}} & op1_jump_add_op2_jump_res;
                    end
                    default: begin
                        jump_flag = `SY_JumpDisable;
                        hold_flag = `SY_HoldDisable;
                        jump_addr = `SY_ZeroWord;
                        mem_wdata_o = `SY_ZeroWord;
                        mem_raddr_o = `SY_ZeroWord;
                        mem_waddr_o = `SY_ZeroWord;
                        mem_we = `SY_WriteDisable;
                        reg_wdata = `SY_ZeroWord;
                    end
                endcase
            end
            `SY_INST_JAL, `SY_INST_JALR: begin
                hold_flag = `SY_HoldDisable;
                mem_wdata_o = `SY_ZeroWord;
                mem_raddr_o = `SY_ZeroWord;
                mem_waddr_o = `SY_ZeroWord;
                mem_we = `SY_WriteDisable;
                jump_flag = `SY_JumpEnable;
                jump_addr = op1_jump_add_op2_jump_res;
                reg_wdata = op1_add_op2_res;
            end
            `SY_INST_LUI, `SY_INST_AUIPC: begin
                hold_flag = `SY_HoldDisable;
                mem_wdata_o = `SY_ZeroWord;
                mem_raddr_o = `SY_ZeroWord;
                mem_waddr_o = `SY_ZeroWord;
                mem_we = `SY_WriteDisable;
                jump_addr = `SY_ZeroWord;
                jump_flag = `SY_JumpDisable;
                reg_wdata = op1_add_op2_res;
            end
            `SY_INST_NOP_OP: begin
                jump_flag = `SY_JumpDisable;
                hold_flag = `SY_HoldDisable;
                jump_addr = `SY_ZeroWord;
                mem_wdata_o = `SY_ZeroWord;
                mem_raddr_o = `SY_ZeroWord;
                mem_waddr_o = `SY_ZeroWord;
                mem_we = `SY_WriteDisable;
                reg_wdata = `SY_ZeroWord;
            end
            `SY_INST_FENCE: begin
                hold_flag = `SY_HoldDisable;
                mem_wdata_o = `SY_ZeroWord;
                mem_raddr_o = `SY_ZeroWord;
                mem_waddr_o = `SY_ZeroWord;
                mem_we = `SY_WriteDisable;
                reg_wdata = `SY_ZeroWord;
                jump_flag = `SY_JumpEnable;
                jump_addr = op1_jump_add_op2_jump_res;
            end
            `SY_INST_EXT: begin
                case (funct3)
                    `SY_INST_EXTSID: begin
                        jump_flag = `SY_JumpDisable;
                        hold_flag = `SY_HoldDisable;
                        jump_addr = `SY_ZeroWord;
                        reg_wdata = `SY_ZeroWord;
                        mem_we = `SY_WriteEnable;
                        mem_req = `SY_RIB_REQ;
                        // write certain information to extend register in UART
                        mem_waddr_o = `SY_UART_EXTREG;
                        mem_raddr_o = `SY_UART_EXTREG;
                        mem_wdata_o = {30'b0, `SY_UART_SIDFLG};
                    end
                    `SY_INST_EXTRT: begin
                        jump_flag = `SY_JumpDisable;
                        jump_addr = `SY_ZeroWord;
                        mem_wdata_o = `SY_ZeroWord;
                        mem_waddr_o = `SY_ZeroWord;
                        mem_we = `SY_WriteDisable;
                        mem_req = `SY_RIB_NREQ;
                        mem_raddr_o = `SY_ZeroWord;
                        reg_waddr = reg_waddr_i;
                        if (temp_done_i == 1'b1) begin
                            hold_flag = `SY_HoldDisable;
                            temp_accept = 1'b1;
                            reg_we = `SY_WriteEnable;
                            reg_wdata = temp_ack_error_i ? `SY_ZeroWord :
                                        {24'h0, temp_raw_i[14:7]};
                        end else begin
                            hold_flag = `SY_HoldEnable;
                            temp_req = (temp_busy_i == 1'b0);
                            reg_we = `SY_WriteDisable;
                            reg_wdata = `SY_ZeroWord;
                        end
                    end
                    `SY_INST_EXTIF: begin
                        jump_flag = `SY_JumpDisable;
                        hold_flag = `SY_HoldDisable;
                        jump_addr = `SY_ZeroWord;
                        if (imm == 12'b0) begin
                            if (op1_ge_op2_unsigned) begin
                                // UART send certain value
                                mem_req = `SY_RIB_REQ;
                                mem_wdata_o = {24'b0, op1_i[7:0]};
                                mem_raddr_o = `SY_UART_DATREG;
                                mem_waddr_o = `SY_UART_DATREG;
                                mem_we = `SY_WriteEnable;
                                reg_wdata = `SY_ZeroWord;
                            end else begin
                                mem_wdata_o = `SY_ZeroWord;
                                mem_raddr_o = `SY_ZeroWord;
                                mem_waddr_o = `SY_ZeroWord;
                                mem_we = `SY_WriteDisable;
                                reg_wdata = op1_i;
                            end
                        end else begin
                            mem_wdata_o = `SY_ZeroWord;
                            mem_raddr_o = `SY_ZeroWord;
                            mem_waddr_o = `SY_ZeroWord;
                            mem_we = `SY_WriteDisable;
                            reg_wdata = op1_add_imm_res;
                        end
                    end
                    default: begin
                        jump_flag = `SY_JumpDisable;
                        hold_flag = `SY_HoldDisable;
                        jump_addr = `SY_ZeroWord;
                        mem_wdata_o = `SY_ZeroWord;
                        mem_raddr_o = `SY_ZeroWord;
                        mem_waddr_o = `SY_ZeroWord;
                        mem_we = `SY_WriteDisable;
                        reg_wdata = `SY_ZeroWord;
                    end
                endcase
            end
            default: begin
                jump_flag = `SY_JumpDisable;
                hold_flag = `SY_HoldDisable;
                jump_addr = `SY_ZeroWord;
                mem_wdata_o = `SY_ZeroWord;
                mem_raddr_o = `SY_ZeroWord;
                mem_waddr_o = `SY_ZeroWord;
                mem_we = `SY_WriteDisable;
                reg_wdata = `SY_ZeroWord;
            end
        endcase
    end

endmodule
