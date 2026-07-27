`include "../core/defines.v"

module i2c(
    input wire clk,
    input wire rst,
    input wire we_i,
    input wire[31:0] addr_i,
    input wire[31:0] data_i,
    output reg[31:0] data_o,
    output wire io_scl,
    inout wire io_sda
    );

    localparam [15:0] I2C_DIV = 16'd250;
    localparam [3:0] S_IDLE = 4'd0;
    localparam [3:0] S_START = 4'd1;
    localparam [3:0] S_SEND_LOW = 4'd2;
    localparam [3:0] S_SEND_HIGH = 4'd3;
    localparam [3:0] S_ACK_LOW = 4'd4;
    localparam [3:0] S_ACK_HIGH = 4'd5;
    localparam [3:0] S_RESTART0 = 4'd6;
    localparam [3:0] S_RESTART1 = 4'd7;
    localparam [3:0] S_RESTART2 = 4'd8;
    localparam [3:0] S_READ_LOW = 4'd9;
    localparam [3:0] S_READ_HIGH = 4'd10;
    localparam [3:0] S_MASTER_ACK_LOW = 4'd11;
    localparam [3:0] S_MASTER_ACK_HIGH = 4'd12;
    localparam [3:0] S_STOP0 = 4'd13;
    localparam [3:0] S_STOP1 = 4'd14;
    localparam [3:0] S_STOP2 = 4'd15;

    reg[6:0] slave_addr;
    reg[31:0] output_data;
    reg[15:0] input_data;
    reg[15:0] div_cnt;
    reg[19:0] idle_cnt;
    reg[3:0] state;
    reg[1:0] step;
    reg[2:0] bit_cnt;
    reg[7:0] shift;
    reg[7:0] read_shift;
    reg scl_reg;
    reg sda_drive_low;

    assign io_scl = scl_reg;
    assign io_sda = sda_drive_low ? 1'b0 : 1'bz;

    wire tick = (div_cnt == I2C_DIV);
    wire sda_in = io_sda;

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            slave_addr <= 7'h48;
            output_data <= 32'h0;
        end else if (we_i == `WriteEnable) begin
            case (addr_i[23:16])
                8'h01: slave_addr <= data_i[6:0];
                8'h02: output_data <= data_i;
                default: begin
                end
            endcase
        end
    end

    always @ (*) begin
        if (rst == `RstEnable) begin
            data_o = `ZeroWord;
        end else begin
            case (addr_i[23:16])
                8'h01: data_o = {25'h0, slave_addr};
                8'h02: data_o = output_data;
                8'h03: data_o = {24'h0, input_data[14:7]};
                default: data_o = `ZeroWord;
            endcase
        end
    end

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            div_cnt <= 16'h0;
        end else if (tick) begin
            div_cnt <= 16'h0;
        end else begin
            div_cnt <= div_cnt + 1'b1;
        end
    end

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            state <= S_IDLE;
            step <= 2'h0;
            bit_cnt <= 3'h7;
            shift <= 8'h0;
            read_shift <= 8'h0;
            input_data <= 16'h1900;
            idle_cnt <= 20'h0;
            scl_reg <= 1'b1;
            sda_drive_low <= 1'b0;
        end else if (tick) begin
            case (state)
                S_IDLE: begin
                    scl_reg <= 1'b1;
                    sda_drive_low <= 1'b0;
                    if (idle_cnt == 20'd10) begin
                        idle_cnt <= 20'h0;
                        step <= 2'h0;
                        shift <= {slave_addr, 1'b0};
                        bit_cnt <= 3'h7;
                        state <= S_START;
                    end else begin
                        idle_cnt <= idle_cnt + 1'b1;
                    end
                end
                S_START: begin
                    scl_reg <= 1'b1;
                    sda_drive_low <= 1'b1;
                    state <= S_SEND_LOW;
                end
                S_SEND_LOW: begin
                    scl_reg <= 1'b0;
                    sda_drive_low <= ~shift[bit_cnt];
                    state <= S_SEND_HIGH;
                end
                S_SEND_HIGH: begin
                    scl_reg <= 1'b1;
                    if (bit_cnt == 3'h0) begin
                        state <= S_ACK_LOW;
                    end else begin
                        bit_cnt <= bit_cnt - 1'b1;
                        state <= S_SEND_LOW;
                    end
                end
                S_ACK_LOW: begin
                    scl_reg <= 1'b0;
                    sda_drive_low <= 1'b0;
                    state <= S_ACK_HIGH;
                end
                S_ACK_HIGH: begin
                    scl_reg <= 1'b1;
                    case (step)
                        2'h0: begin
                            step <= 2'h1;
                            shift <= 8'h00;
                            bit_cnt <= 3'h7;
                            state <= S_SEND_LOW;
                        end
                        2'h1: begin
                            step <= 2'h2;
                            state <= S_RESTART0;
                        end
                        default: begin
                            bit_cnt <= 3'h7;
                            read_shift <= 8'h0;
                            state <= S_READ_LOW;
                        end
                    endcase
                end
                S_RESTART0: begin
                    scl_reg <= 1'b0;
                    sda_drive_low <= 1'b0;
                    state <= S_RESTART1;
                end
                S_RESTART1: begin
                    scl_reg <= 1'b1;
                    sda_drive_low <= 1'b0;
                    state <= S_RESTART2;
                end
                S_RESTART2: begin
                    scl_reg <= 1'b1;
                    sda_drive_low <= 1'b1;
                    shift <= {slave_addr, 1'b1};
                    bit_cnt <= 3'h7;
                    state <= S_SEND_LOW;
                end
                S_READ_LOW: begin
                    scl_reg <= 1'b0;
                    sda_drive_low <= 1'b0;
                    state <= S_READ_HIGH;
                end
                S_READ_HIGH: begin
                    scl_reg <= 1'b1;
                    read_shift[bit_cnt] <= sda_in;
                    if (bit_cnt == 3'h0) begin
                        if (step == 2'h2) begin
                            input_data[15:8] <= {read_shift[7:1], sda_in};
                            step <= 2'h3;
                            state <= S_MASTER_ACK_LOW;
                        end else begin
                            input_data[7:0] <= {read_shift[7:1], sda_in};
                            step <= 2'h0;
                            state <= S_MASTER_ACK_LOW;
                        end
                    end else begin
                        bit_cnt <= bit_cnt - 1'b1;
                        state <= S_READ_LOW;
                    end
                end
                S_MASTER_ACK_LOW: begin
                    scl_reg <= 1'b0;
                    sda_drive_low <= (step == 2'h3);
                    state <= S_MASTER_ACK_HIGH;
                end
                S_MASTER_ACK_HIGH: begin
                    scl_reg <= 1'b1;
                    if (step == 2'h3) begin
                        bit_cnt <= 3'h7;
                        read_shift <= 8'h0;
                        state <= S_READ_LOW;
                    end else begin
                        state <= S_STOP0;
                    end
                end
                S_STOP0: begin
                    scl_reg <= 1'b0;
                    sda_drive_low <= 1'b1;
                    state <= S_STOP1;
                end
                S_STOP1: begin
                    scl_reg <= 1'b1;
                    sda_drive_low <= 1'b1;
                    state <= S_STOP2;
                end
                S_STOP2: begin
                    scl_reg <= 1'b1;
                    sda_drive_low <= 1'b0;
                    state <= S_IDLE;
                end
                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
