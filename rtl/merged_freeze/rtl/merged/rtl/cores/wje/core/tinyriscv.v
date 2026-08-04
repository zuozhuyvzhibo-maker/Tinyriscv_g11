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
module wje_tinyriscv(

    input wire clk,
    input wire rst,

    output wire sid_start_o,
    input wire sid_busy_i,
    output wire if_uart_start_o,
    output wire if_uart_accept_o,
    output wire[7:0] if_uart_data_o,
    input wire if_uart_busy_i,
    input wire if_uart_done_i,

    output wire temp_start_o,
    output wire temp_hold_o,
    output wire temp_accept_o,
    input wire temp_busy_i,
    input wire temp_done_i,
    input wire temp_ack_error_i,
    input wire[15:0] temp_raw_i,

    output wire[`WJE_MemAddrBus] rib_ex_addr_o,
    input wire[`WJE_MemBus] rib_ex_data_i,
    output wire[`WJE_MemBus] rib_ex_data_o,
    output wire rib_ex_req_o,
    output wire rib_ex_we_o,
    output wire[3:0] rib_ex_byte_en_o,

    output wire[`WJE_MemAddrBus] rib_pc_addr_o,
    input wire[`WJE_MemBus] rib_pc_data_i,

    input wire rib_hold_flag_i,
    input wire rib_mem_busy_i                  ,

    output wire[4:0] rf_raddr1_o,
    output wire[4:0] rf_raddr2_o,
    input wire[31:0] rf_rdata1_i,
    input wire[31:0] rf_rdata2_i,
    output wire rf_we_o,
    output wire[4:0] rf_waddr_o,
    output wire[31:0] rf_wdata_o

    );


	wire[`WJE_InstAddrBus] pc_pc_o;


	wire[`WJE_InstBus] if_inst_o;
	wire[`WJE_InstAddrBus] if_inst_addr_o;


	wire[`WJE_RegAddrBus] id_reg1_raddr_o;
	wire[`WJE_RegAddrBus] id_reg2_raddr_o;
	wire[`WJE_InstBus] id_inst_o;
	wire[`WJE_InstAddrBus] id_inst_addr_o;
	wire[`WJE_RegBus] id_reg1_rdata_o;
	wire[`WJE_RegBus] id_reg2_rdata_o;
	wire id_reg_we_o;
	wire[`WJE_RegAddrBus] id_reg_waddr_o;
	wire[`WJE_MemAddrBus] id_op1_o;
	wire[`WJE_MemAddrBus] id_op2_o;
	wire[`WJE_MemAddrBus] id_op1_jump_o;
	wire[`WJE_MemAddrBus] id_op2_jump_o;


	wire[`WJE_InstBus] ie_inst_o;
	wire[`WJE_InstAddrBus] ie_inst_addr_o;
	wire ie_reg_we_o;
	wire[`WJE_RegAddrBus] ie_reg_waddr_o;
	wire[`WJE_RegBus] ie_reg1_rdata_o;
	wire[`WJE_RegBus] ie_reg2_rdata_o;
	wire[`WJE_MemAddrBus] ie_op1_o;
	wire[`WJE_MemAddrBus] ie_op2_o;
	wire[`WJE_MemAddrBus] ie_op1_jump_o;
	wire[`WJE_MemAddrBus] ie_op2_jump_o;


	wire[`WJE_MemBus] ex_mem_wdata_o;
	wire[`WJE_MemAddrBus] ex_mem_raddr_o;
	wire[`WJE_MemAddrBus] ex_mem_waddr_o;
	wire ex_mem_we_o;
	wire ex_mem_req_o;
    wire[3:0] ex_mem_byte_en_o;
	wire[`WJE_RegBus] ex_reg_wdata_o;
	wire ex_reg_we_o;
	wire[`WJE_RegAddrBus] ex_reg_waddr_o;
	wire ex_hold_flag_o;
	wire ex_jump_flag_o;
	wire[`WJE_InstAddrBus] ex_jump_addr_o;
	wire ex_temp_start_o;
	wire ex_temp_hold_o;
	wire ex_temp_accept_o;
	wire ex_if_uart_start_o;
    wire ex_if_uart_accept_o;
	wire[7:0] ex_if_uart_data_o;
	wire ex_if_uart_hold_o;


	wire[`WJE_RegBus] regs_rdata1_o;
	wire[`WJE_RegBus] regs_rdata2_o;


	wire[`WJE_Hold_Flag_Bus] ctrl_hold_flag_o;
	wire ctrl_jump_flag_o;
	wire[`WJE_InstAddrBus] ctrl_jump_addr_o;


    assign rib_ex_addr_o = (ex_mem_we_o == `WJE_WriteEnable)? ex_mem_waddr_o: ex_mem_raddr_o;
    assign rib_ex_data_o = ex_mem_wdata_o;
    assign rib_ex_req_o = ex_mem_req_o;
    assign rib_ex_we_o = ex_mem_we_o;
    assign rib_ex_byte_en_o = ex_mem_byte_en_o;

    assign rib_pc_addr_o = pc_pc_o;
    assign temp_start_o = ex_temp_start_o;
    assign temp_hold_o = ex_temp_hold_o;
    assign temp_accept_o = ex_temp_accept_o;
    assign if_uart_start_o = ex_if_uart_start_o;
    assign if_uart_accept_o = ex_if_uart_accept_o;
    assign if_uart_data_o = ex_if_uart_data_o;



    wje_pc_reg u_pc_reg(
        .clk(clk),
        .rst(rst),
        .pc_o(pc_pc_o),
        .hold_flag_i(ctrl_hold_flag_o),
        .jump_flag_i(ctrl_jump_flag_o),
        .jump_addr_i(ctrl_jump_addr_o)
    );


    wje_ctrl u_ctrl(
        .rst(rst),
        .jump_flag_i(ex_jump_flag_o),
        .jump_addr_i(ex_jump_addr_o),
        .hold_flag_ex_i(ex_hold_flag_o),
        .hold_flag_temp_i(ex_temp_hold_o | ex_if_uart_hold_o),
        .hold_flag_rib_i(rib_hold_flag_i),
        .hold_flag_mem_i(rib_mem_busy_i),
        .hold_flag_o(ctrl_hold_flag_o),
        .jump_flag_o(ctrl_jump_flag_o),
        .jump_addr_o(ctrl_jump_addr_o)
    );

    assign rf_raddr1_o = id_reg1_raddr_o;
    assign rf_raddr2_o = id_reg2_raddr_o;
    assign rf_we_o = ex_reg_we_o;
    assign rf_waddr_o = ex_reg_waddr_o;
    assign rf_wdata_o = ex_reg_wdata_o;
    assign regs_rdata1_o = rf_rdata1_i;
    assign regs_rdata2_o = rf_rdata2_i;

    wje_if_id u_if_id(
        .clk(clk),
        .rst(rst),
        .inst_i(rib_pc_data_i),
        .inst_addr_i(pc_pc_o),
        .hold_flag_i(ctrl_hold_flag_o),
        .inst_o(if_inst_o),
        .inst_addr_o(if_inst_addr_o)
    );


    wje_id u_id(
        .rst(rst),
        .inst_i(if_inst_o),
        .inst_addr_i(if_inst_addr_o),
        .reg1_rdata_i(regs_rdata1_o),
        .reg2_rdata_i(regs_rdata2_o),
        .ex_jump_flag_i(ex_jump_flag_o),
        .reg1_raddr_o(id_reg1_raddr_o),
        .reg2_raddr_o(id_reg2_raddr_o),
        .inst_o(id_inst_o),
        .inst_addr_o(id_inst_addr_o),
        .reg1_rdata_o(id_reg1_rdata_o),
        .reg2_rdata_o(id_reg2_rdata_o),
        .reg_we_o(id_reg_we_o),
        .reg_waddr_o(id_reg_waddr_o),
        .op1_o(id_op1_o),
        .op2_o(id_op2_o),
        .op1_jump_o(id_op1_jump_o),
        .op2_jump_o(id_op2_jump_o)
    );


    wje_id_ex u_id_ex(
        .clk(clk),
        .rst(rst),
        .inst_i(id_inst_o),
        .inst_addr_i(id_inst_addr_o),
        .reg_we_i(id_reg_we_o),
        .reg_waddr_i(id_reg_waddr_o),
        .reg1_rdata_i(id_reg1_rdata_o),
        .reg2_rdata_i(id_reg2_rdata_o),
        .hold_flag_i(ctrl_hold_flag_o),
        .inst_o(ie_inst_o),
        .inst_addr_o(ie_inst_addr_o),
        .reg_we_o(ie_reg_we_o),
        .reg_waddr_o(ie_reg_waddr_o),
        .reg1_rdata_o(ie_reg1_rdata_o),
        .reg2_rdata_o(ie_reg2_rdata_o),
        .op1_i(id_op1_o),
        .op2_i(id_op2_o),
        .op1_jump_i(id_op1_jump_o),
        .op2_jump_i(id_op2_jump_o),
        .op1_o(ie_op1_o),
        .op2_o(ie_op2_o),
        .op1_jump_o(ie_op1_jump_o),
        .op2_jump_o(ie_op2_jump_o)
    );


    wje_ex u_ex(
        .rst(rst),
        .inst_i(ie_inst_o),
        .inst_addr_i(ie_inst_addr_o),
        .reg_we_i(ie_reg_we_o),
        .reg_waddr_i(ie_reg_waddr_o),
        .reg1_rdata_i(ie_reg1_rdata_o),
        .reg2_rdata_i(ie_reg2_rdata_o),
        .op1_i(ie_op1_o),
        .op2_i(ie_op2_o),
        .op1_jump_i(ie_op1_jump_o),
        .op2_jump_i(ie_op2_jump_o),
        .mem_rdata_i(rib_ex_data_i),
        .mem_wdata_o(ex_mem_wdata_o),
        .mem_raddr_o(ex_mem_raddr_o),
        .mem_waddr_o(ex_mem_waddr_o),
        .mem_we_o(ex_mem_we_o),
        .mem_req_o(ex_mem_req_o),
        .mem_byte_en_o(ex_mem_byte_en_o),
        .sid_busy_i(sid_busy_i),
        .if_uart_busy_i(if_uart_busy_i),
        .if_uart_done_i(if_uart_done_i),
        .temp_busy_i(temp_busy_i),
        .temp_done_i(temp_done_i),
        .temp_ack_error_i(temp_ack_error_i),
        .temp_raw_i(temp_raw_i),
        .mem_busy_i(rib_mem_busy_i),
        .reg_wdata_o(ex_reg_wdata_o),
        .reg_we_o(ex_reg_we_o),
        .reg_waddr_o(ex_reg_waddr_o),
        .hold_flag_o(ex_hold_flag_o),
        .jump_flag_o(ex_jump_flag_o),
        .jump_addr_o(ex_jump_addr_o),
        .sid_start_o(sid_start_o),
        .if_uart_start_o(ex_if_uart_start_o),
        .if_uart_accept_o(ex_if_uart_accept_o),
        .if_uart_data_o(ex_if_uart_data_o),
        .if_uart_hold_o(ex_if_uart_hold_o),
        .temp_start_o(ex_temp_start_o),
        .temp_hold_o(ex_temp_hold_o),
        .temp_accept_o(ex_temp_accept_o)
    );

endmodule
