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

// 鏁版嵁鍙戦€佺妯″潡
// 璺ㄦ椂閽熷煙浼犺緭锛屽叏(鍥涙)鎻℃墜鍗忚
// req_o = 1
// ack = 1
// req_o = 0
// ack = 0
module ldk_full_handshake_tx #(
    parameter DW = 32)(             // TX瑕佸彂閫佹暟鎹殑浣嶅

    input wire clk,                 // TX绔椂閽熶俊鍙?
    input wire rst_n,               // TX绔浣嶄俊鍙?

    // from rx
    input wire ack_i,               // RX绔簲绛斾俊鍙?

    // from tx
    input wire req_i,               // TX绔姹備俊鍙凤紝鍙渶鎸佺画涓€涓椂閽?
    input wire[DW-1:0] req_data_i,  // TX绔鍙戦€佺殑鏁版嵁锛屽彧闇€鎸佺画涓€涓椂閽?

    // to tx
    output wire idle_o,             // TX绔槸鍚︾┖闂蹭俊鍙凤紝绌洪棽鎵嶈兘鍙戞暟鎹?

    // to rx
    output wire req_o,              // TX绔姹備俊鍙?
    output wire[DW-1:0] req_data_o  // TX绔鍙戦€佺殑鏁版嵁

    );

    localparam STATE_IDLE     = 3'b001;
    localparam STATE_ASSERT   = 3'b010;
    localparam STATE_DEASSERT = 3'b100;

    reg[2:0] state;
    reg[2:0] state_next;
    
    reg ack_d;
    reg ack;

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
        end else begin
            state <= state_next;
        end
    end

    always @ (*) begin
        case (state)
            STATE_IDLE: begin
                if (req_i == 1'b1) begin
                    state_next = STATE_ASSERT;
                end else begin
                    state_next = STATE_IDLE;
                end
            end
            // 绛夊緟ack=1
            STATE_ASSERT: begin
                if (!ack) begin
                    state_next = STATE_ASSERT;
                end else begin
                    state_next = STATE_DEASSERT;
                end
            end
            // 绛夊緟ack=0
            STATE_DEASSERT: begin
                if (!ack) begin
                    state_next = STATE_IDLE;
                end else begin
                    state_next = STATE_DEASSERT;
                end
            end
            default: begin
                state_next = STATE_IDLE;
            end
        endcase
    end


    // 灏嗗簲绛斾俊鍙锋墦涓ゆ媿杩涜鍚屾
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ack_d <= 1'b0;
            ack <= 1'b0;
        end else begin
            ack_d <= ack_i;
            ack <= ack_d;
        end
    end

    reg req;
    reg[DW-1:0] req_data;
    reg idle;

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            idle <= 1'b1;
            req <= 1'b0;
            req_data <= {(DW){1'b0}};
        end else begin
            case (state)
                // 閿佸瓨TX璇锋眰鏁版嵁锛屽湪鏀跺埌ack涔嬪墠涓€鐩翠繚鎸佹湁鏁?
                STATE_IDLE: begin
                    if (req_i == 1'b1) begin
                        idle <= 1'b0;
                        req <= req_i;
                        req_data <= req_data_i;
                    end else begin
                        idle <= 1'b1;
                        req <= 1'b0;
                    end
                end
                // 鏀跺埌RX鐨刟ck涔嬪悗鎾ら攢TX璇锋眰
                STATE_ASSERT: begin
                    if (ack == 1'b1) begin
                        req <= 1'b0;
                        req_data <= {(DW){1'b0}};
                    end
                end
                STATE_DEASSERT: begin
                    if (!ack) begin
                        idle <= 1'b1;
                    end
                end
            endcase
        end
    end

    assign idle_o = idle;
    assign req_o = req;
    assign req_data_o = req_data;

endmodule
