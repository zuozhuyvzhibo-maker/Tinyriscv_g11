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

`include "../core/defines.v"

// IIC模块
module sy_iic(

	input wire clk,
	input wire rst,

    input wire we_i,
    input wire[31:0] addr_i,
    input wire[31:0] data_i,

    output reg[31:0] data_o,
    output reg io_scl,
    inout wire io_sda

    );
    // clock divide parameters
    localparam DIV_CLK = 32'd200; // 50MHz/400kHz = 125, leave some slack
    localparam DIV_CLK_M = DIV_CLK >> 1; // middle(negedge) of the scl
    localparam DIV_CLK_PM = (DIV_CLK >> 2) - 32'd1; // middle of the scl-HIGH
    localparam DIV_CLK_NM = DIV_CLK_M + DIV_CLK_PM; // middle of the scl-LOW

    // state parameters
    localparam IDLE = 4'b0000;
    localparam START = 4'b0001;
    localparam ADDR_1ST = 4'b0010;
    localparam ACK_1ST = 4'b0011;
    localparam PTR = 4'b0100;
    localparam ACK_2ND = 4'b0101;
    localparam RE_START = 4'b0110;
    localparam ADDR_2ND = 4'b0111;
    localparam ACK_3RD = 4'b1000;
    localparam R_DATA = 4'b1001;
    localparam ACK_4TH = 4'b1010;
    localparam NACK = 4'b1011;
    localparam W_DATA = 4'b1100;
    localparam ACK_5TH = 4'b1101;
    localparam STOP = 4'b1110;

    // 32-bit slave address register (R/W)
    reg [31:0] slv_addr_reg;
    reg [31:0] slv_addr_latch;
    // [---HOLD---][---1-bit read flag---][---8-bit ptr address---][---7-bit slave address---]

    // 32-bit output data counter (R/W)
    reg [31:0] out_reg;
    reg [31:0] out_latch;

    // 32-bit input data register (read only)
    reg [31:0] in_reg;

    // 32-bit clock counter
    reg [31:0] clk_cnt;

    // two 1-bit flag register (1:PM 0:NM)
    reg [1:0] flag_reg;

    // 4-bit state register
    reg [3:0] state;

    // 1-bit sda register and enable signal
    reg sda_en, sda_reg;
    assign io_sda = sda_en ? sda_reg : 1'bz; // 3-state buffer

    // 1-bit read/write flag (1:read 0:write)
    reg rw_flag;

    // 4-bit byte data counter
    reg [3:0] bit_reg;

    // 16:1 pump serializer
    reg [15:0] data_ser;

    // 1-bit byte flag(1:2B 0:1B)
    reg byte_flag;

    // 26-bit time counter for low-power R&W
    reg [25:0] tim;

    // 时间计数器计数
    always @(posedge clk) begin
        if(rst == 1'b0) begin
            tim <= 26'd0;
        end else begin 
            tim <= tim + 26'b1;
        end
    end

    // 写寄存器
    always @(posedge clk) begin
        if (rst == 1'b0) begin
            slv_addr_reg <= {25'b0, `IIC_SLV_ADDR};
            out_reg <= 32'b0; // all zero value
            // in_reg don't need initialization, avoid multi driven
        end else if (we_i == 1'b1) begin
            case (addr_i[17:16])
                2'b01: begin
                    slv_addr_reg <= data_i;
                end
                2'b10: begin
                    out_reg <= data_i;
                end
                default: begin
                    // don't change anything
                    slv_addr_reg <= slv_addr_reg;
                    out_reg <= out_reg;
                end
            endcase
        end else begin
            slv_addr_reg <= slv_addr_reg;
            out_reg <= out_reg;
        end
    end

    // 读寄存器
    always @(*) begin
        if (rst == 1'b0) begin
            data_o = 32'b0;
        end else begin
            case (addr_i[17:16])
                2'b01: begin
                    data_o = slv_addr_reg;
                end
                2'b10: begin
                    data_o = out_reg;
                end
                2'b11: begin
                    data_o = in_reg;
                end
                default: begin
                    data_o = 32'b0;
                end
            endcase
        end
    end

    // 时钟分频计数
    always @(posedge clk) begin
        if (rst == 1'b0) begin
            clk_cnt <= 32'b0;
        end else if (clk_cnt < DIV_CLK) begin
            clk_cnt <= clk_cnt + 32'b1;
        end else begin
            // if not enable, scl should remain HIGH
            clk_cnt <= 32'b0;
        end
    end

    // 时钟分频输出(1 tap for glitch-free)
    always @(posedge clk) begin
        if (rst == 1'b0) begin
            // reset state is HIGH
            io_scl <= 1'b1; 
        end else if (clk_cnt >= DIV_CLK_M) begin
            io_scl <= 1'b0;
        end else begin
            io_scl <= 1'b1;
        end
    end

    // 时钟相位标志位
    always @(posedge clk) begin
        if (rst == 1'b0) begin
            flag_reg <= 2'b0; 
        end else if (clk_cnt == DIV_CLK_NM) begin
            flag_reg <= 2'b01;
        end else if (clk_cnt == DIV_CLK_PM) begin
            flag_reg <= 2'b10;
        end else begin
            flag_reg <= 2'b0;
        end
    end

    // 状态转换
    always @(posedge clk) begin
        if (rst == 1'b0) begin
            state <= IDLE;
            // no data output(reset to HIGH)
            sda_reg <= 1'b1;
            // sda set to output
            sda_en <= 1'b1;
            // default to read
            rw_flag <= 1'b1;
            // default slave address & data
            slv_addr_latch <= 32'b0;
            out_latch <= 32'b0;
            // bit counter reset
            bit_reg <= 4'b0;
            // address serializer reset
            data_ser <= 16'b0;
            // byte flag reset
            byte_flag <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (tim[25] == 1'b0) begin
                        // jump to START
                        state <= START;
                        // sample slave address & data
                        slv_addr_latch <= slv_addr_reg;
                        out_latch <= out_reg;
                        // signals remain unchange
                        sda_reg <= 1'b1;
                        sda_en <= 1'b1;
                        if (slv_addr_reg[8:7] == 2'b00) begin
                            // TEMP is a read-only reg, force read
                            rw_flag <= 1'b1;
                        end else begin
                            rw_flag <= ~slv_addr_reg[15];
                        end
                        bit_reg <= 4'b0;
                        data_ser <= 16'b0;
                        if (slv_addr_reg[8:7] == 2'b01) begin
                            // CFG, 1 byte
                            byte_flag <= 1'b0;
                        end else begin
                            // OTHER, 2 bytes
                            byte_flag <= 1'b1;
                        end
                    end else begin
                        state <= IDLE;
                    end
                end
                START: begin
                    if (flag_reg[1] == 1'b1) begin
                        // jump to ADDR_1ST
                        state <= ADDR_1ST;
                        // sda HIGH-to-LOW
                        sda_reg <= 1'b0;
                        // bit counter set to 8
                        bit_reg <= 4'b1000;
                        // sample slave address(W set)
                        data_ser <= {8'b0, slv_addr_latch[6:0], 1'b0}; 
                    end else begin
                        // don't jump
                        state <= START;
                    end
                end
                ADDR_1ST: begin
                    if (flag_reg[0] == 1'b1) begin
                        if (bit_reg == 4'b0) begin
                            // jump to ACK_1ST
                            state <= ACK_1ST;
                            // sda change to input 
                            sda_en <= 1'b0;
                        end else begin
                            // don't jump
                            state <= ADDR_1ST;
                            // sda output
                            sda_reg <= data_ser[7];
                            // bit counter -1
                            bit_reg <= bit_reg - 4'b1;
                            // serializer shift (LSB)
                            data_ser <= {data_ser[15:8], data_ser[6:0], 1'b0};
                        end
                    end else begin
                        // don't jump
                        state <= ADDR_1ST;
                    end
                end
                ACK_1ST: begin
                    if (flag_reg[1] == 1'b1) begin
                        if (io_sda == 1'b0) begin
                            // jump to PTR
                            state <= PTR;
                            // bit counter set to 8
                            bit_reg <= 4'b1000;
                            // sample pointer value
                            data_ser <= {8'b0, slv_addr_latch[14:7]};
                        end else begin
                            // jump to IDLE, retry
                            state <= IDLE;
                        end
                    end else begin
                        // don't jump
                        state <= ACK_1ST;
                    end
                end
                PTR: begin
                    if (flag_reg[0] == 1'b1) begin
                        if (bit_reg == 4'b0) begin
                            // jump to ACK_2ND
                            state <= ACK_2ND;
                            // sda change to input 
                            sda_en <= 1'b0;
                        end else begin
                            // don't jump
                            state <= PTR;
                            // reset sda to output
                            sda_en <= 1'b1;
                            // sda output
                            sda_reg <= data_ser[7];
                            // bit counter -1
                            bit_reg <= bit_reg - 4'b1;
                            // serializer shift
                            data_ser <= {data_ser[15:8], data_ser[6:0], 1'b0};
                        end
                    end else begin
                        // don't jump
                        state <= PTR;
                    end
                end
                ACK_2ND: begin
                    if (flag_reg[1] == 1'b1) begin
                        if (io_sda == 1'b0) begin
                            if (rw_flag == 1'b1) begin
                                // jump to RE_START, read
                                state <= RE_START;
                                // sda reset to HIGH
                                sda_reg <= 1'b1;
                            end else begin
                                // jump to W_DATA, write
                                state <= W_DATA;
                                // bit counter set to 8
                                bit_reg <= 4'b1000;
                                // sample pointer value
                                if (byte_flag == 1'b1) begin
                                    // write MSB
                                    data_ser <= {8'b0, out_latch[15:8]};
                                end else begin
                                    // write MSB = LSB
                                    data_ser <= {8'b0, out_latch[7:0]};
                                end
                            end
                        end else begin
                            // jump to IDLE, retry
                            state <= IDLE;
                        end
                    end else begin
                        // don't jump
                        state <= ACK_2ND;
                    end
                end
                RE_START: begin
                    if (flag_reg[0] == 1'b1) begin
                        // don't jump
                        state <= RE_START;
                        // sda change to output 
                        sda_en <= 1'b1;
                    end else if (flag_reg[1] == 1'b1) begin
                        // jump to ADDR_2ND
                        state <= ADDR_2ND;
                        // sda HIGH-to-LOW
                        sda_reg <= 1'b0;
                        // bit counter set to 8
                        bit_reg <= 4'b1000;
                        // sample slave address(R set)
                        data_ser <= {8'b0, slv_addr_latch[6:0], 1'b1}; 
                    end else begin
                        // don't jump
                        state <= RE_START;
                    end
                end
                ADDR_2ND: begin
                    if (flag_reg[0] == 1'b1) begin
                        if (bit_reg == 4'b0) begin
                            // jump to ACK_3RD
                            state <= ACK_3RD;
                            // sda change to input 
                            sda_en <= 1'b0;
                        end else begin
                            // don't jump
                            state <= ADDR_2ND;
                            // sda output
                            sda_reg <= data_ser[7];
                            // bit counter -1
                            bit_reg <= bit_reg - 4'b1;
                            // serializer shift
                            data_ser <= {data_ser[15:8], data_ser[6:0], 1'b0};
                        end
                    end else begin
                        // don't jump
                        state <= ADDR_2ND;
                    end
                end
                ACK_3RD: begin
                    if (flag_reg[1] == 1'b1) begin
                        if (io_sda == 1'b0) begin
                            // jump to R_DATA
                            state <= R_DATA;
                            // bit counter set to 8
                            bit_reg <= 4'b1000;
                        end else begin
                            // jump to IDLE, retry
                            state <= IDLE;
                        end
                    end else begin
                        // don't jump
                        state <= ACK_3RD;
                    end
                end
                R_DATA: begin
                    if (flag_reg[1] == 1'b1) begin
                        // don't jump
                        state <= R_DATA;
                        // bit counter -1
                        bit_reg <= bit_reg - 4'b1;
                        // serializer reuse
                        data_ser <= {data_ser[15:0], io_sda};
                    end else if ((flag_reg[0] == 1'b1) && (bit_reg == 4'b0)) begin
                        if (byte_flag == 1'b1) begin
                            // jump to ACK_4TH
                            state <= ACK_4TH;
                            // one byte left
                            byte_flag <= 1'b0;
                            // sda send ACK signal LOW
                            sda_reg <= 1'b0;
                        end else begin
                            // jump to NACK, no byte left
                            state <= NACK;
                            // no byte left;
                            byte_flag <= byte_flag;
                            // sda send NACK signal HIGH
                            sda_reg <= 1'b1;
                        end
                        // sda change to output 
                        sda_en <= 1'b1;
                    end else begin
                        // don't jump
                        state <= R_DATA;
                    end
                end
                ACK_4TH: begin
                    if (flag_reg[0] == 1'b1) begin
                        // jump back to R_DATA
                        state <= R_DATA;
                        // sda change to input 
                        sda_en <= 1'b0;
                        // bit counter set to 8
                        bit_reg <= 4'b1000;
                    end else begin
                        // don't jump 
                        state <= ACK_4TH;
                    end
                end
                NACK: begin
                    if (flag_reg[0] == 1'b1) begin
                        // jump to STOP
                        state <= STOP;
                        // sda output set to LOW
                        sda_reg <= 1'b0;
                    end else begin
                        // don't jump 
                        state <= NACK;
                    end
                end
                W_DATA: begin
                    if (flag_reg[0] == 1'b1) begin
                        if (bit_reg == 4'b0) begin
                            // jump to ACK_5TH
                            state <= ACK_5TH;
                            // sda change to input 
                            sda_en <= 1'b0;
                        end else begin
                            // don't jump
                            state <= W_DATA;
                            // reset sda to output
                            sda_en <= 1'b1;
                            // sda output
                            sda_reg <= data_ser[7];
                            // bit counter -1
                            bit_reg <= bit_reg - 4'b1;
                            // serializer shift
                            data_ser <= {data_ser[15:8], data_ser[6:0], 1'b0};
                        end
                    end
                end
                ACK_5TH: begin
                    if (flag_reg[1] == 1'b1) begin
                        if (io_sda == 1'b0) begin
                            if (byte_flag == 1'b1) begin
                                // jump back to W_DATA
                                state <= W_DATA;
                                // one byte left
                                byte_flag <= 1'b0;
                                // bit counter set to 8
                                bit_reg <= 4'b1000;
                                // sample pointer value(LSB)
                                data_ser <= {8'b0, out_latch[7:0]};
                            end else begin
                                // jump to STOP
                                state <= STOP;
                                // sda output set to LOW
                                sda_reg <= 1'b0;
                            end
                        end else begin
                            // jump to IDLE, retry
                            state <= IDLE;
                        end
                    end else begin
                        // don't jump
                        state <= ACK_5TH;
                    end
                end
                STOP: begin
                    if (flag_reg[0] == 1'b1) begin
                        // don't jump
                        state <= STOP;
                        // reset sda to output
                        sda_en <= 1'b1;
                    end if (flag_reg[1] == 1'b1) begin
                        // jump to IDLE
                        state <= IDLE;
                        // sda output set to HIGH
                        sda_reg <= 1'b1;
                        // read/write switch
                        // rw_flag <= ~rw_flag;
                        // send data to register
                        if (rw_flag == 1'b1) begin
                            if (slv_addr_latch[8:7] == 2'b00) begin
                                in_reg <= {24'b0, data_ser[14:7]};
                            end else begin
                                in_reg <= {16'b0, data_ser};
                            end
                        end else begin
                            in_reg <= in_reg;
                        end 
                    end else begin
                        // don't jump
                        state <= STOP;
                    end
                end
                default: begin
                    state <= IDLE;
                    // no data output(reset to HIGH)
                    sda_reg <= 1'b1;
                    // sda set to output
                    sda_en <= 1'b1;
                    // default to read
                    rw_flag <= 1'b1;
                    // default slave address & data
                    slv_addr_latch <= 32'b0;
                    out_latch <= 32'b0;
                    // bit counter reset
                    bit_reg <= 4'b0;
                    // address serializer reset
                    data_ser <= 16'b0;
                    // byte flag reset
                    byte_flag <= 1'b0;
                end
            endcase
        end
    end

endmodule
