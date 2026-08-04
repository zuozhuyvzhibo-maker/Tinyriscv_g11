`include "wje_defs.v"

/* WJE toggle-handshake protocol adapter without private memory arrays. */
module wje_fpga_bridge_adapter(
    input wire clk,
    input wire rst,
    input wire[7:0] chip_data_i,
    output reg[7:0] chip_data_o,

    output wire rom_we_o,
    output wire[31:0] rom_addr_o,
    output wire[31:0] rom_wdata_o,
    output wire[3:0] rom_wstrb_o,
    input wire[31:0] rom_rdata_i,

    output wire ram_we_o,
    output wire[31:0] ram_addr_o,
    output wire[31:0] ram_wdata_o,
    output wire[3:0] ram_wstrb_o,
    input wire[31:0] ram_rdata_i
    );

    localparam[7:0] CMD_ROM_RD = 8'h11;
    localparam[7:0] CMD_ROM_WR = 8'h12;
    localparam[7:0] CMD_RAM_RD = 8'h21;
    localparam[7:0] CMD_RAM_WR = 8'h22;
    localparam[7:0] RESP_READ = 8'h81;
    localparam[7:0] RESP_WRITE = 8'h82;
    localparam TARGET_ROM = 1'b0;
    localparam TARGET_RAM = 1'b1;

    localparam[3:0] S_IDLE = 4'd0;
    localparam[3:0] S_RX_ADDR = 4'd1;
    localparam[3:0] S_RX_DATA = 4'd2;
    localparam[3:0] S_TX_READ = 4'd3;
    localparam[3:0] S_TX_WRITE = 4'd4;

    localparam[3:0] RX_HEAD_CHUNKS = 4'd2;
    localparam[3:0] RESP_WRITE_CHUNKS = 4'd2;
    localparam[3:0] RESP_READ_CHUNKS = 4'd7;

    reg[3:0] state;
    reg target;
    reg req_we;
    reg[31:0] addr;
    reg[31:0] wdata;
    reg[31:0] rdata;
    reg[3:0] wstrb;

    wire[5:0] chip_payload_i = chip_data_i[5:0];
    wire chip_req_toggle_i = chip_data_i[6];
    wire chip_ack_toggle_i = chip_data_i[7];

    reg[71:0] tx_frame;
    reg[3:0] tx_chunks_total;
    reg[3:0] tx_chunk_index;
    reg[5:0] tx_payload;
    reg tx_req_toggle;
    reg tx_wait_ack;

    reg chip_ack_meta;
    reg chip_ack_sync;
    reg chip_req_meta;
    reg chip_req_sync;
    reg chip_req_sync_d;
    reg rx_ack_toggle;
    reg rx_ack_pending;
    reg[3:0] rx_chunk_index;
    reg[5:0] rx_chunk0;
    reg[5:0] rx_chunk1;
    reg[5:0] rx_chunk2;
    reg[5:0] rx_chunk3;
    reg[5:0] rx_chunk4;
    reg[5:0] rx_chunk5;
    reg[5:0] rx_chunk6;
    reg[5:0] rx_chunk7;
    reg[5:0] rx_chunk8;
    reg[5:0] rx_chunk9;
    reg[5:0] rx_chunk10;

    wire rx_chunk_valid = (chip_req_sync != chip_req_sync_d);
    wire tx_ack_done = tx_wait_ack && (chip_ack_sync == tx_req_toggle);
    wire[7:0] rx_cmd_byte = {rx_chunk0, chip_payload_i[5:4]};
    wire[31:0] rx_addr_word = {rx_chunk1[3:0], rx_chunk2, rx_chunk3,
                               rx_chunk4, rx_chunk5, chip_payload_i[5:2]};
    wire[31:0] rx_wdata_word = {rx_chunk6[1:0], rx_chunk7, rx_chunk8,
                                rx_chunk9, rx_chunk10, chip_payload_i};
    wire address_commit = (state == S_RX_ADDR) && rx_chunk_valid &&
                          (rx_chunk_index == 4'd6);
    wire write_commit = (state == S_RX_DATA) && rx_chunk_valid &&
                        (rx_chunk_index == 4'd11);
    wire[31:0] active_addr = address_commit ? rx_addr_word : addr;
    wire[31:0] merged_ram_wdata = {
        wstrb[3] ? rx_wdata_word[31:24] : ram_rdata_i[31:24],
        wstrb[2] ? rx_wdata_word[23:16] : ram_rdata_i[23:16],
        wstrb[1] ? rx_wdata_word[15:8]  : ram_rdata_i[15:8],
        wstrb[0] ? rx_wdata_word[7:0]   : ram_rdata_i[7:0]
    };

    assign rom_we_o = write_commit && (target == TARGET_ROM);
    assign ram_we_o = write_commit && (target == TARGET_RAM);
    assign rom_addr_o = active_addr;
    assign ram_addr_o = active_addr;
    assign rom_wdata_o = rx_wdata_word;
    assign ram_wdata_o = merged_ram_wdata;
    assign rom_wstrb_o = 4'b1111;
    assign ram_wstrb_o = 4'b1111;

    function [5:0] get_tx_chunk;
        input[71:0] frame;
        input[3:0] chunk_index;
        begin
            case (chunk_index)
                4'd0: get_tx_chunk = frame[71:66];
                4'd1: get_tx_chunk = frame[65:60];
                4'd2: get_tx_chunk = frame[59:54];
                4'd3: get_tx_chunk = frame[53:48];
                4'd4: get_tx_chunk = frame[47:42];
                4'd5: get_tx_chunk = frame[41:36];
                4'd6: get_tx_chunk = frame[35:30];
                4'd7: get_tx_chunk = frame[29:24];
                4'd8: get_tx_chunk = frame[23:18];
                4'd9: get_tx_chunk = frame[17:12];
                4'd10: get_tx_chunk = frame[11:6];
                4'd11: get_tx_chunk = frame[5:0];
                default: get_tx_chunk = 6'h00;
            endcase
        end
    endfunction

    always @ (posedge clk) begin
        if (rst == `WJE_RstEnable) begin
            state <= S_IDLE;
            target <= TARGET_ROM;
            req_we <= `WJE_WriteDisable;
            addr <= 32'h0000_0000;
            wdata <= 32'h0000_0000;
            rdata <= 32'h0000_0000;
            wstrb <= 4'b1111;
            chip_data_o <= 8'h00;
            tx_frame <= 72'h0;
            tx_chunks_total <= 4'h0;
            tx_chunk_index <= 4'h0;
            tx_payload <= 6'h00;
            tx_req_toggle <= 1'b0;
            tx_wait_ack <= 1'b0;
            chip_ack_meta <= 1'b0;
            chip_ack_sync <= 1'b0;
            chip_req_meta <= 1'b0;
            chip_req_sync <= 1'b0;
            chip_req_sync_d <= 1'b0;
            rx_ack_toggle <= 1'b0;
            rx_ack_pending <= 1'b0;
            rx_chunk_index <= 4'h0;
            rx_chunk0 <= 6'h00;
            rx_chunk1 <= 6'h00;
            rx_chunk2 <= 6'h00;
            rx_chunk3 <= 6'h00;
            rx_chunk4 <= 6'h00;
            rx_chunk5 <= 6'h00;
            rx_chunk6 <= 6'h00;
            rx_chunk7 <= 6'h00;
            rx_chunk8 <= 6'h00;
            rx_chunk9 <= 6'h00;
            rx_chunk10 <= 6'h00;
        end else begin
            chip_ack_meta <= chip_ack_toggle_i;
            chip_ack_sync <= chip_ack_meta;
            chip_req_meta <= chip_req_toggle_i;
            chip_req_sync <= chip_req_meta;
            chip_req_sync_d <= chip_req_sync;
            chip_data_o <= {rx_ack_toggle, tx_req_toggle, tx_payload};

            if (rx_ack_pending) begin
                rx_ack_toggle <= chip_req_sync;
                rx_ack_pending <= 1'b0;
            end else if (rx_chunk_valid) begin
                rx_ack_pending <= 1'b1;
            end

            case (state)
                S_IDLE: begin
                    tx_wait_ack <= 1'b0;
                    tx_chunk_index <= 4'h0;
                    if (rx_chunk_valid) begin
                        if (rx_chunk_index == 4'd0) begin
                            rx_chunk0 <= chip_payload_i;
                            rx_chunk_index <= 4'd1;
                        end else if (rx_chunk_index == 4'd1) begin
                            rx_chunk1 <= chip_payload_i;
                            if (rx_cmd_byte == CMD_ROM_RD) begin
                                target <= TARGET_ROM;
                                req_we <= `WJE_WriteDisable;
                                wstrb <= 4'b1111;
                                rx_chunk_index <= RX_HEAD_CHUNKS;
                                state <= S_RX_ADDR;
                            end else if (rx_cmd_byte == CMD_ROM_WR) begin
                                target <= TARGET_ROM;
                                req_we <= `WJE_WriteEnable;
                                wstrb <= 4'b1111;
                                rx_chunk_index <= RX_HEAD_CHUNKS;
                                state <= S_RX_ADDR;
                            end else if (rx_cmd_byte == CMD_RAM_RD) begin
                                target <= TARGET_RAM;
                                req_we <= `WJE_WriteDisable;
                                wstrb <= 4'b1111;
                                rx_chunk_index <= RX_HEAD_CHUNKS;
                                state <= S_RX_ADDR;
                            end else if (rx_cmd_byte == CMD_RAM_WR) begin
                                target <= TARGET_RAM;
                                req_we <= `WJE_WriteEnable;
                                wstrb <= 4'b1111;
                                rx_chunk_index <= RX_HEAD_CHUNKS;
                                state <= S_RX_ADDR;
                            end else if (rx_cmd_byte[7:4] == 4'h3) begin
                                target <= TARGET_RAM;
                                req_we <= `WJE_WriteEnable;
                                wstrb <= rx_cmd_byte[3:0];
                                rx_chunk_index <= RX_HEAD_CHUNKS;
                                state <= S_RX_ADDR;
                            end else begin
                                rx_chunk_index <= 4'h0;
                            end
                        end else begin
                            rx_chunk_index <= 4'h0;
                        end
                    end
                end

                S_RX_ADDR: begin
                    if (rx_chunk_valid) begin
                        case (rx_chunk_index)
                            4'd2: begin rx_chunk2 <= chip_payload_i; rx_chunk_index <= 4'd3; end
                            4'd3: begin rx_chunk3 <= chip_payload_i; rx_chunk_index <= 4'd4; end
                            4'd4: begin rx_chunk4 <= chip_payload_i; rx_chunk_index <= 4'd5; end
                            4'd5: begin rx_chunk5 <= chip_payload_i; rx_chunk_index <= 4'd6; end
                            4'd6: begin
                                rx_chunk6 <= chip_payload_i;
                                addr <= rx_addr_word;
                                if (req_we == `WJE_WriteEnable) begin
                                    rx_chunk_index <= 4'd7;
                                    state <= S_RX_DATA;
                                end else begin
                                    rdata <= (target == TARGET_RAM) ?
                                             ram_rdata_i : rom_rdata_i;
                                    tx_frame <= {RESP_READ,
                                                 ((target == TARGET_RAM) ?
                                                  ram_rdata_i : rom_rdata_i),
                                                 2'b00, 30'h0};
                                    tx_chunks_total <= RESP_READ_CHUNKS;
                                    tx_chunk_index <= 4'h0;
                                    tx_wait_ack <= 1'b0;
                                    rx_chunk_index <= 4'h0;
                                    state <= S_TX_READ;
                                end
                            end
                            default: rx_chunk_index <= RX_HEAD_CHUNKS;
                        endcase
                    end
                end

                S_RX_DATA: begin
                    if (rx_chunk_valid) begin
                        case (rx_chunk_index)
                            4'd7: begin rx_chunk7 <= chip_payload_i; rx_chunk_index <= 4'd8; end
                            4'd8: begin rx_chunk8 <= chip_payload_i; rx_chunk_index <= 4'd9; end
                            4'd9: begin rx_chunk9 <= chip_payload_i; rx_chunk_index <= 4'd10; end
                            4'd10: begin rx_chunk10 <= chip_payload_i; rx_chunk_index <= 4'd11; end
                            4'd11: begin
                                wdata <= rx_wdata_word;
                                tx_frame <= {RESP_WRITE, 64'h0};
                                tx_chunks_total <= RESP_WRITE_CHUNKS;
                                tx_chunk_index <= 4'h0;
                                tx_wait_ack <= 1'b0;
                                rx_chunk_index <= 4'h0;
                                state <= S_TX_WRITE;
                            end
                            default: rx_chunk_index <= 4'd7;
                        endcase
                    end
                end

                S_TX_READ, S_TX_WRITE: begin
                    if (!tx_wait_ack) begin
                        tx_payload <= get_tx_chunk(tx_frame, tx_chunk_index);
                        tx_req_toggle <= ~tx_req_toggle;
                        tx_wait_ack <= 1'b1;
                    end else if (tx_ack_done) begin
                        tx_wait_ack <= 1'b0;
                        if (tx_chunk_index == (tx_chunks_total - 1'b1)) begin
                            tx_chunk_index <= 4'h0;
                            rx_chunk_index <= 4'h0;
                            state <= S_IDLE;
                        end else begin
                            tx_chunk_index <= tx_chunk_index + 1'b1;
                        end
                    end
                end
                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
