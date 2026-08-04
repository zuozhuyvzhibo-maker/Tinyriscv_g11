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
module sy_id(

	input wire rst,

    // from if_id
    input wire[`SY_InstBus] inst_i,
    input wire[`SY_InstAddrBus] inst_addr_i,

    // from regs
    input wire[`SY_RegBus] reg1_rdata_i,
    input wire[`SY_RegBus] reg2_rdata_i,

    // from ex
    input wire ex_jump_flag_i,

    // to regs
    output reg[`SY_RegAddrBus] reg1_raddr_o,
    output reg[`SY_RegAddrBus] reg2_raddr_o,

    // to ex
    output reg[`SY_MemAddrBus] op1_o,
    output reg[`SY_MemAddrBus] op2_o,
    output reg[`SY_MemAddrBus] op1_jump_o,
    output reg[`SY_MemAddrBus] op2_jump_o,
    output reg[`SY_InstBus] inst_o,
    output reg[`SY_InstAddrBus] inst_addr_o,
    output reg[`SY_RegBus] reg1_rdata_o,
    output reg[`SY_RegBus] reg2_rdata_o,
    output reg reg_we_o,
    output reg[`SY_RegAddrBus] reg_waddr_o

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
        op1_o = `SY_ZeroWord;
        op2_o = `SY_ZeroWord;
        op1_jump_o = `SY_ZeroWord;
        op2_jump_o = `SY_ZeroWord;

        case (opcode)
            `SY_INST_TYPE_I: begin
                case (funct3)
                    `SY_INST_ADDI, `SY_INST_SLTI, `SY_INST_SLTIU, `SY_INST_XORI, `SY_INST_ORI, `SY_INST_ANDI, `SY_INST_SLLI, `SY_INST_SRI: begin
                        reg_we_o = `SY_WriteEnable;
                        reg_waddr_o = rd;
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = `SY_ZeroReg;
                        op1_o = reg1_rdata_i;
                        op2_o = {{20{inst_i[31]}}, inst_i[31:20]};
                    end
                    default: begin
                        reg_we_o = `SY_WriteDisable;
                        reg_waddr_o = `SY_ZeroReg;
                        reg1_raddr_o = `SY_ZeroReg;
                        reg2_raddr_o = `SY_ZeroReg;
                    end
                endcase
            end
            `SY_INST_TYPE_R_M: begin
                if ((funct7 == 7'b0000000) || (funct7 == 7'b0100000)) begin
                    case (funct3)
                        `SY_INST_ADD_SUB, `SY_INST_SLL, `SY_INST_SLT, `SY_INST_SLTU, `SY_INST_XOR, `SY_INST_SR, `SY_INST_OR, `SY_INST_AND: begin
                            reg_we_o = `SY_WriteEnable;
                            reg_waddr_o = rd;
                            reg1_raddr_o = rs1;
                            reg2_raddr_o = rs2;
                            op1_o = reg1_rdata_i;
                            op2_o = reg2_rdata_i;
                        end
                        default: begin
                            reg_we_o = `SY_WriteDisable;
                            reg_waddr_o = `SY_ZeroReg;
                            reg1_raddr_o = `SY_ZeroReg;
                            reg2_raddr_o = `SY_ZeroReg;
                        end
                    endcase
                end else begin
                    reg_we_o = `SY_WriteDisable;
                    reg_waddr_o = `SY_ZeroReg;
                    reg1_raddr_o = `SY_ZeroReg;
                    reg2_raddr_o = `SY_ZeroReg;
                end
            end
            `SY_INST_TYPE_L: begin
                case (funct3)
                    `SY_INST_LB, `SY_INST_LH, `SY_INST_LW, `SY_INST_LBU, `SY_INST_LHU: begin
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = `SY_ZeroReg;
                        reg_we_o = `SY_WriteEnable;
                        reg_waddr_o = rd;
                        op1_o = reg1_rdata_i;
                        op2_o = {{20{inst_i[31]}}, inst_i[31:20]};
                    end
                    default: begin
                        reg1_raddr_o = `SY_ZeroReg;
                        reg2_raddr_o = `SY_ZeroReg;
                        reg_we_o = `SY_WriteDisable;
                        reg_waddr_o = `SY_ZeroReg;
                    end
                endcase
            end
            `SY_INST_TYPE_S: begin
                case (funct3)
                    `SY_INST_SB, `SY_INST_SW, `SY_INST_SH: begin
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = rs2;
                        reg_we_o = `SY_WriteDisable;
                        reg_waddr_o = `SY_ZeroReg;
                        op1_o = reg1_rdata_i;
                        op2_o = {{20{inst_i[31]}}, inst_i[31:25], inst_i[11:7]};
                    end
                    default: begin
                        reg1_raddr_o = `SY_ZeroReg;
                        reg2_raddr_o = `SY_ZeroReg;
                        reg_we_o = `SY_WriteDisable;
                        reg_waddr_o = `SY_ZeroReg;
                    end
                endcase
            end
            `SY_INST_TYPE_B: begin
                case (funct3)
                    `SY_INST_BEQ, `SY_INST_BNE, `SY_INST_BLT, `SY_INST_BGE, `SY_INST_BLTU, `SY_INST_BGEU: begin
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = rs2;
                        reg_we_o = `SY_WriteDisable;
                        reg_waddr_o = `SY_ZeroReg;
                        op1_o = reg1_rdata_i;
                        op2_o = reg2_rdata_i;
                        op1_jump_o = inst_addr_i;
                        op2_jump_o = {{20{inst_i[31]}}, inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};
                    end
                    default: begin
                        reg1_raddr_o = `SY_ZeroReg;
                        reg2_raddr_o = `SY_ZeroReg;
                        reg_we_o = `SY_WriteDisable;
                        reg_waddr_o = `SY_ZeroReg;
                    end
                endcase
            end
            `SY_INST_JAL: begin
                reg_we_o = `SY_WriteEnable;
                reg_waddr_o = rd;
                reg1_raddr_o = `SY_ZeroReg;
                reg2_raddr_o = `SY_ZeroReg;
                op1_o = inst_addr_i;
                op2_o = 32'h4;
                op1_jump_o = inst_addr_i;
                op2_jump_o = {{12{inst_i[31]}}, inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0};
            end
            `SY_INST_JALR: begin
                reg_we_o = `SY_WriteEnable;
                reg1_raddr_o = rs1;
                reg2_raddr_o = `SY_ZeroReg;
                reg_waddr_o = rd;
                op1_o = inst_addr_i;
                op2_o = 32'h4;
                op1_jump_o = reg1_rdata_i;
                op2_jump_o = {{20{inst_i[31]}}, inst_i[31:20]};
            end
            `SY_INST_LUI: begin
                reg_we_o = `SY_WriteEnable;
                reg_waddr_o = rd;
                reg1_raddr_o = `SY_ZeroReg;
                reg2_raddr_o = `SY_ZeroReg;
                op1_o = {inst_i[31:12], 12'b0};
                op2_o = `SY_ZeroWord;
            end
            `SY_INST_AUIPC: begin
                reg_we_o = `SY_WriteEnable;
                reg_waddr_o = rd;
                reg1_raddr_o = `SY_ZeroReg;
                reg2_raddr_o = `SY_ZeroReg;
                op1_o = inst_addr_i;
                op2_o = {inst_i[31:12], 12'b0};
            end
            `SY_INST_NOP_OP: begin
                reg_we_o = `SY_WriteDisable;
                reg_waddr_o = `SY_ZeroReg;
                reg1_raddr_o = `SY_ZeroReg;
                reg2_raddr_o = `SY_ZeroReg;
            end
            `SY_INST_FENCE: begin
                reg_we_o = `SY_WriteDisable;
                reg_waddr_o = `SY_ZeroReg;
                reg1_raddr_o = `SY_ZeroReg;
                reg2_raddr_o = `SY_ZeroReg;
                op1_jump_o = inst_addr_i;
                op2_jump_o = 32'h4;
            end
            `SY_INST_EXT: begin
                case (funct3)
                    `SY_INST_EXTSID: begin
                        // one-cycle inst, do nothing, decode it in EX
                        reg1_raddr_o = `SY_ZeroReg;
                        reg2_raddr_o = `SY_ZeroReg;
                        reg_we_o = `SY_WriteDisable;
                        reg_waddr_o = `SY_ZeroReg;
                    end
                    `SY_INST_EXTRT: begin
                        // one-cycle inst, similar to lw
                        reg1_raddr_o = `SY_ZeroReg;
                        reg2_raddr_o = `SY_ZeroReg;
                        reg_we_o = `SY_WriteEnable;
                        reg_waddr_o = rd;
                    end
                    `SY_INST_EXTIF: begin
                        // one-cycle inst
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = 5'b11111;
                        reg_we_o = `SY_WriteEnable;
                        reg_waddr_o = rd;
                        // don't decode imm here, decode it in EX
                        op1_o = reg1_rdata_i;
                        op2_o = reg2_rdata_i;
                    end
                    default: begin
                        reg1_raddr_o = `SY_ZeroReg;
                        reg2_raddr_o = `SY_ZeroReg;
                        reg_we_o = `SY_WriteDisable;
                        reg_waddr_o = `SY_ZeroReg;
                    end
                endcase
            end
            default: begin
                reg_we_o = `SY_WriteDisable;
                reg_waddr_o = `SY_ZeroReg;
                reg1_raddr_o = `SY_ZeroReg;
                reg2_raddr_o = `SY_ZeroReg;
            end
        endcase
    end

endmodule
