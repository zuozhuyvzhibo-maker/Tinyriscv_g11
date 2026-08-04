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
module ldk_tinyriscv(

    input wire clk,
    input wire rst,

    output wire[`LDK_MemAddrBus] rib_ex_addr_o,
    input wire[`LDK_MemBus] rib_ex_data_i,
    output wire[`LDK_MemBus] rib_ex_data_o,
    output wire rib_ex_req_o,
    output wire rib_ex_we_o,
    input wire rib_ex_ack_i,

    output wire rib_pc_req_o,
    input wire rib_pc_ack_i,
    output wire[`LDK_MemAddrBus] rib_pc_addr_o,
    input wire[`LDK_MemBus] rib_pc_data_i         ,

    output wire[4:0] rf_raddr1_o,
    output wire[4:0] rf_raddr2_o,
    input wire[31:0] rf_rdata1_i,
    input wire[31:0] rf_rdata2_i,
    output wire rf_we_o,
    output wire[4:0] rf_waddr_o,
    output wire[31:0] rf_wdata_o

    );


	wire[`LDK_InstAddrBus] pc_pc_o;


	wire[`LDK_InstBus] if_inst_o;
    wire[`LDK_InstAddrBus] if_inst_addr_o;


    wire[`LDK_RegAddrBus] id_reg1_raddr_o;
    wire[`LDK_RegAddrBus] id_reg2_raddr_o;
    wire[`LDK_InstBus] id_inst_o;
    wire[`LDK_InstAddrBus] id_inst_addr_o;
    wire[`LDK_RegBus] id_reg1_rdata_o;
    wire[`LDK_RegBus] id_reg2_rdata_o;
    wire id_reg_we_o;
    wire[`LDK_RegAddrBus] id_reg_waddr_o;
    wire[`LDK_MemAddrBus] id_op1_o;
    wire[`LDK_MemAddrBus] id_op2_o;
    wire[`LDK_MemAddrBus] id_op1_jump_o;
    wire[`LDK_MemAddrBus] id_op2_jump_o;


    wire[`LDK_InstBus] ie_inst_o;
    wire[`LDK_InstAddrBus] ie_inst_addr_o;
    wire ie_reg_we_o;
    wire[`LDK_RegAddrBus] ie_reg_waddr_o;
    wire[`LDK_RegBus] ie_reg1_rdata_o;
    wire[`LDK_RegBus] ie_reg2_rdata_o;
    wire[`LDK_MemAddrBus] ie_op1_o;
    wire[`LDK_MemAddrBus] ie_op2_o;
    wire[`LDK_MemAddrBus] ie_op1_jump_o;
    wire[`LDK_MemAddrBus] ie_op2_jump_o;


    wire[`LDK_MemBus] ex_mem_wdata_o;
    wire[`LDK_MemAddrBus] ex_mem_raddr_o;
    wire[`LDK_MemAddrBus] ex_mem_waddr_o;
    wire ex_mem_we_o;
    wire ex_mem_req_o;
    wire ex_mem_no_ack_o;
    wire[`LDK_RegBus] ex_reg_wdata_o;
    wire ex_reg_we_o;
    wire[`LDK_RegAddrBus] ex_reg_waddr_o;
    wire ex_hold_flag_o;
    wire ex_jump_flag_o;
    wire[`LDK_InstAddrBus] ex_jump_addr_o;
    wire [`LDK_MemBus] ex_mem_rdata_in;


    wire[`LDK_RegBus] regs_rdata1_o;
    wire[`LDK_RegBus] regs_rdata2_o;


    wire[`LDK_Hold_Flag_Bus] ctrl_hold_flag_o;
    wire ctrl_jump_flag_o;
    wire[`LDK_InstAddrBus] ctrl_jump_addr_o;
    wire reg_we_gate_o;
    wire mem_use_latched_o;
    wire [4:0] ctrl_state_o;
    wire ext_inst_done_o;
    wire ext_inst_start_o;
    wire ex_ife_use_uart_o;



    assign rib_ex_addr_o = (rib_ex_we_o == `LDK_WriteEnable)? ex_mem_waddr_o: ex_mem_raddr_o;
    assign rib_ex_data_o = ex_mem_wdata_o;

    assign rib_pc_addr_o = pc_pc_o;


    reg [31:0] mem_rdata_latched;
    always @(posedge clk) begin
        if (rst == `LDK_RstEnable) begin
            mem_rdata_latched <= 32'h0;
        end else if (ctrl_state_o == 4'b0101  && rib_ex_ack_i) begin
            mem_rdata_latched <= rib_ex_data_i;
        end
    end


    assign ex_mem_rdata_in = mem_use_latched_o ? mem_rdata_latched : rib_ex_data_i;


    wire final_reg_we;
    assign final_reg_we = ex_reg_we_o & reg_we_gate_o;


    ldk_pc_reg u_pc_reg(
        .clk(clk),
        .rst(rst),
        .pc_o(pc_pc_o),
        .hold_flag_i(ctrl_hold_flag_o),
        .jump_flag_i(ctrl_jump_flag_o),
        .jump_addr_i(ctrl_jump_addr_o)
    );

    ldk_ctrl_dk u_ctrl_dk(
    .clk             (clk),
    .rst             (rst),
    .inst_at_ex_i    (ie_inst_o),
    .jump_flag_i     (ex_jump_flag_o),
    .jump_addr_i     (ex_jump_addr_o),
    .ext_mem_req_i   (ex_mem_req_o),
    .ext_mem_we_i    (ex_mem_we_o),
    .mem_no_ack_i    (ex_mem_no_ack_o),
    .hold_flag_ex_i  (ex_hold_flag_o),
    .ife_use_uart    (ex_ife_use_uart_o),
    .ext_inst_done   (ext_inst_done_o),
    // ctrl_dk keeps this legacy input for compatibility but does not use it.
    .hold_flag_rib_i (1'b0),
    .if_ack_i        (rib_pc_ack_i),
    .mem_ack_i       (rib_ex_ack_i),
    .hold_flag_o     (ctrl_hold_flag_o),
    .jump_flag_o     (ctrl_jump_flag_o),
    .jump_addr_o     (ctrl_jump_addr_o),
    .if_req_o        (rib_pc_req_o),
    .mem_req_o       (rib_ex_req_o),
    .mem_we_o        (rib_ex_we_o),
    .reg_we_gate_o   (reg_we_gate_o),  // need to check
    .ext_inst_start_o(ext_inst_start_o),
    .mem_rdata_use_latched_o(mem_use_latched_o), // need to fix
    .state_o         (ctrl_state_o)  // open

);

    assign rf_raddr1_o = id_reg1_raddr_o;
    assign rf_raddr2_o = id_reg2_raddr_o;
    assign rf_we_o = final_reg_we;
    assign rf_waddr_o = ex_reg_waddr_o;
    assign rf_wdata_o = ex_reg_wdata_o;
    assign regs_rdata1_o = rf_rdata1_i;
    assign regs_rdata2_o = rf_rdata2_i;

    ldk_if_id u_if_id(
        .clk(clk),
        .rst(rst),
        .inst_i(rib_pc_data_i),
        .inst_addr_i(pc_pc_o),
        .hold_flag_i(ctrl_hold_flag_o),
        .inst_o(if_inst_o),
        .inst_addr_o(if_inst_addr_o)
    );


    ldk_id u_id(
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


    ldk_id_ex u_id_ex(
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


    ldk_ex u_ex(
        .clk(clk),
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
        .mem_rdata_i(ex_mem_rdata_in),
        .ext_inst_start_i(ext_inst_start_o),
        .mem_wdata_o(ex_mem_wdata_o),
        .mem_raddr_o(ex_mem_raddr_o),
        .mem_ack_i(rib_ex_ack_i),
        .mem_waddr_o(ex_mem_waddr_o),
        .mem_we_o(ex_mem_we_o),
        .mem_req_o(ex_mem_req_o),
        .mem_no_ack_o(ex_mem_no_ack_o),
        .reg_wdata_o(ex_reg_wdata_o),
        .reg_we_o(ex_reg_we_o),
        .reg_waddr_o(ex_reg_waddr_o),
        .hold_flag_o(ex_hold_flag_o),
        .jump_flag_o(ex_jump_flag_o),
        .jump_addr_o(ex_jump_addr_o),
        .ext_inst_done_o(ext_inst_done_o),
        .ife_use_uart_o(ex_ife_use_uart_o)

    );

endmodule
