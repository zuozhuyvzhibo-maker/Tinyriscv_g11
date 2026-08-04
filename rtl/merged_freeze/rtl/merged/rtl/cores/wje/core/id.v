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
module wje_id(

	input wire rst,

    // from if_id
    input wire[`WJE_InstBus] inst_i,
    input wire[`WJE_InstAddrBus] inst_addr_i,

    // from regs
    input wire[`WJE_RegBus] reg1_rdata_i,
    input wire[`WJE_RegBus] reg2_rdata_i,

    // from ex
    input wire ex_jump_flag_i,

    // to regs
    output reg[`WJE_RegAddrBus] reg1_raddr_o,
    output reg[`WJE_RegAddrBus] reg2_raddr_o,

    // to ex
    output reg[`WJE_MemAddrBus] op1_o,
    output reg[`WJE_MemAddrBus] op2_o,
    output reg[`WJE_MemAddrBus] op1_jump_o,
    output reg[`WJE_MemAddrBus] op2_jump_o,
    output reg[`WJE_InstBus] inst_o,
    output reg[`WJE_InstAddrBus] inst_addr_o,
    output reg[`WJE_RegBus] reg1_rdata_o,
    output reg[`WJE_RegBus] reg2_rdata_o,
    output reg reg_we_o,
    output reg[`WJE_RegAddrBus] reg_waddr_o

    );

    wire[6:0] opcode = inst_i[6:0];
    wire[2:0] funct3 = inst_i[14:12];
    wire[6:0] funct7 = inst_i[31:25];
    wire[4:0] rd = inst_i[11:7];
    wire[4:0] rs1 = inst_i[19:15];
    wire[4:0] rs2 = inst_i[24:20];


    always @ (*) begin
        inst_o = inst_i;
        inst_addr_o = inst_addr_i;
        reg1_rdata_o = reg1_rdata_i;
        reg2_rdata_o = reg2_rdata_i;
        op1_o = `WJE_ZeroWord;
        op2_o = `WJE_ZeroWord;
        op1_jump_o = `WJE_ZeroWord;
        op2_jump_o = `WJE_ZeroWord;

        case (opcode)
            `WJE_INST_TYPE_I: begin
                case (funct3)
                    `WJE_INST_ADDI, `WJE_INST_SLTI, `WJE_INST_SLTIU, `WJE_INST_XORI, `WJE_INST_ORI, `WJE_INST_ANDI, `WJE_INST_SLLI, `WJE_INST_SRI: begin
                        reg_we_o = `WJE_WriteEnable;
                        reg_waddr_o = rd;
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = `WJE_ZeroReg;
                        op1_o = reg1_rdata_i;
                        op2_o = {{20{inst_i[31]}}, inst_i[31:20]};
                    end
                    default: begin
                        reg_we_o = `WJE_WriteDisable;
                        reg_waddr_o = `WJE_ZeroReg;
                        reg1_raddr_o = `WJE_ZeroReg;
                        reg2_raddr_o = `WJE_ZeroReg;
                    end
                endcase
            end
            `WJE_INST_TYPE_R_M: begin
                if ((funct7 == 7'b0000000) || (funct7 == 7'b0100000)) begin
                    case (funct3)
                        `WJE_INST_ADD_SUB, `WJE_INST_SLL, `WJE_INST_SLT, `WJE_INST_SLTU, `WJE_INST_XOR, `WJE_INST_SR, `WJE_INST_OR, `WJE_INST_AND: begin
                            reg_we_o = `WJE_WriteEnable;
                            reg_waddr_o = rd;
                            reg1_raddr_o = rs1;
                            reg2_raddr_o = rs2;
                            op1_o = reg1_rdata_i;
                            op2_o = reg2_rdata_i;
                        end
                        default: begin
                            reg_we_o = `WJE_WriteDisable;
                            reg_waddr_o = `WJE_ZeroReg;
                            reg1_raddr_o = `WJE_ZeroReg;
                            reg2_raddr_o = `WJE_ZeroReg;
                        end
                    endcase
                end else begin
                    reg_we_o = `WJE_WriteDisable;
                    reg_waddr_o = `WJE_ZeroReg;
                    reg1_raddr_o = `WJE_ZeroReg;
                    reg2_raddr_o = `WJE_ZeroReg;
                end
            end
            `WJE_INST_TYPE_L: begin
                case (funct3)
                    `WJE_INST_LB, `WJE_INST_LH, `WJE_INST_LW, `WJE_INST_LBU, `WJE_INST_LHU: begin
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = `WJE_ZeroReg;
                        reg_we_o = `WJE_WriteEnable;
                        reg_waddr_o = rd;
                        op1_o = reg1_rdata_i;
                        op2_o = {{20{inst_i[31]}}, inst_i[31:20]};
                    end
                    default: begin
                        reg1_raddr_o = `WJE_ZeroReg;
                        reg2_raddr_o = `WJE_ZeroReg;
                        reg_we_o = `WJE_WriteDisable;
                        reg_waddr_o = `WJE_ZeroReg;
                    end
                endcase
            end
            `WJE_INST_TYPE_S: begin
                case (funct3)
                    `WJE_INST_SB, `WJE_INST_SW, `WJE_INST_SH: begin
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = rs2;
                        reg_we_o = `WJE_WriteDisable;
                        reg_waddr_o = `WJE_ZeroReg;
                        op1_o = reg1_rdata_i;
                        op2_o = {{20{inst_i[31]}}, inst_i[31:25], inst_i[11:7]};
                    end
                    default: begin
                        reg1_raddr_o = `WJE_ZeroReg;
                        reg2_raddr_o = `WJE_ZeroReg;
                        reg_we_o = `WJE_WriteDisable;
                        reg_waddr_o = `WJE_ZeroReg;
                    end
                endcase
            end
            `WJE_INST_TYPE_B: begin
                case (funct3)
                    `WJE_INST_BEQ, `WJE_INST_BNE, `WJE_INST_BLT, `WJE_INST_BGE, `WJE_INST_BLTU, `WJE_INST_BGEU: begin
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = rs2;
                        reg_we_o = `WJE_WriteDisable;
                        reg_waddr_o = `WJE_ZeroReg;
                        op1_o = reg1_rdata_i;
                        op2_o = reg2_rdata_i;
                        op1_jump_o = inst_addr_i;
                        op2_jump_o = {{20{inst_i[31]}}, inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};
                    end
                    default: begin
                        reg1_raddr_o = `WJE_ZeroReg;
                        reg2_raddr_o = `WJE_ZeroReg;
                        reg_we_o = `WJE_WriteDisable;
                        reg_waddr_o = `WJE_ZeroReg;
                    end
                endcase
            end
            `WJE_INST_JAL: begin
                reg_we_o = `WJE_WriteEnable;
                reg_waddr_o = rd;
                reg1_raddr_o = `WJE_ZeroReg;
                reg2_raddr_o = `WJE_ZeroReg;
                op1_o = inst_addr_i;
                op2_o = 32'h4;
                op1_jump_o = inst_addr_i;
                op2_jump_o = {{12{inst_i[31]}}, inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0};
            end
            `WJE_INST_JALR: begin
                reg_we_o = `WJE_WriteEnable;
                reg1_raddr_o = rs1;
                reg2_raddr_o = `WJE_ZeroReg;
                reg_waddr_o = rd;
                op1_o = inst_addr_i;
                op2_o = 32'h4;
                op1_jump_o = reg1_rdata_i;
                op2_jump_o = {{20{inst_i[31]}}, inst_i[31:20]};
            end
            `WJE_INST_LUI: begin
                reg_we_o = `WJE_WriteEnable;
                reg_waddr_o = rd;
                reg1_raddr_o = `WJE_ZeroReg;
                reg2_raddr_o = `WJE_ZeroReg;
                op1_o = {inst_i[31:12], 12'b0};
                op2_o = `WJE_ZeroWord;
            end
            `WJE_INST_AUIPC: begin
                reg_we_o = `WJE_WriteEnable;
                reg_waddr_o = rd;
                reg1_raddr_o = `WJE_ZeroReg;
                reg2_raddr_o = `WJE_ZeroReg;
                op1_o = inst_addr_i;
                op2_o = {inst_i[31:12], 12'b0};
            end
            `WJE_INST_NOP_OP: begin
                reg_we_o = `WJE_WriteDisable;
                reg_waddr_o = `WJE_ZeroReg;
                reg1_raddr_o = `WJE_ZeroReg;
                reg2_raddr_o = `WJE_ZeroReg;
            end
            `WJE_INST_FENCE: begin
                reg_we_o = `WJE_WriteDisable;
                reg_waddr_o = `WJE_ZeroReg;
                reg1_raddr_o = `WJE_ZeroReg;
                reg2_raddr_o = `WJE_ZeroReg;
                op1_jump_o = inst_addr_i;
                op2_jump_o = 32'h4;
            end
            `WJE_INST_TYPE_CUSTOM: begin
                case (funct3)
                    `WJE_INST_SID: begin
                        reg_we_o = `WJE_WriteDisable;
                        reg_waddr_o = `WJE_ZeroReg;
                        reg1_raddr_o = `WJE_ZeroReg;
                        reg2_raddr_o = `WJE_ZeroReg;
                        op1_jump_o = inst_addr_i;
                        op2_jump_o = 32'h4;
                    end
                    `WJE_INST_RT: begin
                        reg_we_o = `WJE_WriteEnable;
                        reg_waddr_o = rd;
                        reg1_raddr_o = `WJE_ZeroReg;
                        reg2_raddr_o = `WJE_ZeroReg;
                    end
                    `WJE_INST_IF: begin
                        reg_we_o = `WJE_WriteEnable;
                        reg_waddr_o = rd;
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = 5'd31;
                        op1_o = reg1_rdata_i;
                        op2_o = {{20{inst_i[31]}}, inst_i[31:20]};
                    end
                    default: begin
                        reg_we_o = `WJE_WriteDisable;
                        reg_waddr_o = `WJE_ZeroReg;
                        reg1_raddr_o = `WJE_ZeroReg;
                        reg2_raddr_o = `WJE_ZeroReg;
                    end
                endcase
            end
            default: begin
                reg_we_o = `WJE_WriteDisable;
                reg_waddr_o = `WJE_ZeroReg;
                reg1_raddr_o = `WJE_ZeroReg;
                reg2_raddr_o = `WJE_ZeroReg;
            end
        endcase
    end

endmodule
