/*
 * Copyright 2020 Blue Liang, liangkangnan@163.com
 * Licensed under the Apache License, Version 2.0.
 */

// Pipeline register with independent flush and hold controls.
module lhr_gen_pipe_stall_dff #(
    parameter DW = 32
    )(
    input wire clk,
    input wire rst,
    input wire flush_en,
    input wire hold_en,
    input wire[DW-1:0] def_val,
    input wire[DW-1:0] din,
    output wire[DW-1:0] qout
    );

    reg[DW-1:0] qout_r;

    always @ (posedge clk) begin
        if (!rst || flush_en) begin
            qout_r <= def_val;
        end else if (!hold_en) begin
            qout_r <= din;
        end
    end

    assign qout = qout_r;

endmodule
