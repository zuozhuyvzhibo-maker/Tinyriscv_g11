 /*                                                                      
 Copyright 2020 Blue Liang, liangkangnan@163.com
                                                                         
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


// clk = 50MHz鏃跺搴旂殑娉㈢壒鐜囧垎棰戠郴鏁?
`ifdef FAST_UART_SIM
`define UART_BAUD_115200        32'h8
`elsif IVERILOG_FAST_SIM
`define UART_BAUD_115200        32'h8
`else
`define UART_BAUD_115200        32'h1B8
`endif

// 涓插彛瀵勫瓨鍣ㄥ湴鍧€
`define UART_CTRL_REG           32'h30000000
`define UART_STATUS_REG         32'h30000004
`define UART_BAUD_REG           32'h30000008
`define UART_TX_REG             32'h3000000c
`define UART_RX_REG             32'h30000010

`define UART_TX_BUSY_FLAG       32'h1
`define UART_RX_OVER_FLAG       32'h2

// 绗竴涓寘鐨勫ぇ灏?
`define UART_FIRST_PACKET_LEN   8'd35
// 鍏朵粬鍖呯殑澶у皬(姣忔鐑у啓鐨勫瓧鑺傛暟)
`define UART_REMAIN_PACKET_LEN  8'd35

`define UART_RESP_ACK           32'h6
`define UART_RESP_NAK           32'h15

// 鐑у啓璧峰鍦板潃
`define ROM_START_ADDR          32'h0
`define AckEnable              1'b1


// 涓插彛鏇存柊鍥轰欢妯″潡
module ldk_uart_debug(

    input wire clk,                // 鏃堕挓淇″彿
    input wire rst,                // 澶嶄綅淇″彿

    input wire debug_en_i,         // 妯″潡浣胯兘淇″彿

    input wire mem_write_ack_i,    // 鍐呭瓨鍐欏叆瀹屾垚淇″彿

    output wire req_o,
    output reg mem_we_o,
    output reg[31:0] mem_addr_o,
    output reg[31:0] mem_wdata_o,
    input wire[31:0] mem_rdata_i

    );


    // 鐘舵€?
    localparam S_IDLE                    = 15'h0001;
    localparam S_INIT_UART_BAUD          = 15'h0002;
    localparam S_CLEAR_UART_RX_OVER_FLAG = 15'h0004;
    localparam S_WAIT_BYTE               = 15'h0008;
    localparam S_WAIT_BYTE2              = 15'h0010;
    localparam S_GET_BYTE                = 15'h0020;
    localparam S_REC_FIRST_PACKET        = 15'h0040;
    localparam S_REC_REMAIN_PACKET       = 15'h0080;
    localparam S_SEND_ACK                = 15'h0100;
    localparam S_SEND_NAK                = 15'h0200;
    localparam S_CRC_START               = 15'h0400;
    localparam S_CRC_CALC                = 15'h0800;
    localparam S_CRC_END                 = 15'h1000;
    localparam S_WRITE_MEM               = 15'h2000;
    localparam S_WRITE_WAIT              = 15'h4000;

    reg[14:0] state;

    // 瀛樻斁涓插彛鎺ユ敹鍒扮殑鏁版嵁
    reg[7:0] rx_data[0:131];
    reg[7:0] rec_bytes_index;
    reg[7:0] need_to_rec_bytes;
    reg[15:0] remain_packet_count;
    reg[31:0] fw_file_size;
    reg[31:0] write_mem_addr;
    reg[31:0] write_mem_data;
    reg[7:0] write_mem_byte_index0;
    reg[7:0] write_mem_byte_index1;
    reg[7:0] write_mem_byte_index2;
    reg[7:0] write_mem_byte_index3;

    reg[15:0] crc_result;
    reg[3:0] crc_bit_index;
    reg[7:0] crc_byte_index;


    // 鍚戞€荤嚎璇锋眰淇″彿
    assign req_o = (rst == 1'b1 && debug_en_i == 1'b1)? 1'b1: 1'b0;


    always @ (posedge clk) begin
        if (rst == 1'b0 || debug_en_i == 1'b0) begin
            mem_addr_o <= 32'h0;
            mem_we_o <= 1'b0;
            mem_wdata_o <= 32'h0;
            state <= S_IDLE;
            remain_packet_count <= 16'h0;
        end else begin
            case (state)
                S_IDLE: begin // UART鐨勬帶鍒跺瘎瀛樺櫒鍐欏叆鍐呭锛屼娇鑳経ART妯″潡锛屼娇鍏跺彲鍙戦€佸彲鎺ユ敹
                    mem_addr_o <= `UART_CTRL_REG;
                    mem_wdata_o <= 32'h3;
                    mem_we_o <= 1'b1;
                    state <= S_INIT_UART_BAUD;
                end
                S_INIT_UART_BAUD: begin // UART鐨勬尝鐗圭巼鎺у埗鍣紝澹版槑UART鐨勬尝鐗圭巼
                    mem_addr_o <= `UART_BAUD_REG;
                    mem_wdata_o <= `UART_BAUD_115200;
                    mem_we_o <= 1'b1;
                    state <= S_REC_FIRST_PACKET;
                end
                S_REC_FIRST_PACKET: begin // 鎺ュ彈绗竴涓暟鎹寘锛岀涓€涓暟鎹寘鍖呭惈浜嗗浐浠剁殑澶у皬淇℃伅
                    remain_packet_count <= 16'h0;
                    mem_addr_o <= 32'h0;
                    mem_we_o <= 1'b0;
                    mem_wdata_o <= 32'h0;
                    state <= S_CLEAR_UART_RX_OVER_FLAG;
                end
                S_REC_REMAIN_PACKET: begin // 鎺ユ敹鍓╀綑鐨勬暟鎹寘锛岀洿鍒版帴鏀跺畬鎵€鏈夌殑鍥轰欢鏁版嵁
                    mem_addr_o <= 32'h0;
                    mem_we_o <= 1'b0;
                    mem_wdata_o <= 32'h0;
                    state <= S_CLEAR_UART_RX_OVER_FLAG;
                end
                S_CLEAR_UART_RX_OVER_FLAG: begin
                    mem_addr_o <= `UART_STATUS_REG;
                    mem_wdata_o <= 32'h0;
                    mem_we_o <= 1'b1;
                    state <= S_WAIT_BYTE;
                end
                S_WAIT_BYTE: begin
                    mem_addr_o <= `UART_STATUS_REG;
                    mem_wdata_o <= 32'h0;
                    mem_we_o <= 1'b0;
                    state <= S_WAIT_BYTE2;
                end
                S_WAIT_BYTE2: begin
                    if ((mem_rdata_i & `UART_RX_OVER_FLAG) == `UART_RX_OVER_FLAG) begin
                        mem_addr_o <= `UART_RX_REG;
                        mem_wdata_o <= 32'h0;
                        mem_we_o <= 1'b0;
                        state <= S_GET_BYTE;
                    end
                end
                S_GET_BYTE: begin
                    if (rec_bytes_index == (need_to_rec_bytes - 1'b1)) begin
                        state <= S_CRC_START;
                    end else begin
                        state <= S_CLEAR_UART_RX_OVER_FLAG;
                    end
                end
                S_CRC_START: begin
                    state <= S_CRC_CALC;
                end
                S_CRC_CALC: begin
                    if ((crc_byte_index == need_to_rec_bytes - 2) && crc_bit_index == 4'h8) begin
                        state <= S_CRC_END;
                    end
                end
                S_CRC_END: begin
                    if (crc_result == {rx_data[need_to_rec_bytes - 1], rx_data[need_to_rec_bytes - 2]}) begin
                        if (need_to_rec_bytes == `UART_FIRST_PACKET_LEN && remain_packet_count == 16'h0) begin
                            remain_packet_count <= {5'h0, fw_file_size[31:5]} + 1'b1;
                            state <= S_SEND_ACK;
                        end else begin
                            remain_packet_count <= remain_packet_count - 1'b1;
                            state <= S_WRITE_MEM;
                        end
                    end else begin
                        state <= S_SEND_NAK;
                    end
                end
                S_WRITE_MEM: begin
                    if (write_mem_byte_index0 == (need_to_rec_bytes + 2)) begin
                        state <= S_SEND_ACK;
                    end else begin
                        mem_addr_o <= write_mem_addr;
                        mem_wdata_o <= write_mem_data;
                        mem_we_o <= 1'b1;
                        state <= S_WRITE_WAIT;
                    end
                end
                S_WRITE_WAIT:begin
                    if ( mem_write_ack_i == `AckEnable ) begin
                        state <= S_WRITE_MEM ;
                    end
                end
                S_SEND_ACK: begin
                    mem_addr_o <= `UART_TX_REG;
                    mem_wdata_o <= `UART_RESP_ACK;
                    mem_we_o <= 1'b1;
                    if (remain_packet_count > 0) begin
                        state <= S_REC_REMAIN_PACKET;
                    end else begin
                        state <= S_REC_FIRST_PACKET;
                    end
                end
                S_SEND_NAK: begin
                    mem_addr_o <= `UART_TX_REG;
                    mem_wdata_o <= `UART_RESP_NAK;
                    mem_we_o <= 1'b1;
                    if (remain_packet_count > 0) begin
                        state <= S_REC_REMAIN_PACKET;
                    end else begin
                        state <= S_REC_FIRST_PACKET;
                    end
                end
            endcase
        end
    end

    // 鏁版嵁鍖呯殑澶у皬
    always @ (posedge clk) begin
        if (rst == 1'b0 || debug_en_i == 1'b0) begin
            need_to_rec_bytes <= 8'h0;
        end else begin
            case (state)
                S_REC_FIRST_PACKET: begin
                    need_to_rec_bytes <= `UART_FIRST_PACKET_LEN;
                end
                S_REC_REMAIN_PACKET: begin
                    need_to_rec_bytes <= `UART_REMAIN_PACKET_LEN;
                end
            endcase
        end
    end

    // 璇绘帴鏀跺埌鐨勪覆鍙ｆ暟鎹?
    always @ (posedge clk) begin
        if (rst == 1'b0 || debug_en_i == 1'b0) begin
            rec_bytes_index <= 8'h0;
        end else begin
            case (state)
                S_GET_BYTE: begin
                    rx_data[rec_bytes_index] <= mem_rdata_i[7:0];
                    rec_bytes_index <= rec_bytes_index + 1'b1;
                end
                S_REC_FIRST_PACKET: begin
                    rec_bytes_index <= 8'h0;
                end
                S_REC_REMAIN_PACKET: begin
                    rec_bytes_index <= 8'h0;
                end
            endcase
        end
    end

    // 鍥轰欢澶у皬
    always @ (posedge clk) begin
        if (rst == 1'b0 || debug_en_i == 1'b0) begin
            fw_file_size <= 32'h0;
        end else begin
            case (state)
                S_CRC_START: begin
                    fw_file_size <= {rx_data[25], rx_data[26], rx_data[27], rx_data[28]};
                end
            endcase
        end
    end

    // 鐑у啓鍥轰欢锛屽湴鍧€鐨勬洿鏂?
    always @ (posedge clk) begin
        if (rst == 1'b0 || debug_en_i == 1'b0) begin
            write_mem_addr <= 32'h0;
        end else begin
            case (state)
                S_REC_FIRST_PACKET: begin
                    write_mem_addr <= `ROM_START_ADDR;
                end
                S_CRC_END: begin
                    if (write_mem_addr > 0)
                        write_mem_addr <= write_mem_addr - 4;
                end
                S_WRITE_MEM: begin
                    write_mem_addr <= write_mem_addr + 4;
                end
            endcase
        end
    end
    // 鐑у啓鍥轰欢锛屾暟鎹殑鏇存柊
    always @ (posedge clk) begin
        if (rst == 1'b0 || debug_en_i == 1'b0) begin
            write_mem_data <= 32'h0;
        end else begin
            case (state)
                S_REC_FIRST_PACKET: begin
                    write_mem_data <= 32'h0;
                end
                S_CRC_END: begin
                    write_mem_data <= {rx_data[4], rx_data[3], rx_data[2], rx_data[1]};
                end
                S_WRITE_MEM: begin
                    write_mem_data <= {rx_data[write_mem_byte_index3], rx_data[write_mem_byte_index2], rx_data[write_mem_byte_index1], rx_data[write_mem_byte_index0]};
                end
            endcase
        end
    end

    always @ (posedge clk) begin
        if (rst == 1'b0 || debug_en_i == 1'b0) begin
            write_mem_byte_index0 <= 8'h0;
        end else begin
            case (state)
                S_REC_FIRST_PACKET: begin
                    write_mem_byte_index0 <= 8'h0;
                end
                S_CRC_END: begin
                    write_mem_byte_index0 <= 8'h5;
                end
                S_WRITE_MEM: begin
                    write_mem_byte_index0 <= write_mem_byte_index0 + 4;
                end
            endcase
        end
    end

    always @ (posedge clk) begin
        if (rst == 1'b0 || debug_en_i == 1'b0) begin
            write_mem_byte_index1 <= 8'h0;
        end else begin
            case (state)
                S_REC_FIRST_PACKET: begin
                    write_mem_byte_index1 <= 8'h0;
                end
                S_CRC_END: begin
                    write_mem_byte_index1 <= 8'h6;
                end
                S_WRITE_MEM: begin
                    write_mem_byte_index1 <= write_mem_byte_index1 + 4;
                end
            endcase
        end
    end

    always @ (posedge clk) begin
        if (rst == 1'b0 || debug_en_i == 1'b0) begin
            write_mem_byte_index2 <= 8'h0;
        end else begin
            case (state)
                S_REC_FIRST_PACKET: begin
                    write_mem_byte_index2 <= 8'h0;
                end
                S_CRC_END: begin
                    write_mem_byte_index2 <= 8'h7;
                end
                S_WRITE_MEM: begin
                    write_mem_byte_index2 <= write_mem_byte_index2 + 4;
                end
            endcase
        end
    end

    always @ (posedge clk) begin
        if (rst == 1'b0 || debug_en_i == 1'b0) begin
            write_mem_byte_index3 <= 8'h0;
        end else begin
            case (state)
                S_REC_FIRST_PACKET: begin
                    write_mem_byte_index3 <= 8'h0;
                end
                S_CRC_END: begin
                    write_mem_byte_index3 <= 8'h8;
                end
                S_WRITE_MEM: begin
                    write_mem_byte_index3 <= write_mem_byte_index3 + 4;
                end
            endcase
        end
    end

    // CRC璁＄畻
    always @ (posedge clk) begin
        if (rst == 1'b0 || debug_en_i == 1'b0) begin
            crc_result <= 16'h0;
        end else begin
            case (state)
                S_CRC_START: begin
                    crc_result <= 16'hffff;
                end
                S_CRC_CALC: begin
                    if (crc_bit_index == 4'h0) begin
                        crc_result <= crc_result ^ rx_data[crc_byte_index];
                    end else begin
                        if (crc_bit_index < 4'h9) begin
                            if (crc_result[0] == 1'b1) begin
                                crc_result <= {1'b0, crc_result[15:1]} ^ 16'ha001;
                            end else begin
                                crc_result <= {1'b0, crc_result[15:1]};
                            end
                        end
                    end
                end
            endcase
        end
    end

    always @ (posedge clk) begin
        if (rst == 1'b0 || debug_en_i == 1'b0) begin
            crc_bit_index <= 4'h0;
        end else begin
            case (state)
                S_CRC_START: begin
                    crc_bit_index <= 4'h0;
                end
                S_CRC_CALC: begin
                    if (crc_bit_index < 4'h9) begin
                        crc_bit_index <= crc_bit_index + 1'b1;
                    end else begin
                        crc_bit_index <= 4'h0;
                    end
                end
            endcase
        end
    end

    always @ (posedge clk) begin
        if (rst == 1'b0 || debug_en_i == 1'b0) begin
            crc_byte_index <= 8'h0;
        end else begin
            case (state)
                S_CRC_START: begin
                    crc_byte_index <= 8'h1;
                end
                S_CRC_CALC: begin
                    if (crc_bit_index == 4'h0) begin
                        crc_byte_index <= crc_byte_index + 1'b1;
                    end
                end
            endcase
        end
    end

endmodule
