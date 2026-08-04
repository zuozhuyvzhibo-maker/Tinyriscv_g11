/*
 * Copyright 2019 Blue Liang, liangkangnan@163.com
 * Licensed under the Apache License, Version 2.0.
 */

`include "lhr_defs.v"

// Combinational decoder for RV32I and the three course custom instructions.
// RV32M, CSR, exception, and interrupt decoding are intentionally absent.
module lhr_id(
    input wire rst,
    input wire[`LHR_InstBus] inst_i,
    input wire[`LHR_InstAddrBus] inst_addr_i,
    input wire[`LHR_RegBus] reg1_rdata_i,
    input wire[`LHR_RegBus] reg2_rdata_i,
    output reg[`LHR_RegAddrBus] reg1_raddr_o,
    output reg[`LHR_RegAddrBus] reg2_raddr_o,
    output reg[`LHR_MemAddrBus] op1_o,
    output reg[`LHR_MemAddrBus] op2_o,
    output reg[`LHR_MemAddrBus] op1_jump_o,
    output reg[`LHR_MemAddrBus] op2_jump_o,
    output reg[`LHR_InstBus] inst_o,
    output reg[`LHR_InstAddrBus] inst_addr_o,
    output reg[`LHR_RegBus] reg1_rdata_o,
    output reg[`LHR_RegBus] reg2_rdata_o,
    output reg reg_we_o,
    output reg[`LHR_RegAddrBus] reg_waddr_o
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
        reg1_raddr_o = `LHR_ZeroReg;
        reg2_raddr_o = `LHR_ZeroReg;
        reg_we_o = `LHR_WriteDisable;
        reg_waddr_o = `LHR_ZeroReg;
        op1_o = `LHR_ZeroWord;
        op2_o = `LHR_ZeroWord;
        op1_jump_o = `LHR_ZeroWord;
        op2_jump_o = `LHR_ZeroWord;

        if (rst == `LHR_RstDisable) begin
            case (opcode)
                `LHR_INST_TYPE_I: begin
                    case (funct3)
                        `LHR_INST_ADDI, `LHR_INST_SLTI, `LHR_INST_SLTIU,
                        `LHR_INST_XORI, `LHR_INST_ORI, `LHR_INST_ANDI: begin
                            reg_we_o = `LHR_WriteEnable;
                            reg_waddr_o = rd;
                            reg1_raddr_o = rs1;
                            op1_o = reg1_rdata_i;
                            op2_o = {{20{inst_i[31]}}, inst_i[31:20]};
                        end
                        `LHR_INST_SLLI: begin
                            if (funct7 == 7'b0000000) begin
                                reg_we_o = `LHR_WriteEnable;
                                reg_waddr_o = rd;
                                reg1_raddr_o = rs1;
                                op1_o = reg1_rdata_i;
                                op2_o = {27'h0, inst_i[24:20]};
                            end
                        end
                        `LHR_INST_SRI: begin
                            if ((funct7 == 7'b0000000) ||
                                (funct7 == 7'b0100000)) begin
                                reg_we_o = `LHR_WriteEnable;
                                reg_waddr_o = rd;
                                reg1_raddr_o = rs1;
                                op1_o = reg1_rdata_i;
                                op2_o = {27'h0, inst_i[24:20]};
                            end
                        end
                        default: begin
                        end
                    endcase
                end

                `LHR_INST_TYPE_R: begin
                    // funct7=0000001 (RV32M) and all other illegal encodings
                    // remain at the safe no-write defaults above.
                    if ((funct7 == 7'b0000000) ||
                        (funct7 == 7'b0100000)) begin
                        case (funct3)
                            `LHR_INST_ADD_SUB, `LHR_INST_SLL, `LHR_INST_SLT,
                            `LHR_INST_SLTU, `LHR_INST_XOR, `LHR_INST_SR,
                            `LHR_INST_OR, `LHR_INST_AND: begin
                                reg_we_o = `LHR_WriteEnable;
                                reg_waddr_o = rd;
                                reg1_raddr_o = rs1;
                                reg2_raddr_o = rs2;
                                op1_o = reg1_rdata_i;
                                op2_o = reg2_rdata_i;
                            end
                            default: begin
                            end
                        endcase
                    end
                end

                `LHR_INST_TYPE_L: begin
                    case (funct3)
                        `LHR_INST_LB, `LHR_INST_LH, `LHR_INST_LW,
                        `LHR_INST_LBU, `LHR_INST_LHU: begin
                            reg1_raddr_o = rs1;
                            reg_we_o = `LHR_WriteEnable;
                            reg_waddr_o = rd;
                            op1_o = reg1_rdata_i;
                            op2_o = {{20{inst_i[31]}}, inst_i[31:20]};
                        end
                        default: begin
                        end
                    endcase
                end

                `LHR_INST_TYPE_S: begin
                    case (funct3)
                        `LHR_INST_SB, `LHR_INST_SH, `LHR_INST_SW: begin
                            reg1_raddr_o = rs1;
                            reg2_raddr_o = rs2;
                            op1_o = reg1_rdata_i;
                            op2_o = {{20{inst_i[31]}}, inst_i[31:25],
                                     inst_i[11:7]};
                        end
                        default: begin
                        end
                    endcase
                end

                `LHR_INST_TYPE_B: begin
                    case (funct3)
                        `LHR_INST_BEQ, `LHR_INST_BNE, `LHR_INST_BLT,
                        `LHR_INST_BGE, `LHR_INST_BLTU, `LHR_INST_BGEU: begin
                            reg1_raddr_o = rs1;
                            reg2_raddr_o = rs2;
                            op1_o = reg1_rdata_i;
                            op2_o = reg2_rdata_i;
                            op1_jump_o = inst_addr_i;
                            op2_jump_o = {{20{inst_i[31]}}, inst_i[7],
                                          inst_i[30:25], inst_i[11:8], 1'b0};
                        end
                        default: begin
                        end
                    endcase
                end

                `LHR_INST_JAL: begin
                    reg_we_o = `LHR_WriteEnable;
                    reg_waddr_o = rd;
                    op1_o = inst_addr_i;
                    op2_o = 32'd4;
                    op1_jump_o = inst_addr_i;
                    op2_jump_o = {{12{inst_i[31]}}, inst_i[19:12],
                                  inst_i[20], inst_i[30:21], 1'b0};
                end

                `LHR_INST_JALR: begin
                    if (funct3 == 3'b000) begin
                        reg_we_o = `LHR_WriteEnable;
                        reg_waddr_o = rd;
                        reg1_raddr_o = rs1;
                        op1_o = inst_addr_i;
                        op2_o = 32'd4;
                        op1_jump_o = reg1_rdata_i;
                        op2_jump_o = {{20{inst_i[31]}}, inst_i[31:20]};
                    end
                end

                `LHR_INST_LUI: begin
                    reg_we_o = `LHR_WriteEnable;
                    reg_waddr_o = rd;
                    op1_o = {inst_i[31:12], 12'b0};
                end

                `LHR_INST_AUIPC: begin
                    reg_we_o = `LHR_WriteEnable;
                    reg_waddr_o = rd;
                    op1_o = inst_addr_i;
                    op2_o = {inst_i[31:12], 12'b0};
                end

                `LHR_INST_FENCE: begin
                    // Redirect to the sequential PC to flush stale fetch data.
                    op1_jump_o = inst_addr_i;
                    op2_jump_o = 32'd4;
                end

                `LHR_INST_CUSTOM: begin
                    case (funct3)
                        `LHR_INST_SID: begin
                            // The execute stage writes the UART command register.
                        end
                        `LHR_INST_RT: begin
                            reg_we_o = `LHR_WriteEnable;
                            reg_waddr_o = rd;
                        end
                        `LHR_INST_IF: begin
                            reg_we_o = `LHR_WriteEnable;
                            reg_waddr_o = rd;
                            reg1_raddr_o = rs1;
                            reg2_raddr_o = 5'd31;
                            op1_o = reg1_rdata_i;
                            op2_o = {{20{inst_i[31]}}, inst_i[31:20]};
                        end
                        default: begin
                        end
                    endcase
                end

                default: begin
                end
            endcase
        end
    end

endmodule
