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

`include "../core/defines.v"

// ldk_tinyriscv澶勭悊鍣ㄦ牳椤跺眰妯″潡
module ldk_tinyriscv(

    input wire clk,
    input wire rst,

    output wire[`MemAddrBus] rib_ex_addr_o,    // 璇汇€佸啓澶栬鐨勫湴鍧€
    input wire[`MemBus] rib_ex_data_i,         // 浠庡璁捐鍙栫殑鏁版嵁
    output wire[`MemBus] rib_ex_data_o,        // 鍐欏叆澶栬鐨勬暟鎹?
    output wire rib_ex_req_o,                  // 璁块棶澶栬璇锋眰
    output wire rib_ex_we_o,                   // 鍐欏璁炬爣蹇?
    input wire rib_ex_ack_i,                   // 璁块棶澶栬鍝嶅簲

    output wire rib_pc_req_o,                  // 鍙栨寚璇锋眰
    input wire rib_pc_ack_i,                   // 鍙栨寚鍝嶅簲
    output wire[`MemAddrBus] rib_pc_addr_o,    // 鍙栨寚鍦板潃
    input wire[`MemBus] rib_pc_data_i         // 鍙栧埌鐨勬寚浠ゅ唴瀹?

    );

    // ldk_pc_reg妯″潡杈撳嚭淇″彿
	wire[`InstAddrBus] pc_pc_o;

    // ldk_if_id妯″潡杈撳嚭淇″彿
	wire[`InstBus] if_inst_o;
    wire[`InstAddrBus] if_inst_addr_o;

    // ldk_id妯″潡杈撳嚭淇″彿
    wire[`RegAddrBus] id_reg1_raddr_o;
    wire[`RegAddrBus] id_reg2_raddr_o;
    wire[`InstBus] id_inst_o;
    wire[`InstAddrBus] id_inst_addr_o;
    wire[`RegBus] id_reg1_rdata_o;
    wire[`RegBus] id_reg2_rdata_o;
    wire id_reg_we_o;
    wire[`RegAddrBus] id_reg_waddr_o;
    wire[`MemAddrBus] id_op1_o;
    wire[`MemAddrBus] id_op2_o;
    wire[`MemAddrBus] id_op1_jump_o;
    wire[`MemAddrBus] id_op2_jump_o;

    // ldk_id_ex妯″潡杈撳嚭淇″彿
    wire[`InstBus] ie_inst_o;
    wire[`InstAddrBus] ie_inst_addr_o;
    wire ie_reg_we_o;
    wire[`RegAddrBus] ie_reg_waddr_o;
    wire[`RegBus] ie_reg1_rdata_o;
    wire[`RegBus] ie_reg2_rdata_o;
    wire[`MemAddrBus] ie_op1_o;
    wire[`MemAddrBus] ie_op2_o;
    wire[`MemAddrBus] ie_op1_jump_o;
    wire[`MemAddrBus] ie_op2_jump_o;

    // ldk_ex妯″潡杈撳嚭淇″彿
    wire[`MemBus] ex_mem_wdata_o;
    wire[`MemAddrBus] ex_mem_raddr_o;
    wire[`MemAddrBus] ex_mem_waddr_o;
    wire ex_mem_we_o;
    wire ex_mem_req_o;
    wire ex_mem_no_ack_o;
    wire[`RegBus] ex_reg_wdata_o;
    wire ex_reg_we_o;
    wire[`RegAddrBus] ex_reg_waddr_o;
    wire ex_hold_flag_o;
    wire ex_jump_flag_o;
    wire[`InstAddrBus] ex_jump_addr_o;
    wire [`MemBus] ex_mem_rdata_in;

    // ldk_regs妯″潡杈撳嚭淇″彿
    wire[`RegBus] regs_rdata1_o;
    wire[`RegBus] regs_rdata2_o;

    // ctrl妯″潡杈撳嚭淇″彿
    wire[`Hold_Flag_Bus] ctrl_hold_flag_o;
    wire ctrl_jump_flag_o;
    wire[`InstAddrBus] ctrl_jump_addr_o;
    wire reg_we_gate_o;
    wire mem_use_latched_o;
    wire [4:0] ctrl_state_o;
    wire ext_inst_done_o;
    wire ext_inst_start_o;
    wire ex_ife_use_uart_o;



    assign rib_ex_addr_o = (rib_ex_we_o == `WriteEnable)? ex_mem_waddr_o: ex_mem_raddr_o;
    assign rib_ex_data_o = ex_mem_wdata_o;
    // assign rib_ex_req_o = ex_mem_req_o;
    // assign rib_ex_we_o = ex_mem_we_o;

    assign rib_pc_addr_o = pc_pc_o;

    // 閿佸瓨璇婚樁娈佃繑鍥炵殑 mem_rdata锛屼緵鍐欓樁娈典娇鐢?
    reg [31:0] mem_rdata_latched;
    always @(posedge clk) begin
        if (rst == `RstEnable) begin
            mem_rdata_latched <= 32'h0;
        end else if (ctrl_state_o == 4'b0101  && rib_ex_ack_i) begin
            mem_rdata_latched <= rib_ex_data_i;
        end
    end

    // 鍠傜粰 ldk_ex.v 鐨?mem_rdata锛氭梺璺€夋嫨
    assign ex_mem_rdata_in = mem_use_latched_o ? mem_rdata_latched : rib_ex_data_i;

    // reg_we 闂ㄦ帶
    wire final_reg_we;
    assign final_reg_we = ex_reg_we_o & reg_we_gate_o;

    // ldk_pc_reg妯″潡渚嬪寲
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
    .inst_at_ex_i    (ie_inst_o),       // ID/EX 鐨?inst_o
    .jump_flag_i     (ex_jump_flag_o),
    .jump_addr_i     (ex_jump_addr_o),
    .ext_mem_req_i   (ex_mem_req_o),
    .ext_mem_we_i    (ex_mem_we_o),
    .mem_no_ack_i    (ex_mem_no_ack_o),
    .hold_flag_ex_i  (ex_hold_flag_o),
    .ife_use_uart    (ex_ife_use_uart_o),
    .ext_inst_done   (ext_inst_done_o),
    .hold_flag_rib_i (rib_hold_flag_i),
    .if_ack_i        (rib_pc_ack_i),       // 鏉ヨ嚜妗ユ帴
    .mem_ack_i       (rib_ex_ack_i),       // 鏉ヨ嚜妗ユ帴 
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


    // ldk_regs妯″潡渚嬪寲
    ldk_regs u_regs(
        .clk(clk),
        .rst(rst),
        .we_i(final_reg_we),
        .waddr_i(ex_reg_waddr_o),
        .wdata_i(ex_reg_wdata_o),
        .raddr1_i(id_reg1_raddr_o),
        .rdata1_o(regs_rdata1_o),
        .raddr2_i(id_reg2_raddr_o),
        .rdata2_o(regs_rdata2_o)
    );

    // ldk_if_id妯″潡渚嬪寲
    ldk_if_id u_if_id(
        .clk(clk),
        .rst(rst),
        .inst_i(rib_pc_data_i),
        .inst_addr_i(pc_pc_o),
        .hold_flag_i(ctrl_hold_flag_o),
        .inst_o(if_inst_o),
        .inst_addr_o(if_inst_addr_o)
    );

    // ldk_id妯″潡渚嬪寲
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

    // ldk_id_ex妯″潡渚嬪寲
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

    // ldk_ex妯″潡渚嬪寲
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
