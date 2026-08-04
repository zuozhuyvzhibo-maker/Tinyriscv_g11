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
module wje_ex(

    input wire rst,

    // from id
    input wire[`WJE_InstBus] inst_i,
    input wire[`WJE_InstAddrBus] inst_addr_i,
    input wire reg_we_i,
    input wire[`WJE_RegAddrBus] reg_waddr_i,
    input wire[`WJE_RegBus] reg1_rdata_i,
    input wire[`WJE_RegBus] reg2_rdata_i,
    input wire[`WJE_MemAddrBus] op1_i,
    input wire[`WJE_MemAddrBus] op2_i,
    input wire[`WJE_MemAddrBus] op1_jump_i,
    input wire[`WJE_MemAddrBus] op2_jump_i,

    // from mem
    input wire[`WJE_MemBus] mem_rdata_i,
    input wire mem_busy_i,

    // from uart
    input wire sid_busy_i,
    input wire if_uart_busy_i,
    input wire if_uart_done_i,

    // from i2c temperature reader
    input wire temp_busy_i,
    input wire temp_done_i,
    input wire temp_ack_error_i,
    input wire[15:0] temp_raw_i,

    // to mem
    output reg[`WJE_MemBus] mem_wdata_o,
    output reg[`WJE_MemAddrBus] mem_raddr_o,
    output reg[`WJE_MemAddrBus] mem_waddr_o,
    output wire mem_we_o,
    output wire mem_req_o,
    output wire[3:0] mem_byte_en_o,

    // to regs
    output wire[`WJE_RegBus] reg_wdata_o,
    output wire reg_we_o,
    output wire[`WJE_RegAddrBus] reg_waddr_o,

    // to uart
    output wire sid_start_o,
    output wire if_uart_start_o,
    output wire if_uart_accept_o,
    output wire[7:0] if_uart_data_o,
    output wire if_uart_hold_o,

    // to i2c temperature reader
    output wire temp_start_o,
    output wire temp_hold_o,
    output wire temp_accept_o,

    // to ctrl
    output wire hold_flag_o,
    output wire jump_flag_o,
    output wire[`WJE_InstAddrBus] jump_addr_o

    );

    wire[1:0] mem_raddr_index;
    wire[1:0] mem_waddr_index;
    wire[31:0] sr_shift;
    wire[31:0] sri_shift;
    wire[31:0] sr_shift_mask;
    wire[31:0] sri_shift_mask;
    wire[31:0] op1_add_op2_res;
    wire[31:0] op1_jump_add_op2_jump_res;
    wire[31:0] reg1_data_invert;
    wire[31:0] reg2_data_invert;
    wire op1_ge_op2_signed;
    wire op1_ge_op2_unsigned;
    wire op1_eq_op2;
    wire if_fire_enable;
    wire mem_access_wait;
    wire[6:0] opcode;
    wire[2:0] funct3;
    wire[6:0] funct7;
    wire[4:0] rd;
    wire[4:0] uimm;
    reg[`WJE_RegBus] reg_wdata;
    reg reg_we;
    reg[`WJE_RegAddrBus] reg_waddr;
    reg hold_flag;
    reg jump_flag;
    reg[`WJE_InstAddrBus] jump_addr;
    reg mem_we;
    reg mem_req;
    reg[3:0] mem_byte_en;
    reg sid_start;
    reg if_uart_start;
    reg if_uart_accept;
    reg[7:0] if_uart_data;
    reg if_uart_hold;
    reg temp_start;
    reg temp_hold;
    reg temp_accept;

    assign opcode = inst_i[6:0];
    assign funct3 = inst_i[14:12];
    assign funct7 = inst_i[31:25];
    assign rd = inst_i[11:7];
    assign uimm = inst_i[19:15];

    assign sr_shift = reg1_rdata_i >> reg2_rdata_i[4:0];
    assign sri_shift = reg1_rdata_i >> inst_i[24:20];
    assign sr_shift_mask = 32'hffffffff >> reg2_rdata_i[4:0];
    assign sri_shift_mask = 32'hffffffff >> inst_i[24:20];

    assign op1_add_op2_res = op1_i + op2_i;
    assign op1_jump_add_op2_jump_res = op1_jump_i + op2_jump_i;

    assign reg1_data_invert = ~reg1_rdata_i + 1;
    assign reg2_data_invert = ~reg2_rdata_i + 1;


    assign op1_ge_op2_signed = $signed(op1_i) >= $signed(op2_i);

    assign op1_ge_op2_unsigned = op1_i >= op2_i;
    assign op1_eq_op2 = (op1_i == op2_i);
    assign if_fire_enable = reg1_rdata_i >= reg2_rdata_i;

    assign mem_raddr_index = (reg1_rdata_i + {{20{inst_i[31]}}, inst_i[31:20]}) & 2'b11;
    assign mem_waddr_index = (reg1_rdata_i + {{20{inst_i[31]}}, inst_i[31:25], inst_i[11:7]}) & 2'b11;
    assign mem_access_wait = (mem_req == `WJE_RIB_REQ) && (mem_busy_i == `WJE_HoldEnable);

    assign sid_start_o = sid_start;
    assign if_uart_start_o = if_uart_start;
    assign if_uart_accept_o = if_uart_accept;
    assign if_uart_data_o = if_uart_data;
    assign if_uart_hold_o = if_uart_hold;
    assign temp_start_o = temp_start;
    assign temp_hold_o = temp_hold;
    assign temp_accept_o = temp_accept;

    assign reg_wdata_o = reg_wdata;

    assign reg_we_o = (mem_access_wait == `WJE_HoldEnable)? `WJE_WriteDisable: reg_we;
    assign reg_waddr_o = reg_waddr;

    assign mem_we_o = mem_we;
    assign mem_req_o = mem_req;
    assign mem_byte_en_o = mem_byte_en;

    assign hold_flag_o = hold_flag || mem_access_wait || sid_busy_i;
    assign jump_flag_o = jump_flag;
    assign jump_addr_o = jump_addr;



    always @ (*) begin
        reg_we = reg_we_i;
        reg_waddr = reg_waddr_i;
        mem_req = `WJE_RIB_NREQ;
        mem_byte_en = 4'b1111;
        sid_start = `WJE_False;
        if_uart_start = `WJE_False;
        if_uart_accept = `WJE_False;
        if_uart_data = 8'h0;
        if_uart_hold = `WJE_HoldDisable;
        temp_start = `WJE_False;
        temp_hold = `WJE_HoldDisable;
        temp_accept = `WJE_False;

        case (opcode)
            `WJE_INST_TYPE_I: begin
                case (funct3)
                    `WJE_INST_ADDI: begin
                        jump_flag = `WJE_JumpDisable;
                        hold_flag = `WJE_HoldDisable;
                        jump_addr = `WJE_ZeroWord;
                        mem_wdata_o = `WJE_ZeroWord;
                        mem_raddr_o = `WJE_ZeroWord;
                        mem_waddr_o = `WJE_ZeroWord;
                        mem_we = `WJE_WriteDisable;
                        reg_wdata = op1_add_op2_res;
                    end
                    `WJE_INST_SLTI: begin
                        jump_flag = `WJE_JumpDisable;
                        hold_flag = `WJE_HoldDisable;
                        jump_addr = `WJE_ZeroWord;
                        mem_wdata_o = `WJE_ZeroWord;
                        mem_raddr_o = `WJE_ZeroWord;
                        mem_waddr_o = `WJE_ZeroWord;
                        mem_we = `WJE_WriteDisable;
                        reg_wdata = {32{(~op1_ge_op2_signed)}} & 32'h1;
                    end
                    `WJE_INST_SLTIU: begin
                        jump_flag = `WJE_JumpDisable;
                        hold_flag = `WJE_HoldDisable;
                        jump_addr = `WJE_ZeroWord;
                        mem_wdata_o = `WJE_ZeroWord;
                        mem_raddr_o = `WJE_ZeroWord;
                        mem_waddr_o = `WJE_ZeroWord;
                        mem_we = `WJE_WriteDisable;
                        reg_wdata = {32{(~op1_ge_op2_unsigned)}} & 32'h1;
                    end
                    `WJE_INST_XORI: begin
                        jump_flag = `WJE_JumpDisable;
                        hold_flag = `WJE_HoldDisable;
                        jump_addr = `WJE_ZeroWord;
                        mem_wdata_o = `WJE_ZeroWord;
                        mem_raddr_o = `WJE_ZeroWord;
                        mem_waddr_o = `WJE_ZeroWord;
                        mem_we = `WJE_WriteDisable;
                        reg_wdata = op1_i ^ op2_i;
                    end
                    `WJE_INST_ORI: begin
                        jump_flag = `WJE_JumpDisable;
                        hold_flag = `WJE_HoldDisable;
                        jump_addr = `WJE_ZeroWord;
                        mem_wdata_o = `WJE_ZeroWord;
                        mem_raddr_o = `WJE_ZeroWord;
                        mem_waddr_o = `WJE_ZeroWord;
                        mem_we = `WJE_WriteDisable;
                        reg_wdata = op1_i | op2_i;
                    end
                    `WJE_INST_ANDI: begin
                        jump_flag = `WJE_JumpDisable;
                        hold_flag = `WJE_HoldDisable;
                        jump_addr = `WJE_ZeroWord;
                        mem_wdata_o = `WJE_ZeroWord;
                        mem_raddr_o = `WJE_ZeroWord;
                        mem_waddr_o = `WJE_ZeroWord;
                        mem_we = `WJE_WriteDisable;
                        reg_wdata = op1_i & op2_i;
                    end
                    `WJE_INST_SLLI: begin
                        jump_flag = `WJE_JumpDisable;
                        hold_flag = `WJE_HoldDisable;
                        jump_addr = `WJE_ZeroWord;
                        mem_wdata_o = `WJE_ZeroWord;
                        mem_raddr_o = `WJE_ZeroWord;
                        mem_waddr_o = `WJE_ZeroWord;
                        mem_we = `WJE_WriteDisable;
                        reg_wdata = reg1_rdata_i << inst_i[24:20];
                    end
                    `WJE_INST_SRI: begin
                        jump_flag = `WJE_JumpDisable;
                        hold_flag = `WJE_HoldDisable;
                        jump_addr = `WJE_ZeroWord;
                        mem_wdata_o = `WJE_ZeroWord;
                        mem_raddr_o = `WJE_ZeroWord;
                        mem_waddr_o = `WJE_ZeroWord;
                        mem_we = `WJE_WriteDisable;
                        if (inst_i[30] == 1'b1) begin
                            reg_wdata = (sri_shift & sri_shift_mask) | ({32{reg1_rdata_i[31]}} & (~sri_shift_mask));
                        end else begin
                            reg_wdata = reg1_rdata_i >> inst_i[24:20];
                        end
                    end
                    default: begin
                        jump_flag = `WJE_JumpDisable;
                        hold_flag = `WJE_HoldDisable;
                        jump_addr = `WJE_ZeroWord;
                        mem_wdata_o = `WJE_ZeroWord;
                        mem_raddr_o = `WJE_ZeroWord;
                        mem_waddr_o = `WJE_ZeroWord;
                        mem_we = `WJE_WriteDisable;
                        reg_wdata = `WJE_ZeroWord;
                    end
                endcase
            end
            `WJE_INST_TYPE_R_M: begin
                if ((funct7 == 7'b0000000) || (funct7 == 7'b0100000)) begin
                    case (funct3)
                        `WJE_INST_ADD_SUB: begin
                            jump_flag = `WJE_JumpDisable;
                            hold_flag = `WJE_HoldDisable;
                            jump_addr = `WJE_ZeroWord;
                            mem_wdata_o = `WJE_ZeroWord;
                            mem_raddr_o = `WJE_ZeroWord;
                            mem_waddr_o = `WJE_ZeroWord;
                            mem_we = `WJE_WriteDisable;
                            if (inst_i[30] == 1'b0) begin
                                reg_wdata = op1_add_op2_res;
                            end else begin
                                reg_wdata = op1_i - op2_i;
                            end
                        end
                        `WJE_INST_SLL: begin
                            jump_flag = `WJE_JumpDisable;
                            hold_flag = `WJE_HoldDisable;
                            jump_addr = `WJE_ZeroWord;
                            mem_wdata_o = `WJE_ZeroWord;
                            mem_raddr_o = `WJE_ZeroWord;
                            mem_waddr_o = `WJE_ZeroWord;
                            mem_we = `WJE_WriteDisable;
                            reg_wdata = op1_i << op2_i[4:0];
                        end
                        `WJE_INST_SLT: begin
                            jump_flag = `WJE_JumpDisable;
                            hold_flag = `WJE_HoldDisable;
                            jump_addr = `WJE_ZeroWord;
                            mem_wdata_o = `WJE_ZeroWord;
                            mem_raddr_o = `WJE_ZeroWord;
                            mem_waddr_o = `WJE_ZeroWord;
                            mem_we = `WJE_WriteDisable;
                            reg_wdata = {32{(~op1_ge_op2_signed)}} & 32'h1;
                        end
                        `WJE_INST_SLTU: begin
                            jump_flag = `WJE_JumpDisable;
                            hold_flag = `WJE_HoldDisable;
                            jump_addr = `WJE_ZeroWord;
                            mem_wdata_o = `WJE_ZeroWord;
                            mem_raddr_o = `WJE_ZeroWord;
                            mem_waddr_o = `WJE_ZeroWord;
                            mem_we = `WJE_WriteDisable;
                            reg_wdata = {32{(~op1_ge_op2_unsigned)}} & 32'h1;
                        end
                        `WJE_INST_XOR: begin
                            jump_flag = `WJE_JumpDisable;
                            hold_flag = `WJE_HoldDisable;
                            jump_addr = `WJE_ZeroWord;
                            mem_wdata_o = `WJE_ZeroWord;
                            mem_raddr_o = `WJE_ZeroWord;
                            mem_waddr_o = `WJE_ZeroWord;
                            mem_we = `WJE_WriteDisable;
                            reg_wdata = op1_i ^ op2_i;
                        end
                        `WJE_INST_SR: begin
                            jump_flag = `WJE_JumpDisable;
                            hold_flag = `WJE_HoldDisable;
                            jump_addr = `WJE_ZeroWord;
                            mem_wdata_o = `WJE_ZeroWord;
                            mem_raddr_o = `WJE_ZeroWord;
                            mem_waddr_o = `WJE_ZeroWord;
                            mem_we = `WJE_WriteDisable;
                            if (inst_i[30] == 1'b1) begin
                                reg_wdata = (sr_shift & sr_shift_mask) | ({32{reg1_rdata_i[31]}} & (~sr_shift_mask));
                            end else begin
                                reg_wdata = reg1_rdata_i >> reg2_rdata_i[4:0];
                            end
                        end
                        `WJE_INST_OR: begin
                            jump_flag = `WJE_JumpDisable;
                            hold_flag = `WJE_HoldDisable;
                            jump_addr = `WJE_ZeroWord;
                            mem_wdata_o = `WJE_ZeroWord;
                            mem_raddr_o = `WJE_ZeroWord;
                            mem_waddr_o = `WJE_ZeroWord;
                            mem_we = `WJE_WriteDisable;
                            reg_wdata = op1_i | op2_i;
                        end
                        `WJE_INST_AND: begin
                            jump_flag = `WJE_JumpDisable;
                            hold_flag = `WJE_HoldDisable;
                            jump_addr = `WJE_ZeroWord;
                            mem_wdata_o = `WJE_ZeroWord;
                            mem_raddr_o = `WJE_ZeroWord;
                            mem_waddr_o = `WJE_ZeroWord;
                            mem_we = `WJE_WriteDisable;
                            reg_wdata = op1_i & op2_i;
                        end
                        default: begin
                            jump_flag = `WJE_JumpDisable;
                            hold_flag = `WJE_HoldDisable;
                            jump_addr = `WJE_ZeroWord;
                            mem_wdata_o = `WJE_ZeroWord;
                            mem_raddr_o = `WJE_ZeroWord;
                            mem_waddr_o = `WJE_ZeroWord;
                            mem_we = `WJE_WriteDisable;
                            reg_wdata = `WJE_ZeroWord;
                        end
                    endcase
                end else begin

                    jump_flag = `WJE_JumpDisable;
                    hold_flag = `WJE_HoldDisable;
                    jump_addr = `WJE_ZeroWord;
                    mem_wdata_o = `WJE_ZeroWord;
                    mem_raddr_o = `WJE_ZeroWord;
                    mem_waddr_o = `WJE_ZeroWord;
                    mem_we = `WJE_WriteDisable;
                    reg_wdata = `WJE_ZeroWord;
                end
            end
            `WJE_INST_TYPE_L: begin
                case (funct3)
                    `WJE_INST_LB: begin
                        jump_flag = `WJE_JumpDisable;
                        hold_flag = `WJE_HoldDisable;
                        jump_addr = `WJE_ZeroWord;
                        mem_wdata_o = `WJE_ZeroWord;
                        mem_waddr_o = `WJE_ZeroWord;
                        mem_we = `WJE_WriteDisable;
                        mem_req = `WJE_RIB_REQ;
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
                    `WJE_INST_LH: begin
                        jump_flag = `WJE_JumpDisable;
                        hold_flag = `WJE_HoldDisable;
                        jump_addr = `WJE_ZeroWord;
                        mem_wdata_o = `WJE_ZeroWord;
                        mem_waddr_o = `WJE_ZeroWord;
                        mem_we = `WJE_WriteDisable;
                        mem_req = `WJE_RIB_REQ;
                        mem_raddr_o = op1_add_op2_res;
                        if (mem_raddr_index == 2'b0) begin
                            reg_wdata = {{16{mem_rdata_i[15]}}, mem_rdata_i[15:0]};
                        end else begin
                            reg_wdata = {{16{mem_rdata_i[31]}}, mem_rdata_i[31:16]};
                        end
                    end
                    `WJE_INST_LW: begin
                        jump_flag = `WJE_JumpDisable;
                        hold_flag = `WJE_HoldDisable;
                        jump_addr = `WJE_ZeroWord;
                        mem_wdata_o = `WJE_ZeroWord;
                        mem_waddr_o = `WJE_ZeroWord;
                        mem_we = `WJE_WriteDisable;
                        mem_req = `WJE_RIB_REQ;
                        mem_raddr_o = op1_add_op2_res;
                        reg_wdata = mem_rdata_i;
                    end
                    `WJE_INST_LBU: begin
                        jump_flag = `WJE_JumpDisable;
                        hold_flag = `WJE_HoldDisable;
                        jump_addr = `WJE_ZeroWord;
                        mem_wdata_o = `WJE_ZeroWord;
                        mem_waddr_o = `WJE_ZeroWord;
                        mem_we = `WJE_WriteDisable;
                        mem_req = `WJE_RIB_REQ;
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
                    `WJE_INST_LHU: begin
                        jump_flag = `WJE_JumpDisable;
                        hold_flag = `WJE_HoldDisable;
                        jump_addr = `WJE_ZeroWord;
                        mem_wdata_o = `WJE_ZeroWord;
                        mem_waddr_o = `WJE_ZeroWord;
                        mem_we = `WJE_WriteDisable;
                        mem_req = `WJE_RIB_REQ;
                        mem_raddr_o = op1_add_op2_res;
                        if (mem_raddr_index == 2'b0) begin
                            reg_wdata = {16'h0, mem_rdata_i[15:0]};
                        end else begin
                            reg_wdata = {16'h0, mem_rdata_i[31:16]};
                        end
                    end
                    default: begin
                        jump_flag = `WJE_JumpDisable;
                        hold_flag = `WJE_HoldDisable;
                        jump_addr = `WJE_ZeroWord;
                        mem_wdata_o = `WJE_ZeroWord;
                        mem_raddr_o = `WJE_ZeroWord;
                        mem_waddr_o = `WJE_ZeroWord;
                        mem_we = `WJE_WriteDisable;
                        reg_wdata = `WJE_ZeroWord;
                    end
                endcase
            end
            `WJE_INST_TYPE_S: begin
                case (funct3)
                    `WJE_INST_SB: begin
                        jump_flag = `WJE_JumpDisable;
                        hold_flag = `WJE_HoldDisable;
                        jump_addr = `WJE_ZeroWord;
                        reg_wdata = `WJE_ZeroWord;
                        mem_we = `WJE_WriteEnable;
                        mem_req = `WJE_RIB_REQ;
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
                    `WJE_INST_SH: begin
                        jump_flag = `WJE_JumpDisable;
                        hold_flag = `WJE_HoldDisable;
                        jump_addr = `WJE_ZeroWord;
                        reg_wdata = `WJE_ZeroWord;
                        mem_we = `WJE_WriteEnable;
                        mem_req = `WJE_RIB_REQ;
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
                    `WJE_INST_SW: begin
                        jump_flag = `WJE_JumpDisable;
                        hold_flag = `WJE_HoldDisable;
                        jump_addr = `WJE_ZeroWord;
                        reg_wdata = `WJE_ZeroWord;
                        mem_we = `WJE_WriteEnable;
                        mem_req = `WJE_RIB_REQ;
                        mem_waddr_o = op1_add_op2_res;
                        mem_raddr_o = op1_add_op2_res;
                        mem_wdata_o = reg2_rdata_i;
                    end
                    default: begin
                        jump_flag = `WJE_JumpDisable;
                        hold_flag = `WJE_HoldDisable;
                        jump_addr = `WJE_ZeroWord;
                        mem_wdata_o = `WJE_ZeroWord;
                        mem_raddr_o = `WJE_ZeroWord;
                        mem_waddr_o = `WJE_ZeroWord;
                        mem_we = `WJE_WriteDisable;
                        reg_wdata = `WJE_ZeroWord;
                    end
                endcase
            end
            `WJE_INST_TYPE_B: begin
                case (funct3)
                    `WJE_INST_BEQ: begin
                        hold_flag = `WJE_HoldDisable;
                        mem_wdata_o = `WJE_ZeroWord;
                        mem_raddr_o = `WJE_ZeroWord;
                        mem_waddr_o = `WJE_ZeroWord;
                        mem_we = `WJE_WriteDisable;
                        reg_wdata = `WJE_ZeroWord;
                        jump_flag = op1_eq_op2 & `WJE_JumpEnable;
                        jump_addr = {32{op1_eq_op2}} & op1_jump_add_op2_jump_res;
                    end
                    `WJE_INST_BNE: begin
                        hold_flag = `WJE_HoldDisable;
                        mem_wdata_o = `WJE_ZeroWord;
                        mem_raddr_o = `WJE_ZeroWord;
                        mem_waddr_o = `WJE_ZeroWord;
                        mem_we = `WJE_WriteDisable;
                        reg_wdata = `WJE_ZeroWord;
                        jump_flag = (~op1_eq_op2) & `WJE_JumpEnable;
                        jump_addr = {32{(~op1_eq_op2)}} & op1_jump_add_op2_jump_res;
                    end
                    `WJE_INST_BLT: begin
                        hold_flag = `WJE_HoldDisable;
                        mem_wdata_o = `WJE_ZeroWord;
                        mem_raddr_o = `WJE_ZeroWord;
                        mem_waddr_o = `WJE_ZeroWord;
                        mem_we = `WJE_WriteDisable;
                        reg_wdata = `WJE_ZeroWord;
                        jump_flag = (~op1_ge_op2_signed) & `WJE_JumpEnable;
                        jump_addr = {32{(~op1_ge_op2_signed)}} & op1_jump_add_op2_jump_res;
                    end
                    `WJE_INST_BGE: begin
                        hold_flag = `WJE_HoldDisable;
                        mem_wdata_o = `WJE_ZeroWord;
                        mem_raddr_o = `WJE_ZeroWord;
                        mem_waddr_o = `WJE_ZeroWord;
                        mem_we = `WJE_WriteDisable;
                        reg_wdata = `WJE_ZeroWord;
                        jump_flag = (op1_ge_op2_signed) & `WJE_JumpEnable;
                        jump_addr = {32{(op1_ge_op2_signed)}} & op1_jump_add_op2_jump_res;
                    end
                    `WJE_INST_BLTU: begin
                        hold_flag = `WJE_HoldDisable;
                        mem_wdata_o = `WJE_ZeroWord;
                        mem_raddr_o = `WJE_ZeroWord;
                        mem_waddr_o = `WJE_ZeroWord;
                        mem_we = `WJE_WriteDisable;
                        reg_wdata = `WJE_ZeroWord;
                        jump_flag = (~op1_ge_op2_unsigned) & `WJE_JumpEnable;
                        jump_addr = {32{(~op1_ge_op2_unsigned)}} & op1_jump_add_op2_jump_res;
                    end
                    `WJE_INST_BGEU: begin
                        hold_flag = `WJE_HoldDisable;
                        mem_wdata_o = `WJE_ZeroWord;
                        mem_raddr_o = `WJE_ZeroWord;
                        mem_waddr_o = `WJE_ZeroWord;
                        mem_we = `WJE_WriteDisable;
                        reg_wdata = `WJE_ZeroWord;
                        jump_flag = (op1_ge_op2_unsigned) & `WJE_JumpEnable;
                        jump_addr = {32{(op1_ge_op2_unsigned)}} & op1_jump_add_op2_jump_res;
                    end
                    default: begin
                        jump_flag = `WJE_JumpDisable;
                        hold_flag = `WJE_HoldDisable;
                        jump_addr = `WJE_ZeroWord;
                        mem_wdata_o = `WJE_ZeroWord;
                        mem_raddr_o = `WJE_ZeroWord;
                        mem_waddr_o = `WJE_ZeroWord;
                        mem_we = `WJE_WriteDisable;
                        reg_wdata = `WJE_ZeroWord;
                    end
                endcase
            end
            `WJE_INST_JAL, `WJE_INST_JALR: begin
                hold_flag = `WJE_HoldDisable;
                mem_wdata_o = `WJE_ZeroWord;
                mem_raddr_o = `WJE_ZeroWord;
                mem_waddr_o = `WJE_ZeroWord;
                mem_we = `WJE_WriteDisable;
                jump_flag = `WJE_JumpEnable;
                jump_addr = op1_jump_add_op2_jump_res;
                reg_wdata = op1_add_op2_res;
            end
            `WJE_INST_LUI, `WJE_INST_AUIPC: begin
                hold_flag = `WJE_HoldDisable;
                mem_wdata_o = `WJE_ZeroWord;
                mem_raddr_o = `WJE_ZeroWord;
                mem_waddr_o = `WJE_ZeroWord;
                mem_we = `WJE_WriteDisable;
                jump_addr = `WJE_ZeroWord;
                jump_flag = `WJE_JumpDisable;
                reg_wdata = op1_add_op2_res;
            end
            `WJE_INST_NOP_OP: begin
                jump_flag = `WJE_JumpDisable;
                hold_flag = `WJE_HoldDisable;
                jump_addr = `WJE_ZeroWord;
                mem_wdata_o = `WJE_ZeroWord;
                mem_raddr_o = `WJE_ZeroWord;
                mem_waddr_o = `WJE_ZeroWord;
                mem_we = `WJE_WriteDisable;
                reg_wdata = `WJE_ZeroWord;
            end
            `WJE_INST_FENCE: begin
                hold_flag = `WJE_HoldDisable;
                mem_wdata_o = `WJE_ZeroWord;
                mem_raddr_o = `WJE_ZeroWord;
                mem_waddr_o = `WJE_ZeroWord;
                mem_we = `WJE_WriteDisable;
                reg_wdata = `WJE_ZeroWord;
                jump_flag = `WJE_JumpEnable;
                jump_addr = op1_jump_add_op2_jump_res;
            end
            `WJE_INST_TYPE_CUSTOM: begin
                case (funct3)
                    `WJE_INST_SID: begin
                        hold_flag = `WJE_HoldDisable;
                        mem_wdata_o = `WJE_ZeroWord;
                        mem_raddr_o = `WJE_ZeroWord;
                        mem_waddr_o = `WJE_ZeroWord;
                        mem_we = `WJE_WriteDisable;
                        reg_wdata = `WJE_ZeroWord;
                        jump_flag = `WJE_JumpEnable;
                        jump_addr = op1_jump_add_op2_jump_res;
                        sid_start = `WJE_True;
                    end
                    `WJE_INST_RT: begin
                        mem_wdata_o = `WJE_ZeroWord;
                        mem_raddr_o = `WJE_ZeroWord;
                        mem_waddr_o = `WJE_ZeroWord;
                        mem_we = `WJE_WriteDisable;
                        jump_flag = `WJE_JumpDisable;
                        jump_addr = `WJE_ZeroWord;
                        hold_flag = `WJE_HoldDisable;

                        if (temp_done_i == `WJE_True) begin
                            temp_start = `WJE_False;
                            reg_waddr = reg_waddr_i;
                            if (mem_busy_i == `WJE_HoldEnable) begin
                                // Keep the result pending until the pipeline can advance.
                                temp_hold = `WJE_HoldEnable;
                                reg_we = `WJE_WriteDisable;
                                reg_wdata = `WJE_ZeroWord;
                            end else begin
                                temp_hold = `WJE_HoldDisable;
                                temp_accept = `WJE_True;
                                reg_we = `WJE_WriteEnable;
                                if (temp_ack_error_i == `WJE_True) begin
                                    reg_wdata = `WJE_ZeroWord;
                                end else begin
                                    // LM75-style temperature data uses bits [14:7].
                                    reg_wdata = {24'h0, temp_raw_i[14:7]};
                                end
                            end
                        end else begin
                            temp_hold = `WJE_HoldEnable;
                            temp_start = (temp_busy_i == `WJE_False);
                            reg_we = `WJE_WriteDisable;
                            reg_waddr = reg_waddr_i;
                            reg_wdata = `WJE_ZeroWord;
                        end
                    end
                    `WJE_INST_IF: begin
                        mem_wdata_o = `WJE_ZeroWord;
                        mem_raddr_o = `WJE_ZeroWord;
                        mem_waddr_o = `WJE_ZeroWord;
                        mem_we = `WJE_WriteDisable;
                        jump_flag = `WJE_JumpDisable;
                        jump_addr = `WJE_ZeroWord;
                        hold_flag = `WJE_HoldDisable;
                        reg_waddr = reg_waddr_i;

                        if (inst_i[31:20] == 12'b0) begin
                            if (if_fire_enable == `WJE_True) begin
                                if_uart_data = reg1_rdata_i[7:0];
                                if (if_uart_done_i == `WJE_True) begin
                                    if_uart_start = `WJE_False;
                                    if (mem_busy_i == `WJE_HoldEnable) begin
                                        // Keep completion sticky until the
                                        // fetch/memory stall also releases.
                                        if_uart_hold = `WJE_HoldEnable;
                                        if_uart_accept = `WJE_False;
                                        reg_we = `WJE_WriteDisable;
                                        reg_wdata = `WJE_ZeroWord;
                                    end else begin
                                        if_uart_hold = `WJE_HoldDisable;
                                        if_uart_accept = `WJE_True;
                                        reg_we = `WJE_WriteEnable;
                                        reg_wdata = `WJE_ZeroWord;
                                    end
                                end else begin
                                    if_uart_hold = `WJE_HoldEnable;
                                    if_uart_start = (if_uart_busy_i == `WJE_False);
                                    reg_we = `WJE_WriteDisable;
                                    reg_wdata = `WJE_ZeroWord;
                                end
                            end else begin
                                if_uart_hold = `WJE_HoldDisable;
                                if_uart_start = `WJE_False;
                                reg_we = `WJE_WriteEnable;
                                reg_wdata = reg1_rdata_i;
                            end
                        end else begin
                            if_uart_hold = `WJE_HoldDisable;
                            if_uart_start = `WJE_False;
                            reg_we = `WJE_WriteEnable;
                            reg_wdata = op1_add_op2_res;
                        end
                    end
                    default: begin
                        jump_flag = `WJE_JumpDisable;
                        hold_flag = `WJE_HoldDisable;
                        jump_addr = `WJE_ZeroWord;
                        mem_wdata_o = `WJE_ZeroWord;
                        mem_raddr_o = `WJE_ZeroWord;
                        mem_waddr_o = `WJE_ZeroWord;
                        mem_we = `WJE_WriteDisable;
                        reg_wdata = `WJE_ZeroWord;
                    end
                endcase
            end
            default: begin
                jump_flag = `WJE_JumpDisable;
                hold_flag = `WJE_HoldDisable;
                jump_addr = `WJE_ZeroWord;
                mem_wdata_o = `WJE_ZeroWord;
                mem_raddr_o = `WJE_ZeroWord;
                mem_waddr_o = `WJE_ZeroWord;
                mem_we = `WJE_WriteDisable;
                reg_wdata = `WJE_ZeroWord;
            end
        endcase
    end

endmodule
