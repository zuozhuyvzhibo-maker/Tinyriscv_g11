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

// FPGA-side bridge. It receives byte-wide commands from the chip-side
// bridge and accesses external ROM/RAM located in the FPGA fabric.
module bridge_fpga(

    input wire clk,
    input wire rst,

    // FPGA and chip-side bridge fixed 8-bit synchronous protocol
    //  后续 8-bit 物理线复用为 payload[5:0] + req_toggle + ack_toggle
    input wire[7:0] chip_data_i,
    output reg[7:0] chip_data_o

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
    localparam[3:0] S_RX_ADDR3  = 4'd1;
    localparam[3:0] S_RX_ADDR2  = 4'd2;
    localparam[3:0] S_RX_ADDR1  = 4'd3;
    localparam[3:0] S_RX_ADDR0  = 4'd4;
    localparam[3:0] S_RX_DATA3  = 4'd5;
    localparam[3:0] S_RX_DATA2  = 4'd6;
    localparam[3:0] S_RX_DATA1  = 4'd7;
    localparam[3:0] S_RX_DATA0  = 4'd8;
    localparam[3:0] S_TX_RACK   = 4'd9;
    localparam[3:0] S_TX_DATA3  = 4'd10;
    localparam[3:0] S_TX_DATA2  = 4'd11;
    localparam[3:0] S_TX_DATA1  = 4'd12;
    localparam[3:0] S_TX_DATA0  = 4'd13;
    localparam[3:0] S_TX_WACK   = 4'd14;

    reg[3:0] state;
    reg target;
    reg req_we;
    reg[`MemAddrBus] addr;
    reg[`MemBus] wdata;
    reg[`MemBus] rdata;

    reg[`MemBus] fpga_rom[0:`RomNum - 1];
    reg[`MemBus] fpga_ram[0:`MemNum - 1];

    integer i;

    wire[7:0] rom_index = addr[9:2];
    wire[3:0] ram_index = addr[5:2];

    localparam[3:0] RX_HEAD_CHUNKS  = 4'd2; //  命令头 8bit 需要 2 个 6bit 分片解析
    localparam[3:0] RX_READ_CHUNKS  = 4'd7; //  读请求 CMD+ADDR 共 40bit，补 2bit 后为 7 个 6bit 分片
    localparam[3:0] RX_WRITE_CHUNKS = 4'd12; //  写请求 CMD+ADDR+WDATA 共 72bit，为 12 个 6bit 分片
    localparam[3:0] RESP_WRITE_CHUNKS = 4'd2; //  写响应 RESP_WRITE 共 8bit，需要 2 个 6bit 分片
    localparam[3:0] RESP_READ_CHUNKS  = 4'd7; //  读响应 RESP_READ+RDATA 共 40bit，补 2bit 后为 7 个 6bit 分片

    wire[5:0] chip_payload_i = chip_data_i[5:0]; //  芯片发送方向的 6bit payload
    wire chip_req_toggle_i = chip_data_i[6]; //  芯片发送方向的 req toggle
    wire chip_ack_toggle_i = chip_data_i[7]; //  芯片对 FPGA 返回方向的 ack toggle

    reg[71:0] tx_frame; //  FPGA 返回帧缓存，最大容纳 72bit
    reg[3:0] tx_chunks_total; //  当前返回帧需要发送的 6bit 分片数量
    reg[3:0] tx_chunk_index; //  当前返回帧发送分片序号
    reg[5:0] tx_payload; //  FPGA 输出到芯片的 6bit payload
    reg tx_req_toggle; //  FPGA 返回方向 req toggle
    reg tx_wait_ack; //  FPGA 返回方向正在等待芯片 ack

    reg chip_ack_meta; //  芯片 ack toggle 第一级同步寄存器
    reg chip_ack_sync; //  芯片 ack toggle 第二级同步寄存器
    reg chip_req_meta; //  芯片 req toggle 第一级同步寄存器
    reg chip_req_sync; //  芯片 req toggle 第二级同步寄存器
    reg chip_req_sync_d; //  芯片 req toggle 延迟一拍，用于检测 toggle 变化
    reg rx_ack_toggle; //  FPGA 接收芯片分片后的 ack toggle
    reg rx_ack_pending; //功能：延迟一拍返回接收 ack，避免对方过早发送下一分片
    reg[3:0] rx_chunk_index; //  当前正在接收的 6bit 分片序号
    reg[5:0] rx_chunk0; //  接收帧第 0 个 6bit 分片
    reg[5:0] rx_chunk1; //  接收帧第 1 个 6bit 分片
    reg[5:0] rx_chunk2; //  接收帧第 2 个 6bit 分片
    reg[5:0] rx_chunk3; //  接收帧第 3 个 6bit 分片
    reg[5:0] rx_chunk4; //  接收帧第 4 个 6bit 分片
    reg[5:0] rx_chunk5; //  接收帧第 5 个 6bit 分片
    reg[5:0] rx_chunk6; //  接收帧第 6 个 6bit 分片
    reg[5:0] rx_chunk7; //  接收帧第 7 个 6bit 分片
    reg[5:0] rx_chunk8; //  接收帧第 8 个 6bit 分片
    reg[5:0] rx_chunk9; //  接收帧第 9 个 6bit 分片
    reg[5:0] rx_chunk10; //  接收帧第 10 个 6bit 分片

    wire rx_chunk_valid = (chip_req_sync != chip_req_sync_d); //  检测到芯片 req toggle 翻转时表示收到一个新分片
    wire tx_ack_done = (tx_wait_ack == 1'b1) && (chip_ack_sync == tx_req_toggle); //  芯片 ack toggle 追上本次 req toggle 时表示当前返回分片发送完成
    wire[7:0] rx_cmd_byte = {rx_chunk0, chip_payload_i[5:4]}; //  前两个请求分片拼出 8bit CMD
    wire[31:0] rx_addr_word = {rx_chunk1[3:0], rx_chunk2, rx_chunk3, rx_chunk4, rx_chunk5, chip_payload_i[5:2]}; //  请求分片 1~6 拼出 32bit 地址
    wire[31:0] rx_wdata_word = {rx_chunk6[1:0], rx_chunk7, rx_chunk8, rx_chunk9, rx_chunk10, chip_payload_i}; //  写请求分片 6~11 拼出 32bit 写数据

    function [5:0] get_tx_chunk; //  按分片序号从 72bit 返回帧中取出 6bit payload
        input[71:0] frame; //  待发送返回帧
        input[3:0] chunk_index; //  待取出的分片序号
        begin //  函数主体开始
            case (chunk_index) //  根据分片序号选择固定 6bit 区间
                4'd0: get_tx_chunk = frame[71:66]; //  第 0 个分片
                4'd1: get_tx_chunk = frame[65:60]; //  第 1 个分片
                4'd2: get_tx_chunk = frame[59:54]; //  第 2 个分片
                4'd3: get_tx_chunk = frame[53:48]; //  第 3 个分片
                4'd4: get_tx_chunk = frame[47:42]; //  第 4 个分片
                4'd5: get_tx_chunk = frame[41:36]; //  第 5 个分片
                4'd6: get_tx_chunk = frame[35:30]; //  第 6 个分片
                4'd7: get_tx_chunk = frame[29:24]; //  第 7 个分片
                4'd8: get_tx_chunk = frame[23:18]; //  第 8 个分片
                4'd9: get_tx_chunk = frame[17:12]; //  第 9 个分片
                4'd10: get_tx_chunk = frame[11:6]; //  第 10 个分片
                4'd11: get_tx_chunk = frame[5:0]; //  第 11 个分片
                default: get_tx_chunk = 6'h00; //  异常分片序号默认返回 0
            endcase //  分片选择结束
        end //  函数主体结束
    endfunction //  get_tx_chunk 函数结束

    initial begin
        for (i = 0; i < `RomNum; i = i + 1) begin
            fpga_rom[i] = `ZeroWord;
        end

        for (i = 0; i < `MemNum; i = i + 1) begin
            fpga_ram[i] = `ZeroWord;
        end
    end

//    always @ (posedge clk) begin
//        if (rst == `RstEnable) begin
//            state <= S_IDLE;
//            target <= TARGET_ROM;
//            req_we <= `WriteDisable;
//            addr <= `ZeroWord;
//            wdata <= `ZeroWord;
//            rdata <= `ZeroWord;
//            chip_data_o <= 8'h00;
//        end else begin
//            chip_data_o <= 8'h00;
//
//            case (state)
//                S_IDLE: begin
//                    case (chip_data_i)
//                        CMD_ROM_RD: begin
//                            target <= TARGET_ROM;
//                            req_we <= `WriteDisable;
//                            state <= S_RX_ADDR3;
//                        end
//
//                        CMD_ROM_WR: begin
//                            target <= TARGET_ROM;
//                            req_we <= `WriteEnable;
//                            state <= S_RX_ADDR3;
//                        end
//
//                        CMD_RAM_RD: begin
//                            target <= TARGET_RAM;
//                            req_we <= `WriteDisable;
//                            state <= S_RX_ADDR3;
//                        end
//
//                        CMD_RAM_WR: begin
//                            target <= TARGET_RAM;
//                            req_we <= `WriteEnable;
//                            state <= S_RX_ADDR3;
//                        end
//
//                        default: begin
//                            state <= S_IDLE;
//                        end
//                    endcase
//                end
//
//                S_RX_ADDR3: begin
//                    addr[31:24] <= chip_data_i;
//                    state <= S_RX_ADDR2;
//                end
//
//                S_RX_ADDR2: begin
//                    addr[23:16] <= chip_data_i;
//                    state <= S_RX_ADDR1;
//                end
//
//                S_RX_ADDR1: begin
//                    addr[15:8] <= chip_data_i;
//                    state <= S_RX_ADDR0;
//                end
//
//                S_RX_ADDR0: begin
//                    addr[7:0] <= chip_data_i;
//                    if (req_we == `WriteEnable) begin
//                        state <= S_RX_DATA3;
//                    end else begin
//                        if (target == TARGET_RAM) begin
//                            rdata <= fpga_ram[chip_data_i[5:2]];
//                        end else begin
//                            rdata <= fpga_rom[{addr[9:8], chip_data_i[7:2]}];
//                        end
//                        state <= S_TX_RACK;
//                    end
//                end
//
//                S_RX_DATA3: begin
//                    wdata[31:24] <= chip_data_i;
//                    state <= S_RX_DATA2;
//                end
//
//                S_RX_DATA2: begin
//                    wdata[23:16] <= chip_data_i;
//                    state <= S_RX_DATA1;
//                end
//
//                S_RX_DATA1: begin
//                    wdata[15:8] <= chip_data_i;
//                    state <= S_RX_DATA0;
//                end
//
//                S_RX_DATA0: begin
//                    wdata[7:0] <= chip_data_i;
//                    if (target == TARGET_RAM) begin
//                        fpga_ram[ram_index] <= {wdata[31:8], chip_data_i};
//                    end else begin
//                        fpga_rom[rom_index] <= {wdata[31:8], chip_data_i};
//                    end
//                    state <= S_TX_WACK;
//                end
//
//                S_TX_RACK: begin
//                    chip_data_o <= RESP_READ;
//                    state <= S_TX_DATA3;
//                end
//
//                S_TX_DATA3: begin
//                    chip_data_o <= rdata[31:24];
//                    state <= S_TX_DATA2;
//                end
//
//                S_TX_DATA2: begin
//                    chip_data_o <= rdata[23:16];
//                    state <= S_TX_DATA1;
//                end
//
//                S_TX_DATA1: begin
//                    chip_data_o <= rdata[15:8];
//                    state <= S_TX_DATA0;
//                end
//
//                S_TX_DATA0: begin
//                    chip_data_o <= rdata[7:0];
//                    state <= S_IDLE;
//                end
//
//                S_TX_WACK: begin
//                    chip_data_o <= RESP_WRITE;
//                    state <= S_IDLE;
//                end
//
//                default: begin
//                    state <= S_IDLE;
//                end
//            endcase
//        end
//    end

    always @ (posedge clk) begin //  6bit payload + req/ack toggle 协议状态机
        if (rst == `RstEnable) begin //  低有效复位
            state <= S_IDLE; //  复位后回到空闲状态
            target <= TARGET_ROM; //  复位后默认目标为 ROM
            req_we <= `WriteDisable; //  复位后默认读方向
            addr <= `ZeroWord; //  清空地址缓存
            wdata <= `ZeroWord; //  清空写数据缓存
            rdata <= `ZeroWord; //  清空读数据缓存
            chip_data_o <= 8'h00; //  清空 8bit 物理输出线
            tx_frame <= 72'h0; //  清空返回帧缓存
            tx_chunks_total <= 4'h0; //  清空返回分片总数
            tx_chunk_index <= 4'h0; //  清空返回分片序号
            tx_payload <= 6'h00; //  清空返回 payload
            tx_req_toggle <= 1'b0; //  清空 FPGA 返回 req toggle
            tx_wait_ack <= 1'b0; //  清空等待芯片 ack 标志
            chip_ack_meta <= 1'b0; //  清空 ack 一级同步寄存器
            chip_ack_sync <= 1'b0; //  清空 ack 二级同步寄存器
            chip_req_meta <= 1'b0; //  清空 req 一级同步寄存器
            chip_req_sync <= 1'b0; //  清空 req 二级同步寄存器
            chip_req_sync_d <= 1'b0; //  清空 req 延迟寄存器
            rx_ack_toggle <= 1'b0; //  清空 FPGA 接收 ack toggle
            rx_ack_pending <= 1'b0; //功能：清空接收 ack 延迟标志
            rx_chunk_index <= 4'h0; //  清空接收分片序号
            rx_chunk0 <= 6'h00; //  清空接收分片 0
            rx_chunk1 <= 6'h00; //  清空接收分片 1
            rx_chunk2 <= 6'h00; //  清空接收分片 2
            rx_chunk3 <= 6'h00; //  清空接收分片 3
            rx_chunk4 <= 6'h00; //  清空接收分片 4
            rx_chunk5 <= 6'h00; //  清空接收分片 5
            rx_chunk6 <= 6'h00; //  清空接收分片 6
            rx_chunk7 <= 6'h00; //  清空接收分片 7
            rx_chunk8 <= 6'h00; //  清空接收分片 8
            rx_chunk9 <= 6'h00; //  清空接收分片 9
            rx_chunk10 <= 6'h00; //  清空接收分片 10
        end else begin //  正常工作分支
            chip_ack_meta <= chip_ack_toggle_i; //  同步芯片对 FPGA 返回方向的 ack toggle
            chip_ack_sync <= chip_ack_meta; //  ack toggle 第二级同步
            chip_req_meta <= chip_req_toggle_i; //  同步芯片发送方向的 req toggle
            chip_req_sync <= chip_req_meta; //  req toggle 第二级同步
            chip_req_sync_d <= chip_req_sync; //  保存上一拍 req toggle 用于边沿检测
            chip_data_o <= {rx_ack_toggle, tx_req_toggle, tx_payload}; //  8bit 输出线复用为 ack/req/payload

            if (rx_ack_pending == 1'b1) begin //功能：上一拍已收到新分片，本拍再返回 ack
                rx_ack_toggle <= chip_req_sync; //功能：ack toggle 跟随已稳定接收的 req toggle
                rx_ack_pending <= 1'b0; //功能：清除接收 ack 延迟标志
            end else if (rx_chunk_valid == 1'b1) begin //  收到芯片发送方向的新分片
                rx_ack_pending <= 1'b1; //功能：延迟一拍再 ack，保证本地 toggle 历史已更新
            end //  接收 ack 更新结束

            case (state) //  6+2 协议主状态机
                S_IDLE: begin //  空闲状态等待请求命令头
                    tx_wait_ack <= 1'b0; //  空闲时不等待发送 ack
                    tx_chunk_index <= 4'h0; //  空闲时返回分片序号归零
                    if (rx_chunk_valid == 1'b1) begin //  收到一个请求头分片
                        if (rx_chunk_index == 4'd0) begin //  收到请求分片 0
                            rx_chunk0 <= chip_payload_i; //  保存请求分片 0
                            rx_chunk_index <= 4'd1; //  下一次等待请求分片 1
                        end else if (rx_chunk_index == 4'd1) begin //  收到请求分片 1 后可解析 CMD
                            rx_chunk1 <= chip_payload_i; //  保存请求分片 1
                            if (rx_cmd_byte == CMD_ROM_RD) begin //  收到 ROM 读命令
                                target <= TARGET_ROM; //  缓存目标为 ROM
                                req_we <= `WriteDisable; //  缓存为读操作
                                rx_chunk_index <= RX_HEAD_CHUNKS; //  后续从地址分片 2 开始接收
                                state <= S_RX_ADDR3; //  进入地址分片接收状态
                            end else if (rx_cmd_byte == CMD_ROM_WR) begin //  收到 ROM 写命令
                                target <= TARGET_ROM; //  缓存目标为 ROM
                                req_we <= `WriteEnable; //  缓存为写操作
                                rx_chunk_index <= RX_HEAD_CHUNKS; //  后续从地址分片 2 开始接收
                                state <= S_RX_ADDR3; //  进入地址分片接收状态
                            end else if (rx_cmd_byte == CMD_RAM_RD) begin //  收到 RAM 读命令
                                target <= TARGET_RAM; //  缓存目标为 RAM
                                req_we <= `WriteDisable; //  缓存为读操作
                                rx_chunk_index <= RX_HEAD_CHUNKS; //  后续从地址分片 2 开始接收
                                state <= S_RX_ADDR3; //  进入地址分片接收状态
                            end else if (rx_cmd_byte == CMD_RAM_WR) begin //  收到 RAM 写命令
                                target <= TARGET_RAM; //  缓存目标为 RAM
                                req_we <= `WriteEnable; //  缓存为写操作
                                rx_chunk_index <= RX_HEAD_CHUNKS; //  后续从地址分片 2 开始接收
                                state <= S_RX_ADDR3; //  进入地址分片接收状态
                            end else begin //  未知命令
                                rx_chunk_index <= 4'h0; //  丢弃未知命令并重新等待请求头
                            end //  CMD 解析结束
                        end else begin //  异常请求头分片序号
                            rx_chunk_index <= 4'h0; //  异常时重新等待请求头
                        end //  请求头接收判断结束
                    end //  请求头分片有效判断结束
                end //  S_IDLE 结束

                S_RX_ADDR3: begin //  接收地址剩余 5 个 6bit 分片，沿用旧状态名
                    if (rx_chunk_valid == 1'b1) begin //  收到一个地址分片
                        case (rx_chunk_index) //  根据分片序号保存地址分片
                            4'd2: begin //  收到地址分片 2
                                rx_chunk2 <= chip_payload_i; //  保存地址分片 2
                                rx_chunk_index <= 4'd3; //  下一次等待分片 3
                            end //  分片 2 处理结束
                            4'd3: begin //  收到地址分片 3
                                rx_chunk3 <= chip_payload_i; //  保存地址分片 3
                                rx_chunk_index <= 4'd4; //  下一次等待分片 4
                            end //  分片 3 处理结束
                            4'd4: begin //  收到地址分片 4
                                rx_chunk4 <= chip_payload_i; //  保存地址分片 4
                                rx_chunk_index <= 4'd5; //  下一次等待分片 5
                            end //  分片 4 处理结束
                            4'd5: begin //  收到地址分片 5
                                rx_chunk5 <= chip_payload_i; //  保存地址分片 5
                                rx_chunk_index <= 4'd6; //  下一次等待分片 6
                            end //  分片 5 处理结束
                            4'd6: begin //  收到地址最后一个分片 6
                                rx_chunk6 <= chip_payload_i; //  保存地址分片 6
                                addr <= rx_addr_word; //  拼接并缓存完整 32bit 地址
                                if (req_we == `WriteEnable) begin //  写请求还需要继续接收写数据分片
                                    rx_chunk_index <= 4'd7; //  下一次等待写数据分片 7
                                    state <= S_RX_DATA3; //  进入写数据分片接收状态
                                end else begin //  读请求地址收齐后访问 ROM/RAM
                                    if (target == TARGET_RAM) begin //  读访问目标为 RAM
                                        rdata <= fpga_ram[rx_addr_word[5:2]]; //  读取 RAM 数据
                                        tx_frame <= {RESP_READ, fpga_ram[rx_addr_word[5:2]], 2'b00, 30'h0}; //  构造读响应返回帧
                                    end else begin //  读访问目标为 ROM
                                        rdata <= fpga_rom[rx_addr_word[9:2]]; //  读取 ROM 数据
                                        tx_frame <= {RESP_READ, fpga_rom[rx_addr_word[9:2]], 2'b00, 30'h0}; //  构造读响应返回帧
                                    end //  ROM/RAM 读数据选择结束
                                    tx_chunks_total <= RESP_READ_CHUNKS; //  读响应需要发送 7 个分片
                                    tx_chunk_index <= 4'h0; //  返回分片序号归零
                                    tx_wait_ack <= 1'b0; //  准备发送返回帧
                                    rx_chunk_index <= 4'h0; //  请求接收分片序号归零
                                    state <= S_TX_RACK; //  进入读响应分片发送状态
                                end //  读写方向处理结束
                            end //  地址分片 6 处理结束
                            default: begin //  异常地址分片序号
                                rx_chunk_index <= RX_HEAD_CHUNKS; //  异常时回到地址分片 2
                            end //  异常分支结束
                        endcase //  地址分片保存结束
                    end //  地址分片有效判断结束
                end //  S_RX_ADDR3 结束

                S_RX_DATA3: begin //  接收写数据剩余 5 个 6bit 分片，沿用旧状态名
                    if (rx_chunk_valid == 1'b1) begin //  收到一个写数据分片
                        case (rx_chunk_index) //  根据分片序号保存写数据分片
                            4'd7: begin //  收到写数据分片 7
                                rx_chunk7 <= chip_payload_i; //  保存写数据分片 7
                                rx_chunk_index <= 4'd8; //  下一次等待分片 8
                            end //  分片 7 处理结束
                            4'd8: begin //  收到写数据分片 8
                                rx_chunk8 <= chip_payload_i; //  保存写数据分片 8
                                rx_chunk_index <= 4'd9; //  下一次等待分片 9
                            end //  分片 8 处理结束
                            4'd9: begin //  收到写数据分片 9
                                rx_chunk9 <= chip_payload_i; //  保存写数据分片 9
                                rx_chunk_index <= 4'd10; //  下一次等待分片 10
                            end //  分片 9 处理结束
                            4'd10: begin //  收到写数据分片 10
                                rx_chunk10 <= chip_payload_i; //  保存写数据分片 10
                                rx_chunk_index <= 4'd11; //  下一次等待分片 11
                            end //  分片 10 处理结束
                            4'd11: begin //  收到写数据最后一个分片 11
                                wdata <= rx_wdata_word; //  拼接并缓存完整 32bit 写数据
                                if (target == TARGET_RAM) begin //  写访问目标为 RAM
                                    fpga_ram[ram_index] <= rx_wdata_word; //  写入 RAM
                                end else begin //  写访问目标为 ROM
                                    fpga_rom[rom_index] <= rx_wdata_word; //  写入 ROM
                                end //  ROM/RAM 写入选择结束
                                tx_frame <= {RESP_WRITE, 64'h0}; //  构造写完成响应返回帧
                                tx_chunks_total <= RESP_WRITE_CHUNKS; //  写响应需要发送 2 个分片
                                tx_chunk_index <= 4'h0; //  返回分片序号归零
                                tx_wait_ack <= 1'b0; //  准备发送写响应
                                rx_chunk_index <= 4'h0; //  请求接收分片序号归零
                                state <= S_TX_WACK; //  进入写响应分片发送状态
                            end //  分片 11 处理结束
                            default: begin //  异常写数据分片序号
                                rx_chunk_index <= 4'd7; //  异常时回到写数据分片 7
                            end //  异常分支结束
                        endcase //  写数据分片保存结束
                    end //  写数据分片有效判断结束
                end //  S_RX_DATA3 结束

                S_TX_RACK: begin //  发送读响应帧的所有 6bit 分片
                    if (tx_wait_ack == 1'b0) begin //  当前没有等待 ack 时启动一个新分片
                        tx_payload <= get_tx_chunk(tx_frame, tx_chunk_index); //  取出当前 6bit 返回分片
                        tx_req_toggle <= ~tx_req_toggle; //  翻转 req toggle 表示新返回分片有效
                        tx_wait_ack <= 1'b1; //  进入等待芯片 ack 状态
                    end else if (tx_ack_done == 1'b1) begin //  芯片已确认当前返回分片
                        tx_wait_ack <= 1'b0; //  清除等待 ack 标志
                        if (tx_chunk_index == (tx_chunks_total - 1'b1)) begin //  当前返回分片是本帧最后一个分片
                            tx_chunk_index <= 4'h0; //  返回分片序号归零
                            rx_chunk_index <= 4'h0; //  准备接收下一笔请求
                            state <= S_IDLE; //  返回帧发送完成后回到空闲
                        end else begin //  当前返回帧还有后续分片
                            tx_chunk_index <= tx_chunk_index + 1'b1; //  返回分片序号加一
                        end //  返回分片完成判断结束
                    end //  发送握手处理结束
                end //  S_TX_RACK 结束

                S_TX_WACK: begin //  发送写响应帧的所有 6bit 分片
                    if (tx_wait_ack == 1'b0) begin //  当前没有等待 ack 时启动一个新分片
                        tx_payload <= get_tx_chunk(tx_frame, tx_chunk_index); //  取出当前 6bit 返回分片
                        tx_req_toggle <= ~tx_req_toggle; //  翻转 req toggle 表示新返回分片有效
                        tx_wait_ack <= 1'b1; //  进入等待芯片 ack 状态
                    end else if (tx_ack_done == 1'b1) begin //  芯片已确认当前返回分片
                        tx_wait_ack <= 1'b0; //  清除等待 ack 标志
                        if (tx_chunk_index == (tx_chunks_total - 1'b1)) begin //  当前返回分片是本帧最后一个分片
                            tx_chunk_index <= 4'h0; //  返回分片序号归零
                            rx_chunk_index <= 4'h0; //  准备接收下一笔请求
                            state <= S_IDLE; //  返回帧发送完成后回到空闲
                        end else begin //  当前返回帧还有后续分片
                            tx_chunk_index <= tx_chunk_index + 1'b1; //  返回分片序号加一
                        end //  返回分片完成判断结束
                    end //  发送握手处理结束
                end //  S_TX_WACK 结束

                default: begin //  异常状态保护
                    state <= S_IDLE; //  未知状态回到空闲
                end //  default 结束
            endcase //  6+2 协议状态机结束
        end //  正常工作分支结束
    end //  6+2 协议时序块结束

endmodule
