/*
 * Copyright 2019 Blue Liang, liangkangnan@163.com
 * Licensed under the Apache License, Version 2.0.
 */

`include "defines.v"

// Combinational execute stage for RV32I and the course custom instructions.
// Multiplication, division, CSR, exception, and interrupt paths were removed.
module lhr_ex(
    input wire rst,
    input wire[`InstBus] inst_i,
    input wire reg_we_i,
    input wire[`RegAddrBus] reg_waddr_i,
    input wire[`RegBus] reg1_rdata_i,
    input wire[`RegBus] reg2_rdata_i,
    input wire[`MemAddrBus] op1_i,
    input wire[`MemAddrBus] op2_i,
    input wire[`MemAddrBus] op1_jump_i,
    input wire[`MemAddrBus] op2_jump_i,
    input wire[`MemBus] mem_rdata_i,
    output reg[`MemBus] mem_wdata_o,
    output reg[`MemAddrBus] mem_raddr_o,
    output reg[`MemAddrBus] mem_waddr_o,
    output reg mem_we_o,
    output reg mem_req_o,
    output reg[`RegBus] reg_wdata_o,
    output reg reg_we_o,
    output reg[`RegAddrBus] reg_waddr_o,
    output reg hold_flag_o,
    output reg jump_flag_o,
    output reg[`InstAddrBus] jump_addr_o
    );

    wire[6:0] opcode = inst_i[6:0];
    wire[2:0] funct3 = inst_i[14:12];
    wire[6:0] funct7 = inst_i[31:25];
    wire[`MemAddrBus] effective_addr = op1_i + op2_i;
    wire[`MemAddrBus] branch_addr = op1_jump_i + op2_jump_i;
    wire[1:0] load_index = effective_addr[1:0];
    wire[1:0] store_index = effective_addr[1:0];

    always @ (*) begin
        mem_wdata_o = `ZeroWord;
        mem_raddr_o = `ZeroWord;
        mem_waddr_o = `ZeroWord;
        mem_we_o = `WriteDisable;
        mem_req_o = `RIB_NREQ;
        reg_wdata_o = `ZeroWord;
        reg_we_o = reg_we_i;
        reg_waddr_o = reg_waddr_i;
        hold_flag_o = `HoldDisable;
        jump_flag_o = `JumpDisable;
        jump_addr_o = `ZeroWord;

        if (rst == `RstEnable) begin
            reg_we_o = `WriteDisable;
            reg_waddr_o = `ZeroReg;
        end else begin
            case (opcode)
                `INST_TYPE_I: begin
                    case (funct3)
                        `INST_ADDI: begin
                            reg_wdata_o = effective_addr;
                        end
                        `INST_SLTI: begin
                            reg_wdata_o = ($signed(op1_i) < $signed(op2_i)) ?
                                          32'd1 : 32'd0;
                        end
                        `INST_SLTIU: begin
                            reg_wdata_o = (op1_i < op2_i) ? 32'd1 : 32'd0;
                        end
                        `INST_XORI: begin
                            reg_wdata_o = op1_i ^ op2_i;
                        end
                        `INST_ORI: begin
                            reg_wdata_o = op1_i | op2_i;
                        end
                        `INST_ANDI: begin
                            reg_wdata_o = op1_i & op2_i;
                        end
                        `INST_SLLI: begin
                            if (funct7 == 7'b0000000) begin
                                reg_wdata_o = reg1_rdata_i << inst_i[24:20];
                            end else begin
                                reg_we_o = `WriteDisable;
                            end
                        end
                        `INST_SRI: begin
                            if (funct7 == 7'b0000000) begin
                                reg_wdata_o = reg1_rdata_i >> inst_i[24:20];
                            end else if (funct7 == 7'b0100000) begin
                                reg_wdata_o = $signed(reg1_rdata_i) >>> inst_i[24:20];
                            end else begin
                                reg_we_o = `WriteDisable;
                            end
                        end
                        default: begin
                            reg_we_o = `WriteDisable;
                        end
                    endcase
                end

                `INST_TYPE_R: begin
                    // RV32M uses this opcode with funct7=0000001. It reaches
                    // this safe branch but can never write a destination.
                    if (funct7 == 7'b0000000) begin
                        case (funct3)
                            `INST_ADD_SUB: reg_wdata_o = op1_i + op2_i;
                            `INST_SLL: reg_wdata_o = op1_i << op2_i[4:0];
                            `INST_SLT: begin
                                reg_wdata_o = ($signed(op1_i) < $signed(op2_i)) ?
                                              32'd1 : 32'd0;
                            end
                            `INST_SLTU: begin
                                reg_wdata_o = (op1_i < op2_i) ? 32'd1 : 32'd0;
                            end
                            `INST_XOR: reg_wdata_o = op1_i ^ op2_i;
                            `INST_SR: reg_wdata_o = op1_i >> op2_i[4:0];
                            `INST_OR: reg_wdata_o = op1_i | op2_i;
                            `INST_AND: reg_wdata_o = op1_i & op2_i;
                            default: reg_we_o = `WriteDisable;
                        endcase
                    end else if (funct7 == 7'b0100000) begin
                        case (funct3)
                            `INST_ADD_SUB: reg_wdata_o = op1_i - op2_i;
                            `INST_SR: begin
                                reg_wdata_o = $signed(op1_i) >>> op2_i[4:0];
                            end
                            default: reg_we_o = `WriteDisable;
                        endcase
                    end else begin
                        reg_we_o = `WriteDisable;
                    end
                end

                `INST_TYPE_L: begin
                    mem_req_o = `RIB_REQ;
                    mem_raddr_o = effective_addr;
                    case (funct3)
                        `INST_LB: begin
                            case (load_index)
                                2'b00: reg_wdata_o = {{24{mem_rdata_i[7]}}, mem_rdata_i[7:0]};
                                2'b01: reg_wdata_o = {{24{mem_rdata_i[15]}}, mem_rdata_i[15:8]};
                                2'b10: reg_wdata_o = {{24{mem_rdata_i[23]}}, mem_rdata_i[23:16]};
                                default: reg_wdata_o = {{24{mem_rdata_i[31]}}, mem_rdata_i[31:24]};
                            endcase
                        end
                        `INST_LH: begin
                            if (load_index == 2'b00) begin
                                reg_wdata_o = {{16{mem_rdata_i[15]}}, mem_rdata_i[15:0]};
                            end else begin
                                reg_wdata_o = {{16{mem_rdata_i[31]}}, mem_rdata_i[31:16]};
                            end
                        end
                        `INST_LW: begin
                            reg_wdata_o = mem_rdata_i;
                        end
                        `INST_LBU: begin
                            case (load_index)
                                2'b00: reg_wdata_o = {24'h0, mem_rdata_i[7:0]};
                                2'b01: reg_wdata_o = {24'h0, mem_rdata_i[15:8]};
                                2'b10: reg_wdata_o = {24'h0, mem_rdata_i[23:16]};
                                default: reg_wdata_o = {24'h0, mem_rdata_i[31:24]};
                            endcase
                        end
                        `INST_LHU: begin
                            if (load_index == 2'b00) begin
                                reg_wdata_o = {16'h0, mem_rdata_i[15:0]};
                            end else begin
                                reg_wdata_o = {16'h0, mem_rdata_i[31:16]};
                            end
                        end
                        default: begin
                            mem_req_o = `RIB_NREQ;
                            reg_we_o = `WriteDisable;
                        end
                    endcase
                end

                `INST_TYPE_S: begin
                    reg_we_o = `WriteDisable;
                    mem_req_o = `RIB_REQ;
                    mem_we_o = `WriteEnable;
                    mem_raddr_o = effective_addr;
                    mem_waddr_o = effective_addr;
                    case (funct3)
                        `INST_SB: begin
                            case (store_index)
                                2'b00: mem_wdata_o = {mem_rdata_i[31:8], reg2_rdata_i[7:0]};
                                2'b01: mem_wdata_o = {mem_rdata_i[31:16], reg2_rdata_i[7:0], mem_rdata_i[7:0]};
                                2'b10: mem_wdata_o = {mem_rdata_i[31:24], reg2_rdata_i[7:0], mem_rdata_i[15:0]};
                                default: mem_wdata_o = {reg2_rdata_i[7:0], mem_rdata_i[23:0]};
                            endcase
                        end
                        `INST_SH: begin
                            if (store_index == 2'b00) begin
                                mem_wdata_o = {mem_rdata_i[31:16], reg2_rdata_i[15:0]};
                            end else begin
                                mem_wdata_o = {reg2_rdata_i[15:0], mem_rdata_i[15:0]};
                            end
                        end
                        `INST_SW: begin
                            mem_wdata_o = reg2_rdata_i;
                        end
                        default: begin
                            mem_req_o = `RIB_NREQ;
                            mem_we_o = `WriteDisable;
                        end
                    endcase
                end

                `INST_TYPE_B: begin
                    reg_we_o = `WriteDisable;
                    case (funct3)
                        `INST_BEQ: jump_flag_o = (op1_i == op2_i);
                        `INST_BNE: jump_flag_o = (op1_i != op2_i);
                        `INST_BLT: jump_flag_o = ($signed(op1_i) < $signed(op2_i));
                        `INST_BGE: jump_flag_o = ($signed(op1_i) >= $signed(op2_i));
                        `INST_BLTU: jump_flag_o = (op1_i < op2_i);
                        `INST_BGEU: jump_flag_o = (op1_i >= op2_i);
                        default: jump_flag_o = `JumpDisable;
                    endcase
                    if (jump_flag_o == `JumpEnable) begin
                        jump_addr_o = branch_addr;
                    end
                end

                `INST_JAL, `INST_JALR: begin
                    jump_flag_o = `JumpEnable;
                    jump_addr_o = branch_addr;
                    reg_wdata_o = op1_i + op2_i;
                end

                `INST_LUI, `INST_AUIPC: begin
                    reg_wdata_o = op1_i + op2_i;
                end

                `INST_FENCE: begin
                    reg_we_o = `WriteDisable;
                    jump_flag_o = `JumpEnable;
                    jump_addr_o = branch_addr;
                end

                `INST_CUSTOM: begin
                    case (funct3)
                        `INST_SID: begin
                            reg_we_o = `WriteDisable;
                            mem_req_o = `RIB_REQ;
                            mem_we_o = `WriteEnable;
                            mem_raddr_o = `UART_SEND_ID_REG;
                            mem_waddr_o = `UART_SEND_ID_REG;
                            mem_wdata_o = 32'h00000001;
                        end
                        `INST_RT: begin
                            reg_we_o = `WriteEnable;
                            mem_req_o = `RIB_REQ;
                            mem_raddr_o = `I2C_INPUT_REG;
                            reg_wdata_o = {24'h0, mem_rdata_i[7:0]};
                        end
                        `INST_IF: begin
                            reg_we_o = `WriteEnable;
                            if (inst_i[31:20] == 12'h000) begin
                                if (op1_i >= reg2_rdata_i) begin
                                    mem_req_o = `RIB_REQ;
                                    mem_we_o = `WriteEnable;
                                    mem_raddr_o = `UART_TX_REG;
                                    mem_waddr_o = `UART_TX_REG;
                                    mem_wdata_o = {24'h0, op1_i[7:0]};
                                    reg_wdata_o = `ZeroWord;
                                end else begin
                                    reg_wdata_o = op1_i;
                                end
                            end else begin
                                reg_wdata_o = op1_i + op2_i;
                            end
                        end
                        default: begin
                            reg_we_o = `WriteDisable;
                        end
                    endcase
                end

                default: begin
                    reg_we_o = `WriteDisable;
                    reg_waddr_o = `ZeroReg;
                end
            endcase
        end
    end

endmodule
