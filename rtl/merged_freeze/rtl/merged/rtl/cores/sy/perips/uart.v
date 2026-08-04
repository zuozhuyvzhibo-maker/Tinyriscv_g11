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


`include "sy_defs.v"



// SY-prefixed private RTL module for the four-core integration.
module sy_uart(

	input wire clk,
	input wire rst,

    input wire we_i,
    input wire[31:0] addr_i,
    input wire[31:0] data_i,
    input wire sid_req_i,
    input wire ifire_req_i,
    input wire[7:0] ifire_data_i,
    output reg[31:0] data_o,
	output wire tx_pin,
    input wire rx_pin

    );



`ifdef IVERILOG_FAST_SIM
    localparam BAUD_115200 = 32'h8;
`else
    localparam BAUD_115200 = 32'h1B8;
`endif

    localparam S_IDLE       = 4'b0001;
    localparam S_START      = 4'b0010;
    localparam S_SEND_BYTE  = 4'b0100;
    localparam S_STOP       = 4'b1000;

    reg tx_data_valid;
    reg tx_data_ready;

    reg[3:0] state;
    reg[15:0] cycle_cnt;
    reg[3:0] bit_cnt;
    reg[7:0] tx_data;
    reg tx_reg;

    reg rx_q0;
    reg rx_q1;
    wire rx_negedge;
    reg rx_start;
    reg[3:0] rx_clk_edge_cnt;
    reg rx_clk_edge_level;
    reg rx_done;
    reg[15:0] rx_clk_cnt;
    reg[15:0] rx_div_cnt;
    reg[7:0] rx_data;
    reg rx_over;

    localparam UART_CTRL = 8'h0;
    localparam UART_STATUS = 8'h4;
    localparam UART_BAUD = 8'h8;
    localparam UART_TXDATA = 8'hc;
    localparam UART_RXDATA = 8'h10;
    localparam UART_EXT = 8'h14;

    // addr: 0x00
    // rw. bit[0]: tx enable, 1 = enable, 0 = disable
    // rw. bit[1]: rx enable, 1 = enable, 0 = disable
    reg[31:0] uart_ctrl;

    // addr: 0x04
    // ro. bit[0]: tx busy, 1 = busy, 0 = idle
    // rw. bit[1]: rx over, 1 = over, 0 = receiving
    // must check this bit before tx data
    reg[31:0] uart_status;

    // addr: 0x08
    // rw. clk div
    reg[31:0] uart_baud;

    // addr: 0x10
    // ro. rx data
    reg[31:0] uart_rx;

    assign tx_pin = tx_reg;

    // extend register
    reg[31:0] ext_reg;

    // TX stream data counter
    reg[3:0] tx_seq_cnt;

    // TX stream data active flag
    reg tx_seq_active;


    always @ (posedge clk) begin
        if (rst == 1'b0) begin
            uart_ctrl <= 32'h0;
            uart_status <= 32'h0;
            uart_rx <= 32'h0;
            uart_baud <= BAUD_115200;
            tx_data_valid <= 1'b0;
            ext_reg <= 32'b0;
            tx_seq_cnt <= 8'b0;
            tx_seq_active <= 1'b0;
        end else begin
            if (tx_seq_active && tx_data_ready && (tx_seq_cnt == 4'd10)) begin
                // remove active flag
                tx_seq_active <= 1'b0;
                ext_reg[1:0] <= 2'b0;
            end
            if (we_i == 1'b1) begin
                case (addr_i[7:0])
                    UART_CTRL: begin
                        uart_ctrl <= data_i;
                    end
                    UART_BAUD: begin
                        uart_baud <= data_i;
                    end
                    UART_STATUS: begin
                        uart_status[1] <= data_i[1];
                    end
                    UART_TXDATA: begin
                        if (uart_ctrl[0] == 1'b1 && uart_status[0] == 1'b0) begin
                            tx_data <= data_i[7:0];
                            uart_status[0] <= 1'b1;
                            tx_data_valid <= 1'b1;
                        end
                    end
                    UART_EXT: begin
                        ext_reg <= data_i;
                        if (uart_ctrl[0] == 1'b1 && data_i[1:0] == `SY_UART_SIDFLG && uart_status[0] == 1'b0) begin
                            // stream output initialization
                            tx_seq_cnt <= 4'd0;
                            tx_seq_active <= 1'b1;
                            // data initialization
                            tx_data <= `SY_STDID_CODE0;
                            tx_data_valid <= 1'b1;
                            uart_status[0] <= 1'b1;
                            // counter incr.
                            tx_seq_cnt <= tx_seq_cnt + 4'b1;
                        end
                    end
                endcase
            end else if (tx_seq_active == 1'b1 && uart_status[0] == 1'b0) begin
                case (tx_seq_cnt)
                    4'd1: begin
                        tx_data <= `SY_STDID_CODE1;
                    end
                    4'd2: begin
                        tx_data <= `SY_STDID_CODE2;
                    end
                    4'd3: begin
                        tx_data <= `SY_STDID_CODE3;
                    end
                    4'd4: begin
                        tx_data <= `SY_STDID_CODE4;
                    end
                    4'd5: begin
                        tx_data <= `SY_STDID_CODE5;
                    end
                    4'd6: begin
                        tx_data <= `SY_STDID_CODE6;
                    end
                    4'd7: begin
                        tx_data <= `SY_STDID_CODE7;
                    end
                    4'd8: begin
                        tx_data <= `SY_STDID_CODE8;
                    end
                    4'd9: begin
                        tx_data <= `SY_STDID_CODE9;
                    end
                endcase
                tx_data_valid <= 1'b1;
                uart_status[0] <= 1'b1;
                tx_seq_cnt <= tx_seq_cnt + 4'b1;
            end else begin
                tx_data_valid <= 1'b0;
                if (tx_data_ready == 1'b1) begin
                    uart_status[0] <= 1'b0;
                end
                if (uart_ctrl[1] == 1'b1) begin
                    if (rx_over == 1'b1) begin
                        uart_status[1] <= 1'b1;
                        uart_rx <= {24'h0, rx_data};
                    end
                end
            end
        end
    end


    always @ (*) begin
        if (rst == 1'b0) begin
            data_o = 32'h0;
        end else begin
            case (addr_i[7:0])
                UART_CTRL: begin
                    data_o = uart_ctrl;
                end
                UART_STATUS: begin
                    data_o = uart_status;
                end
                UART_BAUD: begin
                    data_o = uart_baud;
                end
                UART_RXDATA: begin
                    data_o = uart_rx;
                end
                UART_EXT: begin
                    data_o = ext_reg;
                end
                default: begin
                    data_o = 32'h0;
                end
            endcase
        end
    end



    always @ (posedge clk) begin
        if (rst == 1'b0) begin
            state <= S_IDLE;
            cycle_cnt <= 16'd0;
            tx_reg <= 1'b1;
            bit_cnt <= 4'd0;
            tx_data_ready <= 1'b0;
        end else begin
            if (state == S_IDLE) begin
                tx_reg <= 1'b1;
                tx_data_ready <= 1'b0;
                if (tx_data_valid == 1'b1) begin
                    state <= S_START;
                    cycle_cnt <= 16'd0;
                    bit_cnt <= 4'd0;
                    tx_reg <= 1'b0;
                end
            end else begin
                cycle_cnt <= cycle_cnt + 16'd1;
                if (cycle_cnt == uart_baud[15:0]) begin
                    cycle_cnt <= 16'd0;
                    case (state)
                        S_START: begin
                            tx_reg <= tx_data[bit_cnt];
                            state <= S_SEND_BYTE;
                            bit_cnt <= bit_cnt + 4'd1;
                        end
                        S_SEND_BYTE: begin
                            bit_cnt <= bit_cnt + 4'd1;
                            if (bit_cnt == 4'd8) begin
                                state <= S_STOP;
                                tx_reg <= 1'b1;
                            end else begin
                                tx_reg <= tx_data[bit_cnt];
                            end
                        end
                        S_STOP: begin
                            tx_reg <= 1'b1;
                            state <= S_IDLE;
                            tx_data_ready <= 1'b1;
                        end
                    endcase
                end
            end
        end
    end




    assign rx_negedge = rx_q1 && ~rx_q0;


    always @ (posedge clk) begin
        if (rst == 1'b0) begin
            rx_q0 <= 1'b0;
            rx_q1 <= 1'b0;
        end else begin
            rx_q0 <= rx_pin;
            rx_q1 <= rx_q0;
        end
    end


    always @ (posedge clk) begin
        if (rst == 1'b0) begin
            rx_start <= 1'b0;
        end else begin
            if (uart_ctrl[1]) begin
                if (rx_negedge) begin
                    rx_start <= 1'b1;
                end else if (rx_clk_edge_cnt == 4'd9) begin
                    rx_start <= 1'b0;
                end
            end else begin
                rx_start <= 1'b0;
            end
        end
    end

    always @ (posedge clk) begin
        if (rst == 1'b0) begin
            rx_div_cnt <= 16'h0;
        end else begin

            if (rx_start == 1'b1 && rx_clk_edge_cnt == 4'h0) begin
                rx_div_cnt <= {1'b0, uart_baud[15:1]};
            end else begin
                rx_div_cnt <= uart_baud[15:0];
            end
        end
    end


    always @ (posedge clk) begin
        if (rst == 1'b0) begin
            rx_clk_cnt <= 16'h0;
        end else if (rx_start == 1'b1) begin

            if (rx_clk_cnt == rx_div_cnt) begin
                rx_clk_cnt <= 16'h0;
            end else begin
                rx_clk_cnt <= rx_clk_cnt + 1'b1;
            end
        end else begin
            rx_clk_cnt <= 16'h0;
        end
    end


    always @ (posedge clk) begin
        if (rst == 1'b0) begin
            rx_clk_edge_cnt <= 4'h0;
            rx_clk_edge_level <= 1'b0;
        end else if (rx_start == 1'b1) begin

            if (rx_clk_cnt == rx_div_cnt) begin

                if (rx_clk_edge_cnt == 4'd9) begin
                    rx_clk_edge_cnt <= 4'h0;
                    rx_clk_edge_level <= 1'b0;
                end else begin

                    rx_clk_edge_cnt <= rx_clk_edge_cnt + 1'b1;

                    rx_clk_edge_level <= 1'b1;
                end
            end else begin
                rx_clk_edge_level <= 1'b0;
            end
        end else begin
            rx_clk_edge_cnt <= 4'h0;
            rx_clk_edge_level <= 1'b0;
        end
    end


    always @ (posedge clk) begin
        if (rst == 1'b0) begin
            rx_data <= 8'h0;
            rx_over <= 1'b0;
        end else begin
            if (rx_start == 1'b1) begin

                if (rx_clk_edge_level == 1'b1) begin
                    case (rx_clk_edge_cnt)

                        1: begin

                        end

                        2, 3, 4, 5, 6, 7, 8, 9: begin
                            rx_data <= rx_data | (rx_pin << (rx_clk_edge_cnt - 2));

                            if (rx_clk_edge_cnt == 4'h9) begin
                                rx_over <= 1'b1;
                            end
                        end
                    endcase
                end
            end else begin
                rx_data <= 8'h0;
                rx_over <= 1'b0;
            end
        end
    end

endmodule
