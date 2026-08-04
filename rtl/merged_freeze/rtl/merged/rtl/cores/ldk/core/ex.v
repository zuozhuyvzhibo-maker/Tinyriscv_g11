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
module ldk_ex(

    input wire clk,
    input wire rst,

    // from id
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

    // from mem
    input wire[`LDK_MemBus] mem_rdata_i,
    input wire mem_ack_i,

    input wire ext_inst_start_i,


    // to mem
    output reg[`LDK_MemBus] mem_wdata_o,
    output reg[`LDK_MemAddrBus] mem_raddr_o,
    output reg[`LDK_MemAddrBus] mem_waddr_o,
    output wire mem_we_o,
    output wire mem_req_o,
    output wire mem_no_ack_o,

    // to regs
    output wire[`LDK_RegBus] reg_wdata_o,
    output wire reg_we_o,
    output wire[`LDK_RegAddrBus] reg_waddr_o,

    // to ctrl
    output wire ext_inst_done_o,
    output wire ife_use_uart_o,
    output wire hold_flag_o,
    output wire jump_flag_o,
    output wire[`LDK_InstAddrBus] jump_addr_o

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
    wire[6:0] opcode;
    wire[2:0] funct3;
    wire[6:0] funct7;
    wire[4:0] rd;
    wire[4:0] uimm;
    reg[`LDK_RegBus] reg_wdata;
    reg reg_we;
    reg[`LDK_RegAddrBus] reg_waddr;
    reg hold_flag;
    reg jump_flag;
    reg[`LDK_InstAddrBus] jump_addr;
    reg mem_we;
    reg mem_req;

    localparam [`LDK_MemAddrBus] SID_UART_CTRL_ADDR   = 32'h3000_0000 ;
    localparam [`LDK_MemAddrBus] SID_UART_STATUS_ADDR = 32'h3000_0004 ;
    localparam [`LDK_MemAddrBus] SID_UART_TXDATA_ADDR = 32'h3000_000c ;
    localparam [`LDK_MemAddrBus] IIC_ADDR_REG_ADDR    = 32'h7001_0000 ;
    localparam [`LDK_MemAddrBus] IIC_DATAOUT_REG_ADDR = 32'h7002_0000 ;
    localparam [`LDK_MemAddrBus] IIC_DATAIN_REG_ADDR  = 32'h7003_0000 ;
    localparam [`LDK_MemAddrBus] IIC_LM75_ADDR        = 32'h0000_0091 ;

    localparam [2:0] SID_IDLE        = 3'd0;
    localparam [2:0] SID_CTRL_WRITE  = 3'd1;
    localparam [2:0] SID_DATA_WRITE  = 3'd2;
    localparam [2:0] SID_STATUS_READ = 3'd3;
    localparam [2:0] SID_DONE        = 3'd4;

    reg[2:0] sid_state;
    reg[3:0] sid_index;
    wire is_sid_inst;
    wire is_ife_inst;
    wire is_rt_inst;
    wire ife_imm_is_zero;
    wire ife_uart_active;
    wire[31:0] ife_imm_ext;
    wire[7:0] uart_tx_data;
    wire ext_isd_ife_inst_done;
    wire ext_rt_inst_done;

    function [3:0] sid_number_lsb;
        input [3:0] index;
        begin
            case (index)
                4'd0: sid_number_lsb = 4'h2;
                4'd1: sid_number_lsb = 4'h0;
                4'd2: sid_number_lsb = 4'h2;
                4'd3: sid_number_lsb = 4'h5;
                4'd4: sid_number_lsb = 4'h2;
                4'd5: sid_number_lsb = 4'h1;
                4'd6: sid_number_lsb = 4'h0;
                4'd7: sid_number_lsb = 4'h9;
                4'd8: sid_number_lsb = 4'h0;
                4'd9: sid_number_lsb = 4'h5;
                default: sid_number_lsb = 4'h0;
            endcase
        end
    endfunction

    assign opcode = inst_i[6:0];
    assign funct3 = inst_i[14:12];
    assign funct7 = inst_i[31:25];
    assign rd = inst_i[11:7];
    assign uimm = inst_i[19:15];
    assign is_sid_inst = (opcode == `LDK_INST_EXTEND) && (funct3 == `LDK_INST_SID);
    assign is_ife_inst = (opcode == `LDK_INST_EXTEND) && (funct3 == `LDK_INST_IFE);
    assign is_rt_inst = (opcode == `LDK_INST_EXTEND) && (funct3 == `LDK_INST_RT);
    assign ife_imm_is_zero = (inst_i[31:20] == 12'd0);
    assign ife_imm_ext = {{20{inst_i[31]}}, inst_i[31:20]};
    assign ife_use_uart_o = is_ife_inst && ife_imm_is_zero && op1_ge_op2_unsigned;
    assign ife_uart_active = is_ife_inst && ife_use_uart_o;
    assign uart_tx_data = is_sid_inst ? {4'h3, sid_number_lsb(sid_index)} : op1_i[7:0];
    assign ext_isd_ife_inst_done = (sid_state == SID_DONE) ? `LDK_EXT_INST_DONE : `LDK_EXT_INST_NOT_DONE;
    assign ext_rt_inst_done = is_rt_inst && mem_ack_i ;
    assign ext_inst_done_o = ext_isd_ife_inst_done || ext_rt_inst_done ;

    assign sr_shift = reg1_rdata_i >> reg2_rdata_i[4:0];
    assign sri_shift = reg1_rdata_i >> inst_i[24:20];
    assign sr_shift_mask = 32'hffffffff >> reg2_rdata_i[4:0];
    assign sri_shift_mask = 32'hffffffff >> inst_i[24:20];

    assign op1_add_op2_res = is_ife_inst ? ( op1_i + {{20{inst_i[31]}}, inst_i[31:20]} ) : ( op1_i + op2_i );
    assign op1_jump_add_op2_jump_res = op1_jump_i + op2_jump_i;

    assign reg1_data_invert = ~reg1_rdata_i + 1;
    assign reg2_data_invert = ~reg2_rdata_i + 1;


    assign op1_ge_op2_signed = $signed(op1_i) >= $signed(op2_i);

    assign op1_ge_op2_unsigned = op1_i >= op2_i;
    assign op1_eq_op2 = (op1_i == op2_i);


    assign mem_raddr_index = (reg1_rdata_i + {{20{inst_i[31]}}, inst_i[31:20]}) & 2'b11;
    assign mem_waddr_index = (reg1_rdata_i + {{20{inst_i[31]}}, inst_i[31:25], inst_i[11:7]}) & 2'b11;
    assign mem_no_ack_o = ((opcode == `LDK_INST_TYPE_L) &&
                           (mem_raddr_o[31:28] != 4'h0) &&
                           (mem_raddr_o[31:28] != 4'h1)) ||
                          ((opcode == `LDK_INST_TYPE_S) &&
                           (mem_waddr_o[31:28] != 4'h0) &&
                           (mem_waddr_o[31:28] != 4'h1));

    always @(posedge clk) begin
        if (rst == `LDK_RstEnable) begin
            sid_state <= SID_IDLE;
            sid_index <= 4'd0;
        end else begin
            case (sid_state)
                SID_IDLE: begin
                    sid_index <= 4'd0;
                    if ((ext_inst_start_i == `LDK_True) && (is_sid_inst || ife_uart_active)) begin
                        sid_state <= SID_CTRL_WRITE;
                    end else begin
                        sid_state <= SID_IDLE;
                    end
                end
                SID_CTRL_WRITE: begin
                    sid_state <= SID_DATA_WRITE;
                end
                SID_DATA_WRITE: begin
                    sid_state <= SID_STATUS_READ;
                end
                SID_STATUS_READ: begin
                    if (mem_rdata_i[0] == 1'b0) begin
                        if (ife_uart_active || (sid_index == 4'd9)) begin
                            sid_state <= SID_DONE;
                        end else begin
                            sid_index <= sid_index + 1'b1;
                            sid_state <= SID_DATA_WRITE;
                        end
                    end else begin
                        sid_state <= SID_STATUS_READ;
                    end
                end
                SID_DONE: begin
                    sid_state <= SID_IDLE;
                    sid_index <= 4'd0;
                end
                default: begin
                    sid_state <= SID_IDLE;
                    sid_index <= 4'd0;
                end
            endcase
        end
    end

    assign reg_wdata_o = reg_wdata ;

    assign reg_we_o = reg_we ;
    assign reg_waddr_o = reg_waddr ;


    assign mem_we_o = mem_we;


    assign mem_req_o = mem_req;

    assign hold_flag_o = hold_flag ;
    assign jump_flag_o = jump_flag ;
    assign jump_addr_o = jump_addr ;


    always @ (*) begin
        reg_we = reg_we_i;
        reg_waddr = reg_waddr_i;
        mem_req = `LDK_RIB_NREQ;

        case (opcode)
            `LDK_INST_TYPE_I: begin
                case (funct3)
                    `LDK_INST_ADDI: begin
                        jump_flag = `LDK_JumpDisable;
                        hold_flag = `LDK_HoldDisable;
                        jump_addr = `LDK_ZeroWord;
                        mem_wdata_o = `LDK_ZeroWord;
                        mem_raddr_o = `LDK_ZeroWord;
                        mem_waddr_o = `LDK_ZeroWord;
                        mem_we = `LDK_WriteDisable;
                        reg_wdata = op1_add_op2_res;
                    end
                    `LDK_INST_SLTI: begin
                        jump_flag = `LDK_JumpDisable;
                        hold_flag = `LDK_HoldDisable;
                        jump_addr = `LDK_ZeroWord;
                        mem_wdata_o = `LDK_ZeroWord;
                        mem_raddr_o = `LDK_ZeroWord;
                        mem_waddr_o = `LDK_ZeroWord;
                        mem_we = `LDK_WriteDisable;
                        reg_wdata = {32{(~op1_ge_op2_signed)}} & 32'h1;
                    end
                    `LDK_INST_SLTIU: begin
                        jump_flag = `LDK_JumpDisable;
                        hold_flag = `LDK_HoldDisable;
                        jump_addr = `LDK_ZeroWord;
                        mem_wdata_o = `LDK_ZeroWord;
                        mem_raddr_o = `LDK_ZeroWord;
                        mem_waddr_o = `LDK_ZeroWord;
                        mem_we = `LDK_WriteDisable;
                        reg_wdata = {32{(~op1_ge_op2_unsigned)}} & 32'h1;
                    end
                    `LDK_INST_XORI: begin
                        jump_flag = `LDK_JumpDisable;
                        hold_flag = `LDK_HoldDisable;
                        jump_addr = `LDK_ZeroWord;
                        mem_wdata_o = `LDK_ZeroWord;
                        mem_raddr_o = `LDK_ZeroWord;
                        mem_waddr_o = `LDK_ZeroWord;
                        mem_we = `LDK_WriteDisable;
                        reg_wdata = op1_i ^ op2_i;
                    end
                    `LDK_INST_ORI: begin
                        jump_flag = `LDK_JumpDisable;
                        hold_flag = `LDK_HoldDisable;
                        jump_addr = `LDK_ZeroWord;
                        mem_wdata_o = `LDK_ZeroWord;
                        mem_raddr_o = `LDK_ZeroWord;
                        mem_waddr_o = `LDK_ZeroWord;
                        mem_we = `LDK_WriteDisable;
                        reg_wdata = op1_i | op2_i;
                    end
                    `LDK_INST_ANDI: begin
                        jump_flag = `LDK_JumpDisable;
                        hold_flag = `LDK_HoldDisable;
                        jump_addr = `LDK_ZeroWord;
                        mem_wdata_o = `LDK_ZeroWord;
                        mem_raddr_o = `LDK_ZeroWord;
                        mem_waddr_o = `LDK_ZeroWord;
                        mem_we = `LDK_WriteDisable;
                        reg_wdata = op1_i & op2_i;
                    end
                    `LDK_INST_SLLI: begin
                        jump_flag = `LDK_JumpDisable;
                        hold_flag = `LDK_HoldDisable;
                        jump_addr = `LDK_ZeroWord;
                        mem_wdata_o = `LDK_ZeroWord;
                        mem_raddr_o = `LDK_ZeroWord;
                        mem_waddr_o = `LDK_ZeroWord;
                        mem_we = `LDK_WriteDisable;
                        reg_wdata = reg1_rdata_i << inst_i[24:20];
                    end
                    `LDK_INST_SRI: begin
                        jump_flag = `LDK_JumpDisable;
                        hold_flag = `LDK_HoldDisable;
                        jump_addr = `LDK_ZeroWord;
                        mem_wdata_o = `LDK_ZeroWord;
                        mem_raddr_o = `LDK_ZeroWord;
                        mem_waddr_o = `LDK_ZeroWord;
                        mem_we = `LDK_WriteDisable;
                        if (inst_i[30] == 1'b1) begin
                            reg_wdata = (sri_shift & sri_shift_mask) | ({32{reg1_rdata_i[31]}} & (~sri_shift_mask));
                        end else begin
                            reg_wdata = reg1_rdata_i >> inst_i[24:20];
                        end
                    end
                    default: begin
                        jump_flag = `LDK_JumpDisable;
                        hold_flag = `LDK_HoldDisable;
                        jump_addr = `LDK_ZeroWord;
                        mem_wdata_o = `LDK_ZeroWord;
                        mem_raddr_o = `LDK_ZeroWord;
                        mem_waddr_o = `LDK_ZeroWord;
                        mem_we = `LDK_WriteDisable;
                        reg_wdata = `LDK_ZeroWord;
                    end
                endcase
            end
            `LDK_INST_TYPE_R_M: begin
                if ((funct7 == 7'b0000000) || (funct7 == 7'b0100000)) begin
                    case (funct3)
                        `LDK_INST_ADD_SUB: begin
                            jump_flag = `LDK_JumpDisable;
                            hold_flag = `LDK_HoldDisable;
                            jump_addr = `LDK_ZeroWord;
                            mem_wdata_o = `LDK_ZeroWord;
                            mem_raddr_o = `LDK_ZeroWord;
                            mem_waddr_o = `LDK_ZeroWord;
                            mem_we = `LDK_WriteDisable;
                            if (inst_i[30] == 1'b0) begin
                                reg_wdata = op1_add_op2_res;
                            end else begin
                                reg_wdata = op1_i - op2_i;
                            end
                        end
                        `LDK_INST_SLL: begin
                            jump_flag = `LDK_JumpDisable;
                            hold_flag = `LDK_HoldDisable;
                            jump_addr = `LDK_ZeroWord;
                            mem_wdata_o = `LDK_ZeroWord;
                            mem_raddr_o = `LDK_ZeroWord;
                            mem_waddr_o = `LDK_ZeroWord;
                            mem_we = `LDK_WriteDisable;
                            reg_wdata = op1_i << op2_i[4:0];
                        end
                        `LDK_INST_SLT: begin
                            jump_flag = `LDK_JumpDisable;
                            hold_flag = `LDK_HoldDisable;
                            jump_addr = `LDK_ZeroWord;
                            mem_wdata_o = `LDK_ZeroWord;
                            mem_raddr_o = `LDK_ZeroWord;
                            mem_waddr_o = `LDK_ZeroWord;
                            mem_we = `LDK_WriteDisable;
                            reg_wdata = {32{(~op1_ge_op2_signed)}} & 32'h1;
                        end
                        `LDK_INST_SLTU: begin
                            jump_flag = `LDK_JumpDisable;
                            hold_flag = `LDK_HoldDisable;
                            jump_addr = `LDK_ZeroWord;
                            mem_wdata_o = `LDK_ZeroWord;
                            mem_raddr_o = `LDK_ZeroWord;
                            mem_waddr_o = `LDK_ZeroWord;
                            mem_we = `LDK_WriteDisable;
                            reg_wdata = {32{(~op1_ge_op2_unsigned)}} & 32'h1;
                        end
                        `LDK_INST_XOR: begin
                            jump_flag = `LDK_JumpDisable;
                            hold_flag = `LDK_HoldDisable;
                            jump_addr = `LDK_ZeroWord;
                            mem_wdata_o = `LDK_ZeroWord;
                            mem_raddr_o = `LDK_ZeroWord;
                            mem_waddr_o = `LDK_ZeroWord;
                            mem_we = `LDK_WriteDisable;
                            reg_wdata = op1_i ^ op2_i;
                        end
                        `LDK_INST_SR: begin
                            jump_flag = `LDK_JumpDisable;
                            hold_flag = `LDK_HoldDisable;
                            jump_addr = `LDK_ZeroWord;
                            mem_wdata_o = `LDK_ZeroWord;
                            mem_raddr_o = `LDK_ZeroWord;
                            mem_waddr_o = `LDK_ZeroWord;
                            mem_we = `LDK_WriteDisable;
                            if (inst_i[30] == 1'b1) begin
                                reg_wdata = (sr_shift & sr_shift_mask) | ({32{reg1_rdata_i[31]}} & (~sr_shift_mask));
                            end else begin
                                reg_wdata = reg1_rdata_i >> reg2_rdata_i[4:0];
                            end
                        end
                        `LDK_INST_OR: begin
                            jump_flag = `LDK_JumpDisable;
                            hold_flag = `LDK_HoldDisable;
                            jump_addr = `LDK_ZeroWord;
                            mem_wdata_o = `LDK_ZeroWord;
                            mem_raddr_o = `LDK_ZeroWord;
                            mem_waddr_o = `LDK_ZeroWord;
                            mem_we = `LDK_WriteDisable;
                            reg_wdata = op1_i | op2_i;
                        end
                        `LDK_INST_AND: begin
                            jump_flag = `LDK_JumpDisable;
                            hold_flag = `LDK_HoldDisable;
                            jump_addr = `LDK_ZeroWord;
                            mem_wdata_o = `LDK_ZeroWord;
                            mem_raddr_o = `LDK_ZeroWord;
                            mem_waddr_o = `LDK_ZeroWord;
                            mem_we = `LDK_WriteDisable;
                            reg_wdata = op1_i & op2_i;
                        end
                        default: begin
                            jump_flag = `LDK_JumpDisable;
                            hold_flag = `LDK_HoldDisable;
                            jump_addr = `LDK_ZeroWord;
                            mem_wdata_o = `LDK_ZeroWord;
                            mem_raddr_o = `LDK_ZeroWord;
                            mem_waddr_o = `LDK_ZeroWord;
                            mem_we = `LDK_WriteDisable;
                            reg_wdata = `LDK_ZeroWord;
                        end
                    endcase
                end else begin
                    jump_flag = `LDK_JumpDisable;
                    hold_flag = `LDK_HoldDisable;
                    jump_addr = `LDK_ZeroWord;
                    mem_wdata_o = `LDK_ZeroWord;
                    mem_raddr_o = `LDK_ZeroWord;
                    mem_waddr_o = `LDK_ZeroWord;
                    mem_we = `LDK_WriteDisable;
                    reg_wdata = `LDK_ZeroWord;
                end
            end
            `LDK_INST_TYPE_L: begin
                case (funct3)
                    `LDK_INST_LB: begin
                        jump_flag = `LDK_JumpDisable;
                        hold_flag = `LDK_HoldDisable;
                        jump_addr = `LDK_ZeroWord;
                        mem_wdata_o = `LDK_ZeroWord;
                        mem_waddr_o = `LDK_ZeroWord;
                        mem_we = `LDK_WriteDisable;
                        mem_req = `LDK_RIB_REQ;
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
                    `LDK_INST_LH: begin
                        jump_flag = `LDK_JumpDisable;
                        hold_flag = `LDK_HoldDisable;
                        jump_addr = `LDK_ZeroWord;
                        mem_wdata_o = `LDK_ZeroWord;
                        mem_waddr_o = `LDK_ZeroWord;
                        mem_we = `LDK_WriteDisable;
                        mem_req = `LDK_RIB_REQ;
                        mem_raddr_o = op1_add_op2_res;
                        if (mem_raddr_index == 2'b0) begin
                            reg_wdata = {{16{mem_rdata_i[15]}}, mem_rdata_i[15:0]};
                        end else begin
                            reg_wdata = {{16{mem_rdata_i[31]}}, mem_rdata_i[31:16]};
                        end
                    end
                    `LDK_INST_LW: begin
                        jump_flag = `LDK_JumpDisable;
                        hold_flag = `LDK_HoldDisable;
                        jump_addr = `LDK_ZeroWord;
                        mem_wdata_o = `LDK_ZeroWord;
                        mem_waddr_o = `LDK_ZeroWord;
                        mem_we = `LDK_WriteDisable;
                        mem_req = `LDK_RIB_REQ;
                        mem_raddr_o = op1_add_op2_res;
                        reg_wdata = mem_rdata_i;
                    end
                    `LDK_INST_LBU: begin
                        jump_flag = `LDK_JumpDisable;
                        hold_flag = `LDK_HoldDisable;
                        jump_addr = `LDK_ZeroWord;
                        mem_wdata_o = `LDK_ZeroWord;
                        mem_waddr_o = `LDK_ZeroWord;
                        mem_we = `LDK_WriteDisable;
                        mem_req = `LDK_RIB_REQ;
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
                    `LDK_INST_LHU: begin
                        jump_flag = `LDK_JumpDisable;
                        hold_flag = `LDK_HoldDisable;
                        jump_addr = `LDK_ZeroWord;
                        mem_wdata_o = `LDK_ZeroWord;
                        mem_waddr_o = `LDK_ZeroWord;
                        mem_we = `LDK_WriteDisable;
                        mem_req = `LDK_RIB_REQ;
                        mem_raddr_o = op1_add_op2_res;
                        if (mem_raddr_index == 2'b0) begin
                            reg_wdata = {16'h0, mem_rdata_i[15:0]};
                        end else begin
                            reg_wdata = {16'h0, mem_rdata_i[31:16]};
                        end
                    end
                    default: begin
                        jump_flag = `LDK_JumpDisable;
                        hold_flag = `LDK_HoldDisable;
                        jump_addr = `LDK_ZeroWord;
                        mem_wdata_o = `LDK_ZeroWord;
                        mem_raddr_o = `LDK_ZeroWord;
                        mem_waddr_o = `LDK_ZeroWord;
                        mem_we = `LDK_WriteDisable;
                        reg_wdata = `LDK_ZeroWord;
                    end
                endcase
            end
            `LDK_INST_TYPE_S: begin
                case (funct3)
                    `LDK_INST_SB: begin
                        jump_flag = `LDK_JumpDisable;
                        hold_flag = `LDK_HoldDisable;
                        jump_addr = `LDK_ZeroWord;
                        reg_wdata = `LDK_ZeroWord;
                        mem_we = `LDK_WriteEnable;
                        mem_req = `LDK_RIB_REQ;
                        mem_waddr_o = op1_add_op2_res;
                        mem_raddr_o = op1_add_op2_res;
                        case (mem_waddr_index)
                            2'b00: begin
                                mem_wdata_o = {mem_rdata_i[31:8], reg2_rdata_i[7:0]};
                            end
                            2'b01: begin
                                mem_wdata_o = {mem_rdata_i[31:16], reg2_rdata_i[7:0], mem_rdata_i[7:0]};
                            end
                            2'b10: begin
                                mem_wdata_o = {mem_rdata_i[31:24], reg2_rdata_i[7:0], mem_rdata_i[15:0]};
                            end
                            default: begin
                                mem_wdata_o = {reg2_rdata_i[7:0], mem_rdata_i[23:0]};
                            end
                        endcase
                    end
                    `LDK_INST_SH: begin
                        jump_flag = `LDK_JumpDisable;
                        hold_flag = `LDK_HoldDisable;
                        jump_addr = `LDK_ZeroWord;
                        reg_wdata = `LDK_ZeroWord;
                        mem_we = `LDK_WriteEnable;
                        mem_req = `LDK_RIB_REQ;
                        mem_waddr_o = op1_add_op2_res;
                        mem_raddr_o = op1_add_op2_res;
                        if (mem_waddr_index == 2'b00) begin
                            mem_wdata_o = {mem_rdata_i[31:16], reg2_rdata_i[15:0]};
                        end else begin
                            mem_wdata_o = {reg2_rdata_i[15:0], mem_rdata_i[15:0]};
                        end
                    end
                    `LDK_INST_SW: begin
                        jump_flag = `LDK_JumpDisable;
                        hold_flag = `LDK_HoldDisable;
                        jump_addr = `LDK_ZeroWord;
                        reg_wdata = `LDK_ZeroWord;
                        mem_we = `LDK_WriteEnable;
                        mem_req = `LDK_RIB_REQ;
                        mem_waddr_o = op1_add_op2_res;
                        mem_raddr_o = op1_add_op2_res;
                        mem_wdata_o = reg2_rdata_i;
                    end
                    default: begin
                        jump_flag = `LDK_JumpDisable;
                        hold_flag = `LDK_HoldDisable;
                        jump_addr = `LDK_ZeroWord;
                        mem_wdata_o = `LDK_ZeroWord;
                        mem_raddr_o = `LDK_ZeroWord;
                        mem_waddr_o = `LDK_ZeroWord;
                        mem_we = `LDK_WriteDisable;
                        reg_wdata = `LDK_ZeroWord;
                    end
                endcase
            end
            `LDK_INST_TYPE_B: begin
                case (funct3)
                    `LDK_INST_BEQ: begin
                        hold_flag = `LDK_HoldDisable;
                        mem_wdata_o = `LDK_ZeroWord;
                        mem_raddr_o = `LDK_ZeroWord;
                        mem_waddr_o = `LDK_ZeroWord;
                        mem_we = `LDK_WriteDisable;
                        reg_wdata = `LDK_ZeroWord;
                        jump_flag = op1_eq_op2 & `LDK_JumpEnable;
                        jump_addr = {32{op1_eq_op2}} & op1_jump_add_op2_jump_res;
                    end
                    `LDK_INST_BNE: begin
                        hold_flag = `LDK_HoldDisable;
                        mem_wdata_o = `LDK_ZeroWord;
                        mem_raddr_o = `LDK_ZeroWord;
                        mem_waddr_o = `LDK_ZeroWord;
                        mem_we = `LDK_WriteDisable;
                        reg_wdata = `LDK_ZeroWord;
                        jump_flag = (~op1_eq_op2) & `LDK_JumpEnable;
                        jump_addr = {32{(~op1_eq_op2)}} & op1_jump_add_op2_jump_res;
                    end
                    `LDK_INST_BLT: begin
                        hold_flag = `LDK_HoldDisable;
                        mem_wdata_o = `LDK_ZeroWord;
                        mem_raddr_o = `LDK_ZeroWord;
                        mem_waddr_o = `LDK_ZeroWord;
                        mem_we = `LDK_WriteDisable;
                        reg_wdata = `LDK_ZeroWord;
                        jump_flag = (~op1_ge_op2_signed) & `LDK_JumpEnable;
                        jump_addr = {32{(~op1_ge_op2_signed)}} & op1_jump_add_op2_jump_res;
                    end
                    `LDK_INST_BGE: begin
                        hold_flag = `LDK_HoldDisable;
                        mem_wdata_o = `LDK_ZeroWord;
                        mem_raddr_o = `LDK_ZeroWord;
                        mem_waddr_o = `LDK_ZeroWord;
                        mem_we = `LDK_WriteDisable;
                        reg_wdata = `LDK_ZeroWord;
                        jump_flag = (op1_ge_op2_signed) & `LDK_JumpEnable;
                        jump_addr = {32{(op1_ge_op2_signed)}} & op1_jump_add_op2_jump_res;
                    end
                    `LDK_INST_BLTU: begin
                        hold_flag = `LDK_HoldDisable;
                        mem_wdata_o = `LDK_ZeroWord;
                        mem_raddr_o = `LDK_ZeroWord;
                        mem_waddr_o = `LDK_ZeroWord;
                        mem_we = `LDK_WriteDisable;
                        reg_wdata = `LDK_ZeroWord;
                        jump_flag = (~op1_ge_op2_unsigned) & `LDK_JumpEnable;
                        jump_addr = {32{(~op1_ge_op2_unsigned)}} & op1_jump_add_op2_jump_res;
                    end
                    `LDK_INST_BGEU: begin
                        hold_flag = `LDK_HoldDisable;
                        mem_wdata_o = `LDK_ZeroWord;
                        mem_raddr_o = `LDK_ZeroWord;
                        mem_waddr_o = `LDK_ZeroWord;
                        mem_we = `LDK_WriteDisable;
                        reg_wdata = `LDK_ZeroWord;
                        jump_flag = (op1_ge_op2_unsigned) & `LDK_JumpEnable;
                        jump_addr = {32{(op1_ge_op2_unsigned)}} & op1_jump_add_op2_jump_res;
                    end
                    default: begin
                        jump_flag = `LDK_JumpDisable;
                        hold_flag = `LDK_HoldDisable;
                        jump_addr = `LDK_ZeroWord;
                        mem_wdata_o = `LDK_ZeroWord;
                        mem_raddr_o = `LDK_ZeroWord;
                        mem_waddr_o = `LDK_ZeroWord;
                        mem_we = `LDK_WriteDisable;
                        reg_wdata = `LDK_ZeroWord;
                    end
                endcase
            end
            `LDK_INST_JAL, `LDK_INST_JALR: begin
                hold_flag = `LDK_HoldDisable;
                mem_wdata_o = `LDK_ZeroWord;
                mem_raddr_o = `LDK_ZeroWord;
                mem_waddr_o = `LDK_ZeroWord;
                mem_we = `LDK_WriteDisable;
                jump_flag = `LDK_JumpEnable;
                jump_addr = op1_jump_add_op2_jump_res;
                reg_wdata = op1_add_op2_res;
            end
            `LDK_INST_LUI, `LDK_INST_AUIPC: begin
                hold_flag = `LDK_HoldDisable;
                mem_wdata_o = `LDK_ZeroWord;
                mem_raddr_o = `LDK_ZeroWord;
                mem_waddr_o = `LDK_ZeroWord;
                mem_we = `LDK_WriteDisable;
                jump_addr = `LDK_ZeroWord;
                jump_flag = `LDK_JumpDisable;
                reg_wdata = op1_add_op2_res;
            end
            `LDK_INST_NOP_OP: begin
                jump_flag = `LDK_JumpDisable;
                hold_flag = `LDK_HoldDisable;
                jump_addr = `LDK_ZeroWord;
                mem_wdata_o = `LDK_ZeroWord;
                mem_raddr_o = `LDK_ZeroWord;
                mem_waddr_o = `LDK_ZeroWord;
                mem_we = `LDK_WriteDisable;
                reg_wdata = `LDK_ZeroWord;
            end
            `LDK_INST_FENCE: begin
                hold_flag = `LDK_HoldDisable;
                mem_wdata_o = `LDK_ZeroWord;
                mem_raddr_o = `LDK_ZeroWord;
                mem_waddr_o = `LDK_ZeroWord;
                mem_we = `LDK_WriteDisable;
                reg_wdata = `LDK_ZeroWord;
                jump_flag = `LDK_JumpEnable;
                jump_addr = op1_jump_add_op2_jump_res;
            end
            `LDK_INST_EXTEND: begin
                jump_flag = `LDK_JumpDisable;
                hold_flag = `LDK_HoldDisable;
                jump_addr = `LDK_ZeroWord;
                mem_wdata_o = `LDK_ZeroWord;
                mem_raddr_o = `LDK_ZeroWord;
                mem_waddr_o = `LDK_ZeroWord;
                mem_we = `LDK_WriteDisable;
                reg_we = `LDK_WriteDisable;
                reg_wdata = `LDK_ZeroWord;
                case ( funct3 )
                    `LDK_INST_SID: begin

                        jump_flag = `LDK_JumpDisable ;
                        jump_addr = `LDK_ZeroWord ;

                        hold_flag = `LDK_HoldDisable ;

                        reg_wdata = `LDK_ZeroWord ;

                        reg_we = `LDK_WriteDisable;
                        mem_we = ((sid_state == SID_CTRL_WRITE) || (sid_state == SID_DATA_WRITE)) ? `LDK_WriteEnable : `LDK_WriteDisable;
                        mem_req = ((sid_state == SID_CTRL_WRITE) || (sid_state == SID_DATA_WRITE) || (sid_state == SID_STATUS_READ)) ? `LDK_RIB_REQ : `LDK_RIB_NREQ;
                        mem_waddr_o = (sid_state == SID_CTRL_WRITE) ? SID_UART_CTRL_ADDR : SID_UART_TXDATA_ADDR;
                        mem_raddr_o = SID_UART_STATUS_ADDR;
                        mem_wdata_o = (sid_state == SID_CTRL_WRITE) ? 32'h1 :
                                      ((sid_state == SID_DATA_WRITE) ? {24'h0, 4'h3, sid_number_lsb(sid_index)} : `LDK_ZeroWord);
                    end
                    `LDK_INST_RT: begin

                        jump_flag = `LDK_JumpDisable ;
                        jump_addr = `LDK_ZeroWord ;

                        hold_flag = `LDK_HoldDisable ;

                        reg_wdata = { 24'd0, mem_rdata_i[14:7] } ;

                        reg_we = `LDK_WriteEnable;
                        mem_we = `LDK_WriteEnable ;
                        mem_req = `LDK_RIB_REQ ;
                        mem_waddr_o = IIC_ADDR_REG_ADDR ;
                        mem_raddr_o = IIC_DATAOUT_REG_ADDR ;
                        mem_wdata_o = IIC_LM75_ADDR ;
                    end
                    `LDK_INST_IFE:begin

                        jump_flag = `LDK_JumpDisable ;
                        jump_addr = `LDK_ZeroWord ;

                        hold_flag = `LDK_HoldDisable ;

                        reg_we = `LDK_WriteEnable;
                        reg_wdata = ife_imm_is_zero ? (op1_ge_op2_unsigned ? `LDK_ZeroWord : op1_i) :
                                                       (op1_i + ife_imm_ext);
                        mem_we = ((sid_state == SID_CTRL_WRITE) || (sid_state == SID_DATA_WRITE)) ? `LDK_WriteEnable : `LDK_WriteDisable;
                        mem_req = ((sid_state == SID_CTRL_WRITE) || (sid_state == SID_DATA_WRITE) || (sid_state == SID_STATUS_READ)) ? `LDK_RIB_REQ : `LDK_RIB_NREQ;
                        mem_waddr_o = (sid_state == SID_CTRL_WRITE) ? SID_UART_CTRL_ADDR : SID_UART_TXDATA_ADDR;
                        mem_raddr_o = SID_UART_STATUS_ADDR;
                        mem_wdata_o = (sid_state == SID_CTRL_WRITE) ? 32'h1 :
                                      ((sid_state == SID_DATA_WRITE) ? {24'h0, uart_tx_data} : `LDK_ZeroWord);
                    end
                    default : begin
                        jump_flag = `LDK_JumpDisable;
                        hold_flag = `LDK_HoldDisable;
                        jump_addr = `LDK_ZeroWord;
                        mem_wdata_o = `LDK_ZeroWord;
                        mem_raddr_o = `LDK_ZeroWord;
                        mem_waddr_o = `LDK_ZeroWord;
                        mem_we = `LDK_WriteDisable;
                        reg_we = `LDK_WriteDisable;
                        reg_wdata = `LDK_ZeroWord;
                    end
                endcase
            end
            default: begin
                jump_flag = `LDK_JumpDisable;
                hold_flag = `LDK_HoldDisable;
                jump_addr = `LDK_ZeroWord;
                mem_wdata_o = `LDK_ZeroWord;
                mem_raddr_o = `LDK_ZeroWord;
                mem_waddr_o = `LDK_ZeroWord;
                mem_we = `LDK_WriteDisable;
                reg_wdata = `LDK_ZeroWord;
            end
        endcase
    end

endmodule
