`include "../rtl/core/defines.v"

module lhr_fpga_uart_debug(
    input wire clk,
    input wire rst,
    input wire debug_en_i,

    output wire uart_tx_pin,
    input wire uart_rx_pin,

    output reg rom_we_o,
    output reg[31:0] rom_addr_o,
    output reg[31:0] rom_wdata_o
    );

    localparam UART_BAUD_115200 = 32'h1b8;
    localparam UART_RX_OVER_FLAG = 32'h2;
    localparam UART_PACKET_LEN = 8'd35;
    localparam UART_RESP_ACK = 32'h6;
    localparam UART_RESP_NAK = 32'h15;

    localparam S_IDLE = 5'd0;
    localparam S_INIT_UART_CTRL = 5'd1;
    localparam S_INIT_UART_BAUD = 5'd2;
    localparam S_REC_HEADER = 5'd3;
    localparam S_REC_DATA = 5'd4;
    localparam S_CLEAR_STATUS = 5'd5;
    localparam S_READ_STATUS = 5'd6;
    localparam S_READ_BYTE = 5'd7;
    localparam S_CRC_START = 5'd8;
    localparam S_CRC_CALC = 5'd9;
    localparam S_CRC_CHECK = 5'd10;
    localparam S_WRITE_WORD = 5'd11;
    localparam S_SEND_ACK = 5'd12;
    localparam S_SEND_NAK = 5'd13;

    reg uart_we;
    reg[31:0] uart_addr;
    reg[31:0] uart_wdata;
    wire[31:0] uart_rdata;

    reg[4:0] state;
    reg[7:0] rx_data[0:34];
    reg[7:0] rec_bytes_index;
    reg packet_is_header;
    reg[15:0] remain_packet_count;
    reg[31:0] fw_file_size;
    reg[31:0] write_mem_addr;
    reg[2:0] write_word_index;
    reg[15:0] crc_result;
    reg[3:0] crc_bit_index;
    reg[7:0] crc_byte_index;
    reg[31:0] write_word_data;

    lhr_uart u_debug_uart(
        .clk(clk),
        .rst(rst),
        .we_i(uart_we),
        .addr_i(uart_addr),
        .data_i(uart_wdata),
        .data_o(uart_rdata),
        .tx_pin(uart_tx_pin),
        .rx_pin(uart_rx_pin)
    );

    always @ (*) begin
        case (write_word_index)
            3'd0: write_word_data = {rx_data[4], rx_data[3], rx_data[2], rx_data[1]};
            3'd1: write_word_data = {rx_data[8], rx_data[7], rx_data[6], rx_data[5]};
            3'd2: write_word_data = {rx_data[12], rx_data[11], rx_data[10], rx_data[9]};
            3'd3: write_word_data = {rx_data[16], rx_data[15], rx_data[14], rx_data[13]};
            3'd4: write_word_data = {rx_data[20], rx_data[19], rx_data[18], rx_data[17]};
            3'd5: write_word_data = {rx_data[24], rx_data[23], rx_data[22], rx_data[21]};
            3'd6: write_word_data = {rx_data[28], rx_data[27], rx_data[26], rx_data[25]};
            default: write_word_data = {rx_data[32], rx_data[31], rx_data[30], rx_data[29]};
        endcase
    end

    always @ (*) begin
        uart_we = `WriteDisable;
        uart_addr = `ZeroWord;
        uart_wdata = `ZeroWord;
        rom_we_o = `WriteDisable;
        rom_addr_o = `ZeroWord;
        rom_wdata_o = `ZeroWord;

        if (rst == `RstDisable && debug_en_i == 1'b1) begin
            case (state)
                S_INIT_UART_CTRL: begin
                    uart_we = `WriteEnable;
                    uart_addr = `UART_CTRL_REG;
                    uart_wdata = 32'h3;
                end
                S_INIT_UART_BAUD: begin
                    uart_we = `WriteEnable;
                    uart_addr = `UART_BAUD_REG;
                    uart_wdata = UART_BAUD_115200;
                end
                S_CLEAR_STATUS: begin
                    uart_we = `WriteEnable;
                    uart_addr = `UART_STATUS_REG;
                    uart_wdata = 32'h0;
                end
                S_READ_STATUS: begin
                    uart_addr = `UART_STATUS_REG;
                end
                S_READ_BYTE: begin
                    uart_addr = `UART_RX_REG;
                end
                S_WRITE_WORD: begin
                    rom_we_o = `WriteEnable;
                    rom_addr_o = write_mem_addr;
                    rom_wdata_o = write_word_data;
                end
                S_SEND_ACK: begin
                    uart_we = `WriteEnable;
                    uart_addr = `UART_TX_REG;
                    uart_wdata = UART_RESP_ACK;
                end
                S_SEND_NAK: begin
                    uart_we = `WriteEnable;
                    uart_addr = `UART_TX_REG;
                    uart_wdata = UART_RESP_NAK;
                end
                default: begin
                end
            endcase
        end
    end

    always @ (posedge clk) begin
        if (rst == `RstEnable || debug_en_i == 1'b0) begin
            state <= S_IDLE;
            rec_bytes_index <= 8'h0;
            packet_is_header <= 1'b1;
            remain_packet_count <= 16'h0;
            fw_file_size <= 32'h0;
            write_mem_addr <= `ROM_BASE_ADDR;
            write_word_index <= 3'h0;
            crc_result <= 16'h0;
            crc_bit_index <= 4'h0;
            crc_byte_index <= 8'h0;
        end else begin
            case (state)
                S_IDLE: begin
                    state <= S_INIT_UART_CTRL;
                end
                S_INIT_UART_CTRL: begin
                    state <= S_INIT_UART_BAUD;
                end
                S_INIT_UART_BAUD: begin
                    state <= S_REC_HEADER;
                end
                S_REC_HEADER: begin
                    packet_is_header <= 1'b1;
                    rec_bytes_index <= 8'h0;
                    write_mem_addr <= `ROM_BASE_ADDR;
                    state <= S_CLEAR_STATUS;
                end
                S_REC_DATA: begin
                    packet_is_header <= 1'b0;
                    rec_bytes_index <= 8'h0;
                    state <= S_CLEAR_STATUS;
                end
                S_CLEAR_STATUS: begin
                    state <= S_READ_STATUS;
                end
                S_READ_STATUS: begin
                    if ((uart_rdata & UART_RX_OVER_FLAG) == UART_RX_OVER_FLAG) begin
                        state <= S_READ_BYTE;
                    end else begin
                        state <= S_READ_STATUS;
                    end
                end
                S_READ_BYTE: begin
                    rx_data[rec_bytes_index] <= uart_rdata[7:0];
                    if (rec_bytes_index == UART_PACKET_LEN - 1'b1) begin
                        state <= S_CRC_START;
                    end else begin
                        rec_bytes_index <= rec_bytes_index + 1'b1;
                        state <= S_CLEAR_STATUS;
                    end
                end
                S_CRC_START: begin
                    crc_result <= 16'hffff;
                    crc_byte_index <= 8'd1;
                    crc_bit_index <= 4'h0;
                    state <= S_CRC_CALC;
                end
                S_CRC_CALC: begin
                    if (crc_bit_index == 4'h0) begin
                        crc_result <= crc_result ^ {8'h0, rx_data[crc_byte_index]};
                        crc_bit_index <= 4'h1;
                    end else begin
                        if (crc_result[0] == 1'b1) begin
                            crc_result <= {1'b0, crc_result[15:1]} ^ 16'ha001;
                        end else begin
                            crc_result <= {1'b0, crc_result[15:1]};
                        end

                        if (crc_bit_index == 4'h8) begin
                            if (crc_byte_index == 8'd32) begin
                                state <= S_CRC_CHECK;
                            end else begin
                                crc_byte_index <= crc_byte_index + 1'b1;
                                crc_bit_index <= 4'h0;
                            end
                        end else begin
                            crc_bit_index <= crc_bit_index + 1'b1;
                        end
                    end
                end
                S_CRC_CHECK: begin
                    if (crc_result == {rx_data[34], rx_data[33]}) begin
                        if (packet_is_header == 1'b1) begin
                            fw_file_size <= {rx_data[25], rx_data[26], rx_data[27], rx_data[28]};
                            remain_packet_count <= ({rx_data[25], rx_data[26], rx_data[27], rx_data[28]} >> 5) + 1'b1;
                            state <= S_SEND_ACK;
                        end else begin
                            write_word_index <= 3'h0;
                            state <= S_WRITE_WORD;
                        end
                    end else begin
                        state <= S_SEND_NAK;
                    end
                end
                S_WRITE_WORD: begin
                    if (write_word_index == 3'd7) begin
                        write_mem_addr <= write_mem_addr + 4;
                        remain_packet_count <= remain_packet_count - 1'b1;
                        state <= S_SEND_ACK;
                    end else begin
                        write_word_index <= write_word_index + 1'b1;
                        write_mem_addr <= write_mem_addr + 4;
                    end
                end
                S_SEND_ACK: begin
                    if (remain_packet_count > 0) begin
                        state <= S_REC_DATA;
                    end else begin
                        state <= S_REC_HEADER;
                    end
                end
                S_SEND_NAK: begin
                    if (packet_is_header == 1'b1) begin
                        state <= S_REC_HEADER;
                    end else begin
                        state <= S_REC_DATA;
                    end
                end
                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
