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

// 鏁版嵁鎺ユ敹绔ā鍧?
// 璺ㄦ椂閽熷煙浼犺緭锛屽叏(鍥涙)鎻℃墜鍗忚
// req = 1
// ack_o = 1
// req = 0
// ack_o = 0
module ldk_full_handshake_rx #(
    parameter DW = 32)(             // RX瑕佹帴鏀舵暟鎹殑浣嶅

    input wire clk,                 // RX绔椂閽熶俊鍙?
    input wire rst_n,               // RX绔浣嶄俊鍙?

    // from tx
    input wire req_i,               // TX绔姹備俊鍙?
    input wire[DW-1:0] req_data_i,  // TX绔緭鍏ユ暟鎹?

    // to tx
    output wire ack_o,              // RX绔簲绛擳X绔俊鍙?

    // to rx
    output wire[DW-1:0] recv_data_o,// RX绔帴鏀跺埌鐨勬暟鎹?
    output wire recv_rdy_o          // RX绔槸鍚︽帴鏀跺埌鏁版嵁淇″彿

    );

    localparam STATE_IDLE     = 2'b01;
    localparam STATE_DEASSERT = 2'b10;

    reg[1:0] state;
    reg[1:0] state_next;

    reg req_d;
    reg req;

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
        end else begin
            state <= state_next;
        end
    end

    always @ (*) begin
        case (state)
            // 绛夊緟TX璇锋眰淇″彿req=1
            STATE_IDLE: begin
                if (req == 1'b1) begin
                    state_next = STATE_DEASSERT;
                end else begin
                    state_next = STATE_IDLE;
                end
            end
            // 绛夊緟req=0
            STATE_DEASSERT: begin
                if (req) begin
                    state_next = STATE_DEASSERT;
                end else begin
                    state_next = STATE_IDLE;
                end
            end
            default: begin
                state_next = STATE_IDLE;
            end
        endcase
    end


    // 灏嗚姹備俊鍙锋墦涓ゆ媿杩涜鍚屾
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            req_d <= 1'b0;
            req <= 1'b0;
        end else begin
            req_d <= req_i;
            req <= req_d;
        end
    end

    reg[DW-1:0] recv_data;
    reg recv_rdy;
    reg ack;

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ack <= 1'b0;
            recv_rdy <= 1'b0;
            recv_data <= {(DW){1'b0}};
        end else begin
            case (state)
                STATE_IDLE: begin
                    if (req == 1'b1) begin
                        ack <= 1'b1;
                        recv_rdy <= 1'b1;           // 杩欎釜淇″彿鍙細鎸佺画涓€涓椂閽?
                        recv_data <= req_data_i;    // 杩欎釜淇″彿鍙細鎸佺画涓€涓椂閽?
                    end
                end
                STATE_DEASSERT: begin
                    recv_rdy <= 1'b0;
                    recv_data <= {(DW){1'b0}};
                    // req鎾ら攢鍚巃ck涔熸挙閿€
                    if (req == 1'b0) begin
                        ack <= 1'b0;
                    end
                end
            endcase
        end
    end

    assign ack_o = ack;
    assign recv_rdy_o = recv_rdy;
    assign recv_data_o = recv_data;

endmodule
