`include "../core/defines.v"

module lhr_pwm(
    input wire clk,
    input wire rst,
    input wire we_i,
    input wire[31:0] addr_i,
    input wire[31:0] data_i,
    output reg[31:0] data_o,
    output wire[3:0] pwm_o
    );

    reg[31:0] period[0:3];
    reg[31:0] high_time[0:3];
    reg[31:0] counter[0:3];
    reg[3:0] enable;

    integer i;

    assign pwm_o[0] = enable[0] && (period[0] != 32'h0) && (counter[0] < high_time[0]);
    assign pwm_o[1] = enable[1] && (period[1] != 32'h0) && (counter[1] < high_time[1]);
    assign pwm_o[2] = enable[2] && (period[2] != 32'h0) && (counter[2] < high_time[2]);
    assign pwm_o[3] = enable[3] && (period[3] != 32'h0) && (counter[3] < high_time[3]);

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            enable <= 4'h0;
            for (i = 0; i < 4; i = i + 1) begin
                period[i] <= 32'h0;
                high_time[i] <= 32'h0;
                counter[i] <= 32'h0;
            end
        end else begin
            if (we_i == `WriteEnable) begin
                case (addr_i[23:16])
                    8'h00: period[0] <= data_i;
                    8'h01: period[1] <= data_i;
                    8'h02: period[2] <= data_i;
                    8'h03: period[3] <= data_i;
                    8'h04: enable <= data_i[3:0];
                    8'h10: high_time[0] <= data_i;
                    8'h11: high_time[1] <= data_i;
                    8'h12: high_time[2] <= data_i;
                    8'h13: high_time[3] <= data_i;
                    default: begin
                    end
                endcase
            end

            for (i = 0; i < 4; i = i + 1) begin
                if (enable[i] == 1'b0 || period[i] == 32'h0) begin
                    counter[i] <= 32'h0;
                end else if (counter[i] >= period[i] - 1'b1) begin
                    counter[i] <= 32'h0;
                end else begin
                    counter[i] <= counter[i] + 1'b1;
                end
            end
        end
    end

    always @ (*) begin
        if (rst == `RstEnable) begin
            data_o = `ZeroWord;
        end else begin
            case (addr_i[23:16])
                8'h00: data_o = period[0];
                8'h01: data_o = period[1];
                8'h02: data_o = period[2];
                8'h03: data_o = period[3];
                8'h04: data_o = {28'h0, enable};
                8'h10: data_o = high_time[0];
                8'h11: data_o = high_time[1];
                8'h12: data_o = high_time[2];
                8'h13: data_o = high_time[3];
                default: data_o = `ZeroWord;
            endcase
        end
    end

endmodule
