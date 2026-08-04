/*
 * Shared integer register file for the four-core TinyRISC-V integration.
 * Reset is active low, matching all four frozen cores.
 */

// One physical register file is connected to the core selected by chip_sel.
module shared_regs(
    input wire clk,
    input wire rst,
    input wire we_i,
    input wire[4:0] waddr_i,
    input wire[31:0] wdata_i,
    input wire[4:0] raddr1_i,
    output reg[31:0] rdata1_o,
    input wire[4:0] raddr2_i,
    output reg[31:0] rdata2_o,
    output wire over_o,
    output wire succ_o
    );

    reg[31:0] regs[0:31];
    integer i;

    // The course tests write x26=1 when finished and x27=1 when successful.
    assign over_o = (rst == 1'b0) ? 1'b1 : ~regs[26][0];
    assign succ_o = (rst == 1'b0) ? 1'b1 : ~regs[27][0];

    always @ (posedge clk) begin
        if (rst == 1'b0) begin
            for (i = 0; i < 32; i = i + 1) begin
                regs[i] <= 32'h0000_0000;
            end
        end else if ((we_i == 1'b1) && (waddr_i != 5'h00)) begin
            regs[waddr_i] <= wdata_i;
        end
    end

    always @ (*) begin
        if (raddr1_i == 5'h00) begin
            rdata1_o = 32'h0000_0000;
        end else if ((we_i == 1'b1) && (raddr1_i == waddr_i)) begin
            rdata1_o = wdata_i;
        end else begin
            rdata1_o = regs[raddr1_i];
        end
    end

    always @ (*) begin
        if (raddr2_i == 5'h00) begin
            rdata2_o = 32'h0000_0000;
        end else if ((we_i == 1'b1) && (raddr2_i == waddr_i)) begin
            rdata2_o = wdata_i;
        end else begin
            rdata2_o = regs[raddr2_i];
        end
    end

endmodule
