 /*
 Copyright 2026

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

// Chip-side bridge. It converts RIB ROM/RAM accesses into a fixed
// byte-wide synchronous protocol to the external FPGA bridge.
module bridge(

    input wire clk,
    input wire rst,

    // RIB slave0/ROM side
    input wire rom_req_i,
    input wire rom_we_i,
    input wire[`MemAddrBus] rom_addr_i,
    input wire[`MemBus] rom_data_i,
    output reg[`MemBus] rom_data_o,
    output reg rom_resp_valid_o,
    output reg[`MemAddrBus] rom_resp_addr_o,

    // RIB slave1/RAM side
    input wire ram_req_i,
    input wire ram_we_i,
    input wire[`MemAddrBus] ram_addr_i,
    input wire[`MemBus] ram_data_i,
    output reg[`MemBus] ram_data_o,

    // Chip-to-FPGA fixed 8-bit synchronous protocol
    // 后续 8-bit 物理线复用为 payload[5:0] + req_toggle + ack_toggle
    input wire[7:0] fpga_data_i,
    output reg[7:0] fpga_data_o,

    output wire busy_o

    );

    localparam[7:0] CMD_ROM_RD  = 8'h11;
    localparam[7:0] CMD_ROM_WR  = 8'h12;
    localparam[7:0] CMD_RAM_RD  = 8'h21;
    localparam[7:0] CMD_RAM_WR  = 8'h22;
    localparam[7:0] RESP_READ   = 8'h81; 
    localparam[7:0] RESP_WRITE  = 8'h82; 

    localparam TARGET_ROM = 1'b0;
    localparam TARGET_RAM = 1'b1;

    localparam[3:0] S_IDLE      = 4'd0;
    localparam[3:0] S_TX_CMD    = 4'd1;
    localparam[3:0] S_TX_ADDR3  = 4'd2;
    localparam[3:0] S_TX_ADDR2  = 4'd3;
    localparam[3:0] S_TX_ADDR1  = 4'd4;
    localparam[3:0] S_TX_ADDR0  = 4'd5;
    localparam[3:0] S_TX_DATA3  = 4'd6;
    localparam[3:0] S_TX_DATA2  = 4'd7;
    localparam[3:0] S_TX_DATA1  = 4'd8;
    localparam[3:0] S_TX_DATA0  = 4'd9;
    localparam[3:0] S_WAIT_RESP = 4'd10;
    localparam[3:0] S_RX_DATA3  = 4'd11;
    localparam[3:0] S_RX_DATA2  = 4'd12;
    localparam[3:0] S_RX_DATA1  = 4'd13;
    localparam[3:0] S_RX_DATA0  = 4'd14;
    localparam[3:0] S_DONE      = 4'd15;

    reg[3:0] state;
    reg target;
    reg req_we;
    reg[`MemAddrBus] addr;
    reg[`MemBus] wdata;
    reg[`MemBus] rdata;

    wire start_req = rom_req_i | ram_req_i;

    assign busy_o = ((state != S_IDLE) && (state != S_DONE)) ||
                    ((state == S_IDLE) && start_req);

    localparam[3:0] REQ_READ_CHUNKS  = 4'd7; // 读请求帧为 CMD+ADDR 共 40bit，补 2bit 后分成 7 个 6bit 分片
    localparam[3:0] REQ_WRITE_CHUNKS = 4'd12; // 写请求帧为 CMD+ADDR+WDATA 共 72bit，分成 12 个 6bit 分片
    localparam[3:0] RESP_HEAD_CHUNKS = 4'd2; // 响应命令字 8bit，至少需要 2 个 6bit 分片才能解析
    localparam[3:0] RESP_READ_CHUNKS = 4'd7; // 读响应帧为 RESP+RDATA 共 40bit，补 2bit 后分成 7 个 6bit 分片
    
    wire[5:0] fpga_payload_i = fpga_data_i[5:0]; // FPGA 返回方向的 6bit payload
    wire fpga_req_toggle_i = fpga_data_i[6]; // FPGA 返回方向的 req toggle
    wire fpga_ack_toggle_i = fpga_data_i[7]; // FPGA 对芯片发送方向的 ack toggle

    reg[71:0] tx_frame; // 芯片发送帧缓存，最大容纳写请求 72bit
    reg[3:0] tx_chunks_total; // 当前发送帧需要发送的 6bit 分片数量
    reg[3:0] tx_chunk_index; // 当前正在发送的 6bit 分片序号
    reg[5:0] tx_payload; // 芯片输出到 FPGA 的 6bit payload
    reg tx_req_toggle; // 芯片发送方向 req toggle
    reg tx_wait_ack; // 芯片发送方向正在等待 FPGA ack

    reg fpga_ack_meta; // FPGA ack toggle 第一级同步寄存器
    reg fpga_ack_sync; // FPGA ack toggle 第二级同步寄存器
    reg fpga_req_meta; // FPGA req toggle 第一级同步寄存器
    reg fpga_req_sync; // FPGA req toggle 第二级同步寄存器
    reg fpga_req_sync_d; // FPGA req toggle 延迟一拍，用于检测 toggle 变化
    reg rx_ack_toggle; // 芯片接收 FPGA 分片后的 ack toggle
    reg rx_ack_pending; // 新增：延迟一拍返回接收 ack，避免对方过早发送下一分片
    reg[3:0] rx_chunk_index; // 当前正在接收的 6bit 分片序号
    reg[5:0] rx_chunk0; // 接收帧第 0 个 6bit 分片
    reg[5:0] rx_chunk1; // 接收帧第 1 个 6bit 分片
    reg[5:0] rx_chunk2; // 接收帧第 2 个 6bit 分片
    reg[5:0] rx_chunk3; // 接收帧第 3 个 6bit 分片
    reg[5:0] rx_chunk4; // 接收帧第 4 个 6bit 分片
    reg[5:0] rx_chunk5; // 接收帧第 5 个 6bit 分片
    reg[5:0] rx_chunk6; // 接收帧第 6 个 6bit 分片

    wire rx_chunk_valid = (fpga_req_sync != fpga_req_sync_d); // 检测到 FPGA req toggle 翻转时表示收到一个新分片
    wire tx_ack_done = (tx_wait_ack == 1'b1) && (fpga_ack_sync == tx_req_toggle); // FPGA ack toggle 追上本次 req toggle 时表示当前分片发送完成
    wire[7:0] rx_resp_byte = {rx_chunk0, fpga_payload_i[5:4]}; // 前两个响应分片拼出 8bit RESP
    wire[31:0] rx_read_data = {rx_chunk1[3:0], rx_chunk2, rx_chunk3, rx_chunk4, rx_chunk5, fpga_payload_i[5:2]}; // 读响应后 32bit 数据由第 1~6 个分片拼接得到

    function [5:0] get_tx_chunk; // 按分片序号从 72bit 发送帧中取出 6bit payload
        input[71:0] frame; // 待发送帧
        input[3:0] chunk_index; // 待取出的分片序号
        begin // 函数主体开始
            case (chunk_index) // 根据分片序号选择固定 6bit 区间
                4'd0: get_tx_chunk = frame[71:66]; // 第 0 个分片
                4'd1: get_tx_chunk = frame[65:60]; // 第 1 个分片
                4'd2: get_tx_chunk = frame[59:54]; // 第 2 个分片
                4'd3: get_tx_chunk = frame[53:48]; // 第 3 个分片
                4'd4: get_tx_chunk = frame[47:42]; // 第 4 个分片
                4'd5: get_tx_chunk = frame[41:36]; // 第 5 个分片
                4'd6: get_tx_chunk = frame[35:30]; // 第 6 个分片
                4'd7: get_tx_chunk = frame[29:24]; // 第 7 个分片
                4'd8: get_tx_chunk = frame[23:18]; // 第 8 个分片
                4'd9: get_tx_chunk = frame[17:12]; // 第 9 个分片
                4'd10: get_tx_chunk = frame[11:6]; // 第 10 个分片
                4'd11: get_tx_chunk = frame[5:0]; // 第 11 个分片
                default: get_tx_chunk = 6'h00; // 异常分片序号默认返回 0
            endcase // 分片选择结束
        end // 函数主体结束
    endfunction // get_tx_chunk 函数结束

//    always @ (posedge clk) begin
//        if (rst == `RstEnable) begin
//            state <= S_IDLE;
//            target <= TARGET_ROM;
//            req_we <= `WriteDisable;
//            addr <= `ZeroWord;
//            wdata <= `ZeroWord;
//            rdata <= `ZeroWord;
//            rom_data_o <= `ZeroWord;
//            ram_data_o <= `ZeroWord;
//            fpga_data_o <= 8'h00;
//        end else begin
//            fpga_data_o <= 8'h00;
//
//            case (state)
//                S_IDLE: begin
//                    rdata <= `ZeroWord;
//                    if (ram_req_i == `RIB_REQ) begin
//                        target <= TARGET_RAM;
//                        req_we <= ram_we_i;
//                        addr <= ram_addr_i;
//                        wdata <= ram_data_i;
//                        state <= S_TX_CMD;
//                    end else if (rom_req_i == `RIB_REQ) begin
//                        target <= TARGET_ROM;
//                        req_we <= rom_we_i;
//                        addr <= rom_addr_i;
//                        wdata <= rom_data_i;
//                        state <= S_TX_CMD;
//                    end
//                end
//
//                S_TX_CMD: begin
//                    if (target == TARGET_RAM) begin
//                        fpga_data_o <= (req_we == `WriteEnable)? CMD_RAM_WR: CMD_RAM_RD;
//                    end else begin
//                        fpga_data_o <= (req_we == `WriteEnable)? CMD_ROM_WR: CMD_ROM_RD;
//                    end
//                    state <= S_TX_ADDR3;
//                end
//
//                S_TX_ADDR3: begin
//                    fpga_data_o <= addr[31:24];
//                    state <= S_TX_ADDR2;
//                end
//
//                S_TX_ADDR2: begin
//                    fpga_data_o <= addr[23:16];
//                    state <= S_TX_ADDR1;
//                end
//
//                S_TX_ADDR1: begin
//                    fpga_data_o <= addr[15:8];
//                    state <= S_TX_ADDR0;
//                end
//
//                S_TX_ADDR0: begin
//                    fpga_data_o <= addr[7:0];
//                    state <= (req_we == `WriteEnable)? S_TX_DATA3: S_WAIT_RESP;
//                end
//
//                S_TX_DATA3: begin
//                    fpga_data_o <= wdata[31:24];
//                    state <= S_TX_DATA2;
//                end
//
//                S_TX_DATA2: begin
//                    fpga_data_o <= wdata[23:16];
//                    state <= S_TX_DATA1;
//                end
//
//                S_TX_DATA1: begin
//                    fpga_data_o <= wdata[15:8];
//                    state <= S_TX_DATA0;
//                end
//
//                S_TX_DATA0: begin
//                    fpga_data_o <= wdata[7:0];
//                    state <= S_WAIT_RESP;
//                end
//
//                S_WAIT_RESP: begin
//                    if (fpga_data_i == RESP_READ) begin
//                        state <= S_RX_DATA3;
//                    end else if (fpga_data_i == RESP_WRITE) begin
//                        state <= S_DONE;
//                    end
//                end
//
//                S_RX_DATA3: begin
//                    rdata[31:24] <= fpga_data_i;
//                    state <= S_RX_DATA2;
//                end
//
//                S_RX_DATA2: begin
//                    rdata[23:16] <= fpga_data_i;
//                    state <= S_RX_DATA1;
//                end
//
//                S_RX_DATA1: begin
//                    rdata[15:8] <= fpga_data_i;
//                    state <= S_RX_DATA0;
//                end
//
//                S_RX_DATA0: begin
//                    rdata[7:0] <= fpga_data_i;
//                    if (target == TARGET_RAM) begin
//                        ram_data_o <= {rdata[31:8], fpga_data_i};
//                    end else begin
//                        rom_data_o <= {rdata[31:8], fpga_data_i};
//                    end
//                    state <= S_DONE;
//                end
//
//                S_DONE: begin
//                    state <= S_IDLE;
//                end
//
//                default: begin
//                    state <= S_IDLE;
//                end
//            endcase
//        end
//    end

    always @ (posedge clk) begin // 6bit payload + req/ack toggle 协议状态机
        if (rst == `RstEnable) begin // 低有效复位
            state <= S_IDLE; // 复位后回到空闲状态
            target <= TARGET_ROM; // 复位后默认目标为 ROM
            req_we <= `WriteDisable; // 复位后默认读方向
            addr <= `ZeroWord; // 清空地址缓存
            wdata <= `ZeroWord; // 清空写数据缓存
            rdata <= `ZeroWord; // 清空读数据缓存
            rom_data_o <= `ZeroWord; // 清空 ROM 读数据输出
            rom_resp_valid_o <= 1'b0; // 清空 ROM 读响应有效脉冲
            rom_resp_addr_o <= `ZeroWord; // 清空 ROM 读响应地址标记
            ram_data_o <= `ZeroWord; // 清空 RAM 读数据输出
            fpga_data_o <= 8'h00; // 清空 8bit 物理输出线
            tx_frame <= 72'h0; // 清空发送帧
            tx_chunks_total <= 4'h0; // 清空发送分片总数
            tx_chunk_index <= 4'h0; // 清空发送分片序号
            tx_payload <= 6'h00; // 清空发送 payload
            tx_req_toggle <= 1'b0; // 清空芯片发送 req toggle
            tx_wait_ack <= 1'b0; // 清空等待 ack 标志
            fpga_ack_meta <= 1'b0; // 清空 ack 一级同步寄存器
            fpga_ack_sync <= 1'b0; // 清空 ack 二级同步寄存器
            fpga_req_meta <= 1'b0; // 清空 req 一级同步寄存器
            fpga_req_sync <= 1'b0; // 清空 req 二级同步寄存器
            fpga_req_sync_d <= 1'b0; // 清空 req 延迟寄存器
            rx_ack_toggle <= 1'b0; // 清空芯片接收 ack toggle
            rx_ack_pending <= 1'b0; // 新增：清空接收 ack 延迟标志
            rx_chunk_index <= 4'h0; // 清空接收分片序号
            rx_chunk0 <= 6'h00; // 清空接收分片 0
            rx_chunk1 <= 6'h00; // 清空接收分片 1
            rx_chunk2 <= 6'h00; // 清空接收分片 2
            rx_chunk3 <= 6'h00; // 清空接收分片 3
            rx_chunk4 <= 6'h00; // 清空接收分片 4
            rx_chunk5 <= 6'h00; // 清空接收分片 5
            rx_chunk6 <= 6'h00; // 清空接收分片 6
        end else begin // 正常工作分支
            fpga_ack_meta <= fpga_ack_toggle_i; // 同步 FPGA 对芯片发送方向的 ack toggle
            fpga_ack_sync <= fpga_ack_meta; // ack toggle 第二级同步
            fpga_req_meta <= fpga_req_toggle_i; // 同步 FPGA 返回方向的 req toggle
            fpga_req_sync <= fpga_req_meta; // req toggle 第二级同步
            fpga_req_sync_d <= fpga_req_sync; // 保存上一拍 req toggle 用于边沿检测
            fpga_data_o <= {rx_ack_toggle, tx_req_toggle, tx_payload}; // 8bit 输出线复用为 ack/req/payload
            rom_resp_valid_o <= 1'b0; // ROM 读响应标记只保持一个芯片时钟周期

            if (rx_ack_pending == 1'b1) begin // 新增：上一拍已收到新分片，本拍再返回 ack
                rx_ack_toggle <= fpga_req_sync; // 新增：ack toggle 跟随已稳定接收的 req toggle
                rx_ack_pending <= 1'b0; // 新增：清除接收 ack 延迟标志
            end else if (rx_chunk_valid == 1'b1) begin // 收到 FPGA 返回方向的新分片
                rx_ack_pending <= 1'b1; // 新增：延迟一拍再 ack，保证本地 toggle 历史已更新
            end // 接收 ack 更新结束

            case (state) // 6+2 协议主状态机
                S_IDLE: begin // 空闲状态等待 RIB 请求
                    rdata <= `ZeroWord; // 开始新事务前清空读数据缓存
                    tx_wait_ack <= 1'b0; // 空闲时不等待发送 ack
                    tx_chunk_index <= 4'h0; // 空闲时发送分片序号归零
                    rx_chunk_index <= 4'h0; // 空闲时接收分片序号归零
                    if (ram_req_i == `RIB_REQ) begin // RAM 请求优先
                        target <= TARGET_RAM; // 缓存当前目标为 RAM
                        req_we <= ram_we_i; // 缓存 RAM 访问读写方向
                        addr <= ram_addr_i; // 缓存 RAM 地址
                        wdata <= ram_data_i; // 缓存 RAM 写数据
                        if (ram_we_i == `WriteEnable) begin // RAM 写请求需要 CMD+ADDR+WDATA
                            tx_frame <= {CMD_RAM_WR, ram_addr_i, ram_data_i}; // 构造 RAM 写请求发送帧
                            tx_chunks_total <= REQ_WRITE_CHUNKS; // RAM 写请求发送 12 个分片
                        end else begin // RAM 读请求需要 CMD+ADDR
                            tx_frame <= {CMD_RAM_RD, ram_addr_i, 2'b00, 30'h0}; // 构造 RAM 读请求发送帧并补齐到 72bit
                            tx_chunks_total <= REQ_READ_CHUNKS; // RAM 读请求发送 7 个分片
                        end // RAM 请求帧构造结束
                        state <= S_TX_CMD; // 进入发送请求帧状态
                    end else if (rom_req_i == `RIB_REQ) begin // 没有 RAM 请求时处理 ROM 请求
                        target <= TARGET_ROM; // 缓存当前目标为 ROM
                        req_we <= rom_we_i; // 缓存 ROM 访问读写方向
                        addr <= rom_addr_i; // 缓存 ROM 地址
                        wdata <= rom_data_i; // 缓存 ROM 写数据
                        if (rom_we_i == `WriteEnable) begin // ROM 写请求需要 CMD+ADDR+WDATA
                            tx_frame <= {CMD_ROM_WR, rom_addr_i, rom_data_i}; // 构造 ROM 写请求发送帧
                            tx_chunks_total <= REQ_WRITE_CHUNKS; // ROM 写请求发送 12 个分片
                        end else begin // ROM 读请求需要 CMD+ADDR
                            tx_frame <= {CMD_ROM_RD, rom_addr_i, 2'b00, 30'h0}; // 构造 ROM 读请求发送帧并补齐到 72bit
                            tx_chunks_total <= REQ_READ_CHUNKS; // ROM 读请求发送 7 个分片
                        end // ROM 请求帧构造结束
                        state <= S_TX_CMD; // 进入发送请求帧状态
                    end // RIB 请求判断结束
                end // S_IDLE 结束

                S_TX_CMD: begin // 发送请求帧的所有 6bit 分片
                    if (tx_wait_ack == 1'b0) begin // 当前没有等待 ack 时启动一个新分片
                        tx_payload <= get_tx_chunk(tx_frame, tx_chunk_index); // 取出当前 6bit 分片
                        tx_req_toggle <= ~tx_req_toggle; // 翻转 req toggle 表示新分片有效
                        tx_wait_ack <= 1'b1; // 进入等待 FPGA ack 状态
                        if (tx_chunk_index == (tx_chunks_total - 1'b1)) begin // 新增：最后一个请求分片一发出就提前进入等待响应状态
                            rx_chunk_index <= 4'h0; // 新增：准备接收响应分片
                            state <= S_WAIT_RESP; // 新增：避免 FPGA 快速返回响应时芯片侧尚未进入接收状态
                        end // 新增：最后请求分片提前切换状态结束
                    end else if (tx_ack_done == 1'b1) begin // FPGA 已确认当前分片
                        tx_wait_ack <= 1'b0; // 清除等待 ack 标志
                        if (tx_chunk_index == (tx_chunks_total - 1'b1)) begin // 当前分片是本帧最后一个分片
                            tx_chunk_index <= 4'h0; // 发送分片序号归零
                            rx_chunk_index <= 4'h0; // 准备接收响应分片
                            state <= S_WAIT_RESP; // 请求发完后等待 FPGA 响应
                        end else begin // 当前帧还有后续分片
                            tx_chunk_index <= tx_chunk_index + 1'b1; // 发送分片序号加一
                        end // 发送分片完成判断结束
                    end // 发送握手处理结束
                end // S_TX_CMD 结束

                S_WAIT_RESP: begin // 等待并接收 RESP 的前两个 6bit 分片
                    if ((tx_wait_ack == 1'b1) && (tx_ack_done == 1'b1)) begin // 新增：如果最后一个请求分片的 ack 此时返回
                        tx_wait_ack <= 1'b0; // 新增：清除最后请求分片的等待 ack 标志
                        tx_chunk_index <= 4'h0; // 新增：发送分片序号归零
                    end // 新增：最后请求分片 ack 清理结束
                    if (rx_chunk_valid == 1'b1) begin // 收到一个响应分片
                        if (rx_chunk_index == 4'd0) begin // 收到响应分片 0
                            rx_chunk0 <= fpga_payload_i; // 保存响应分片 0
                            rx_chunk_index <= 4'd1; // 下一次等待响应分片 1
                        end else if (rx_chunk_index == 4'd1) begin // 收到响应分片 1 后可解析 RESP
                            rx_chunk1 <= fpga_payload_i; // 保存响应分片 1
                            if (rx_resp_byte == RESP_READ) begin // 收到读响应命令
                                rx_chunk_index <= RESP_HEAD_CHUNKS; // 后续从分片 2 继续接收读数据
                                state <= S_RX_DATA3; // 进入读响应剩余分片接收状态
                            end else if (rx_resp_byte == RESP_WRITE) begin // 收到写完成响应命令
                                rx_chunk_index <= 4'h0; // 写响应接收完成后分片序号归零
                                state <= S_DONE; // 写事务完成
                            end else begin // 收到未知响应命令
                                rx_chunk_index <= 4'h0; // 丢弃未知响应并重新等待响应头
                            end // RESP 解析结束
                        end else begin // 异常响应分片序号保护
                            rx_chunk_index <= 4'h0; // 异常时重新等待响应头
                        end // 响应头接收判断结束
                    end // 响应头分片有效判断结束
                end // S_WAIT_RESP 结束

                S_RX_DATA3: begin // 接收读响应剩余分片，沿用旧状态名
                    if (rx_chunk_valid == 1'b1) begin // 收到一个读数据分片
                        case (rx_chunk_index) // 根据分片序号保存读响应分片
                            4'd2: begin // 收到读响应分片 2
                                rx_chunk2 <= fpga_payload_i; // 保存读响应分片 2
                                rx_chunk_index <= 4'd3; // 下一次等待分片 3
                            end // 分片 2 处理结束
                            4'd3: begin // 收到读响应分片 3
                                rx_chunk3 <= fpga_payload_i; // 保存读响应分片 3
                                rx_chunk_index <= 4'd4; // 下一次等待分片 4
                            end // 分片 3 处理结束
                            4'd4: begin // 收到读响应分片 4
                                rx_chunk4 <= fpga_payload_i; // 保存读响应分片 4
                                rx_chunk_index <= 4'd5; // 下一次等待分片 5
                            end // 分片 4 处理结束
                            4'd5: begin // 收到读响应分片 5
                                rx_chunk5 <= fpga_payload_i; // 保存读响应分片 5
                                rx_chunk_index <= 4'd6; // 下一次等待分片 6
                            end // 分片 5 处理结束
                            4'd6: begin // 收到读响应最后一个分片 6
                                rx_chunk6 <= fpga_payload_i; // 保存读响应分片 6
                                rdata <= rx_read_data; // 拼接完整 32bit 读数据
                                if (target == TARGET_RAM) begin // 如果当前目标为 RAM
                                    ram_data_o <= rx_read_data; // 更新 RAM 读数据输出
                                end else begin // 如果当前目标为 ROM
                                    rom_data_o <= rx_read_data; // 更新 ROM 读数据输出
                                    rom_resp_valid_o <= 1'b1; // 标记本拍完成一个 ROM 读响应
                                    rom_resp_addr_o <= addr; // 回传该 ROM 响应对应的取指地址
                                end // 读数据输出选择结束
                                rx_chunk_index <= 4'h0; // 读响应接收完成后分片序号归零
                                state <= S_DONE; // 读事务完成
                            end // 分片 6 处理结束
                            default: begin // 异常分片序号保护
                                rx_chunk_index <= RESP_HEAD_CHUNKS; // 异常时回到读数据分片 2
                            end // 异常分支结束
                        endcase // 读响应分片保存结束
                    end // 读数据分片有效判断结束
                end // S_RX_DATA3 结束

                S_DONE: begin // 事务完成状态
                    state <= S_IDLE; // 下一拍回到空闲状态
                end // S_DONE 结束

                default: begin // 异常状态保护
                    state <= S_IDLE; // 未知状态回到空闲
                end // default 结束
            endcase // 6+2 协议状态机结束
        end // 正常工作分支结束
    end // 6+2 协议时序块结束

endmodule
