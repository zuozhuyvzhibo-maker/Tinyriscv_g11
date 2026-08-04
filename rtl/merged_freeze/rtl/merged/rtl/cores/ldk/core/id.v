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
module ldk_id(

	input wire rst,

    // from if_id
    input wire[`LDK_InstBus] inst_i,
    input wire[`LDK_InstAddrBus] inst_addr_i,

    // from regs
    input wire[`LDK_RegBus] reg1_rdata_i,
    input wire[`LDK_RegBus] reg2_rdata_i,


    // from ex
    input wire ex_jump_flag_i,

    // to regs
    output reg[`LDK_RegAddrBus] reg1_raddr_o,
    output reg[`LDK_RegAddrBus] reg2_raddr_o,

    // to ex
    output reg[`LDK_MemAddrBus] op1_o,
    output reg[`LDK_MemAddrBus] op2_o,
    output reg[`LDK_MemAddrBus] op1_jump_o,
    output reg[`LDK_MemAddrBus] op2_jump_o,
    output reg[`LDK_InstBus] inst_o,
    output reg[`LDK_InstAddrBus] inst_addr_o,
    output reg[`LDK_RegBus] reg1_rdata_o,
    output reg[`LDK_RegBus] reg2_rdata_o,
    output reg reg_we_o,
    output reg[`LDK_RegAddrBus] reg_waddr_o


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
        op1_o = `LDK_ZeroWord;
        op2_o = `LDK_ZeroWord;
        op1_jump_o = `LDK_ZeroWord;
        op2_jump_o = `LDK_ZeroWord;

        case (opcode)
            `LDK_INST_TYPE_I: begin
                case (funct3)
                    `LDK_INST_ADDI, `LDK_INST_SLTI, `LDK_INST_SLTIU, `LDK_INST_XORI, `LDK_INST_ORI, `LDK_INST_ANDI, `LDK_INST_SLLI, `LDK_INST_SRI: begin
                        reg_we_o = `LDK_WriteEnable;
                        reg_waddr_o = rd;
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = `LDK_ZeroReg;
                        op1_o = reg1_rdata_i;
                        op2_o = {{20{inst_i[31]}}, inst_i[31:20]};
                    end
                    default: begin
                        reg_we_o = `LDK_WriteDisable;
                        reg_waddr_o = `LDK_ZeroReg;
                        reg1_raddr_o = `LDK_ZeroReg;
                        reg2_raddr_o = `LDK_ZeroReg;
                    end
                endcase
            end
            `LDK_INST_TYPE_R_M: begin
                if ((funct7 == 7'b0000000) || (funct7 == 7'b0100000)) begin
                    case (funct3)
                        `LDK_INST_ADD_SUB, `LDK_INST_SLL, `LDK_INST_SLT, `LDK_INST_SLTU, `LDK_INST_XOR, `LDK_INST_SR, `LDK_INST_OR, `LDK_INST_AND: begin
                            reg_we_o = `LDK_WriteEnable;
                            reg_waddr_o = rd;
                            reg1_raddr_o = rs1;
                            reg2_raddr_o = rs2;
                            op1_o = reg1_rdata_i;
                            op2_o = reg2_rdata_i;
                        end
                        default: begin
                            reg_we_o = `LDK_WriteDisable;
                            reg_waddr_o = `LDK_ZeroReg;
                            reg1_raddr_o = `LDK_ZeroReg;
                            reg2_raddr_o = `LDK_ZeroReg;
                        end
                    endcase
                end else begin
                    reg_we_o = `LDK_WriteDisable;
                    reg_waddr_o = `LDK_ZeroReg;
                    reg1_raddr_o = `LDK_ZeroReg;
                    reg2_raddr_o = `LDK_ZeroReg;
                end
            end
            `LDK_INST_TYPE_L: begin
                case (funct3)
                    `LDK_INST_LB, `LDK_INST_LH, `LDK_INST_LW, `LDK_INST_LBU, `LDK_INST_LHU: begin
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = `LDK_ZeroReg;
                        reg_we_o = `LDK_WriteEnable;
                        reg_waddr_o = rd;
                        op1_o = reg1_rdata_i;
                        op2_o = {{20{inst_i[31]}}, inst_i[31:20]};
                    end
                    default: begin
                        reg1_raddr_o = `LDK_ZeroReg;
                        reg2_raddr_o = `LDK_ZeroReg;
                        reg_we_o = `LDK_WriteDisable;
                        reg_waddr_o = `LDK_ZeroReg;
                    end
                endcase
            end
            `LDK_INST_TYPE_S: begin
                case (funct3)
                    `LDK_INST_SB, `LDK_INST_SW, `LDK_INST_SH: begin
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = rs2;
                        reg_we_o = `LDK_WriteDisable;
                        reg_waddr_o = `LDK_ZeroReg;
                        op1_o = reg1_rdata_i;
                        op2_o = {{20{inst_i[31]}}, inst_i[31:25], inst_i[11:7]};
                    end
                    default: begin
                        reg1_raddr_o = `LDK_ZeroReg;
                        reg2_raddr_o = `LDK_ZeroReg;
                        reg_we_o = `LDK_WriteDisable;
                        reg_waddr_o = `LDK_ZeroReg;
                    end
                endcase
            end
            `LDK_INST_TYPE_B: begin
                case (funct3)
                    `LDK_INST_BEQ, `LDK_INST_BNE, `LDK_INST_BLT, `LDK_INST_BGE, `LDK_INST_BLTU, `LDK_INST_BGEU: begin
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = rs2;
                        reg_we_o = `LDK_WriteDisable;
                        reg_waddr_o = `LDK_ZeroReg;
                        op1_o = reg1_rdata_i;
                        op2_o = reg2_rdata_i;
                        op1_jump_o = inst_addr_i;
                        op2_jump_o = {{20{inst_i[31]}}, inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};
                    end
                    default: begin
                        reg1_raddr_o = `LDK_ZeroReg;
                        reg2_raddr_o = `LDK_ZeroReg;
                        reg_we_o = `LDK_WriteDisable;
                        reg_waddr_o = `LDK_ZeroReg;
                    end
                endcase
            end
            `LDK_INST_JAL: begin
                reg_we_o = `LDK_WriteEnable;
                reg_waddr_o = rd;
                reg1_raddr_o = `LDK_ZeroReg;
                reg2_raddr_o = `LDK_ZeroReg;
                op1_o = inst_addr_i;
                op2_o = 32'h4;
                op1_jump_o = inst_addr_i;
                op2_jump_o = {{12{inst_i[31]}}, inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0};
            end
            `LDK_INST_JALR: begin
                reg_we_o = `LDK_WriteEnable;
                reg1_raddr_o = rs1;
                reg2_raddr_o = `LDK_ZeroReg;
                reg_waddr_o = rd;
                op1_o = inst_addr_i;
                op2_o = 32'h4;
                op1_jump_o = reg1_rdata_i;
                op2_jump_o = {{20{inst_i[31]}}, inst_i[31:20]};
            end
            `LDK_INST_LUI: begin
                reg_we_o = `LDK_WriteEnable;
                reg_waddr_o = rd;
                reg1_raddr_o = `LDK_ZeroReg;
                reg2_raddr_o = `LDK_ZeroReg;
                op1_o = {inst_i[31:12], 12'b0};
                op2_o = `LDK_ZeroWord;
            end
            `LDK_INST_AUIPC: begin
                reg_we_o = `LDK_WriteEnable;
                reg_waddr_o = rd;
                reg1_raddr_o = `LDK_ZeroReg;
                reg2_raddr_o = `LDK_ZeroReg;
                op1_o = inst_addr_i;
                op2_o = {inst_i[31:12], 12'b0};
            end
            `LDK_INST_NOP_OP: begin
                reg_we_o = `LDK_WriteDisable;
                reg_waddr_o = `LDK_ZeroReg;
                reg1_raddr_o = `LDK_ZeroReg;
                reg2_raddr_o = `LDK_ZeroReg;
            end
            `LDK_INST_FENCE: begin
                reg_we_o = `LDK_WriteDisable;
                reg_waddr_o = `LDK_ZeroReg;
                reg1_raddr_o = `LDK_ZeroReg;
                reg2_raddr_o = `LDK_ZeroReg;
                op1_jump_o = inst_addr_i;
                op2_jump_o = 32'h4;
            end
            `LDK_INST_EXTEND:begin
                case (funct3)
                    `LDK_INST_SID: begin
                        reg_we_o = `LDK_WriteEnable ;
                        reg_waddr_o = rd;
                        reg1_raddr_o = rs1 ;
                        reg2_raddr_o = `LDK_ZeroReg ;
                        op1_o = reg1_rdata_i;
                        op2_o = {{20{inst_i[31]}}, inst_i[31:20]};
                    end
                    `LDK_INST_RT: begin
                        reg_we_o = `LDK_WriteEnable ;
                        reg_waddr_o = rd;
                        reg1_raddr_o = rs1 ;
                        reg2_raddr_o = `LDK_ZeroReg ;
                        op1_o = reg1_rdata_i;
                        op2_o = {{20{inst_i[31]}}, inst_i[31:20]};
                    end
                    `LDK_INST_IFE: begin
                        reg_we_o = `LDK_WriteEnable ;
                        reg_waddr_o = rd;
                        reg1_raddr_o = rs1 ;
                        reg2_raddr_o = 5'b11111 ;
                        op1_o = reg1_rdata_i;
                        op2_o = reg2_rdata_i;
                    end
                    default: begin
                        reg1_raddr_o = `LDK_ZeroReg;
                        reg2_raddr_o = `LDK_ZeroReg;
                        reg_we_o = `LDK_WriteDisable;
                        reg_waddr_o = `LDK_ZeroReg;
                    end
                endcase
            end
            default: begin
                reg_we_o = `LDK_WriteDisable;
                reg_waddr_o = `LDK_ZeroReg;
                reg1_raddr_o = `LDK_ZeroReg;
                reg2_raddr_o = `LDK_ZeroReg;
            end
        endcase
    end

endmodule
