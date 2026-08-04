`timescale 1ns/1ps

/* Physical 8-N-1 transmit/receive loopback for each normal UART. */
module merged_uart_tb;

    reg clk;
    reg rst;
    reg[1:0] core_sel;
    reg we;
    reg[31:0] addr;
    reg[31:0] wdata;
    wire[31:0] lhr_rdata;
    wire[31:0] ldk_rdata;
    wire[31:0] sy_rdata;
    wire[31:0] wje_rdata;
    wire lhr_tx;
    wire ldk_tx;
    wire sy_tx;
    wire wje_tx;
    wire selected_tx = (core_sel == 0) ? lhr_tx :
                       (core_sel == 1) ? ldk_tx :
                       (core_sel == 2) ? sy_tx : wje_tx;
    wire[31:0] selected_rdata = (core_sel == 0) ? lhr_rdata :
                                (core_sel == 1) ? ldk_rdata :
                                (core_sel == 2) ? sy_rdata : wje_rdata;

    integer core_id;
    integer errors;
    integer bit_no;
    reg[7:0] test_byte;

    lhr_uart u_lhr(
        .clk(clk), .rst(rst && (core_sel == 0)), .we_i(we),
        .addr_i(addr), .data_i(wdata), .data_o(lhr_rdata),
        .tx_pin(lhr_tx), .rx_pin(selected_tx)
    );
    ldk_uart u_ldk(
        .clk(clk), .rst(rst && (core_sel == 1)), .we_i(we),
        .addr_i(addr), .data_i(wdata), .data_o(ldk_rdata),
        .tx_pin(ldk_tx), .rx_pin(selected_tx)
    );
    sy_uart u_sy(
        .clk(clk), .rst(rst && (core_sel == 2)), .we_i(we),
        .addr_i(addr), .data_i(wdata), .sid_req_i(1'b0),
        .ifire_req_i(1'b0), .ifire_data_i(8'h00),
        .data_o(sy_rdata), .tx_pin(sy_tx), .rx_pin(selected_tx)
    );
    wje_uart u_wje(
        .clk(clk), .rst(rst && (core_sel == 3)), .we_i(we),
        .addr_i(addr), .data_i(wdata), .sid_start_i(1'b0),
        .if_uart_start_i(1'b0), .if_uart_accept_i(1'b0),
        .if_uart_data_i(8'h00), .data_o(wje_rdata),
        .sid_busy_o(), .if_uart_busy_o(), .if_uart_done_o(),
        .tx_pin(wje_tx), .rx_pin(selected_tx)
    );

    always #10 clk = ~clk;

    task automatic mmio_write;
        input[31:0] write_addr;
        input[31:0] write_value;
        begin
            @(negedge clk);
            addr = write_addr;
            wdata = write_value;
            we = 1'b1;
            @(posedge clk);
            @(negedge clk);
            we = 1'b0;
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = 1'b0;
        core_sel = 2'd0;
        we = 1'b0;
        addr = 32'h0;
        wdata = 32'h0;
        errors = 0;
        test_byte = 8'ha5;

        if (!$value$plusargs("CORE=%d", core_id) ||
            (core_id < 0) || (core_id > 3)) begin
            $display("TEST_FAIL test=uart_loopback reason=invalid_or_missing_CORE");
            $finish;
        end
        core_sel = core_id[1:0];
        repeat (4) @(posedge clk);
        rst = 1'b1;
        repeat (3) @(posedge clk);

        mmio_write(32'h0000_0000, 32'h3); // TX and RX enable
        mmio_write(32'h0000_0004, 32'h0); // clear RX-over/data
        mmio_write(32'h0000_000c, {24'h0, test_byte});

        @(negedge selected_tx);
        repeat (4) @(posedge clk);
        if (selected_tx !== 1'b0) begin
            errors = errors + 1;
            $display("ASSERT_FAIL test=uart_loopback core=%0d item=start_bit got=%b",
                     core_id, selected_tx);
        end
        for (bit_no = 0; bit_no < 8; bit_no = bit_no + 1) begin
            repeat (9) @(posedge clk);
            if (selected_tx !== test_byte[bit_no]) begin
                errors = errors + 1;
                $display("ASSERT_FAIL test=uart_loopback core=%0d item=data_bit bit=%0d got=%b expected=%b",
                         core_id, bit_no, selected_tx, test_byte[bit_no]);
            end
        end
        repeat (9) @(posedge clk);
        if (selected_tx !== 1'b1) begin
            errors = errors + 1;
            $display("ASSERT_FAIL test=uart_loopback core=%0d item=stop_bit got=%b",
                     core_id, selected_tx);
        end

        repeat (20) @(posedge clk);
        addr = 32'h0000_0010;
        #1;
        if (selected_rdata[7:0] !== test_byte) begin
            errors = errors + 1;
            $display("ASSERT_FAIL test=uart_loopback core=%0d item=rx_data got=%02x expected=%02x",
                     core_id, selected_rdata[7:0], test_byte);
        end
        addr = 32'h0000_0004;
        #1;
        if (selected_rdata[1] !== 1'b1) begin
            errors = errors + 1;
            $display("ASSERT_FAIL test=uart_loopback core=%0d item=rx_over status=%08x",
                     core_id, selected_rdata);
        end

        case (core_id)
            0: if (u_lhr.uart_baud !== 32'd8) errors = errors + 1;
            1: if (u_ldk.uart_baud !== 32'd8) errors = errors + 1;
            2: if (u_sy.uart_baud !== 32'd8) errors = errors + 1;
            3: if (u_wje.uart_baud !== 32'd8) errors = errors + 1;
        endcase

        if (errors == 0)
            $display("TEST_PASS test=uart_loopback core=%0d byte=a5 format=8N1 fast_div=8",
                     core_id);
        else
            $display("TEST_FAIL test=uart_loopback core=%0d errors=%0d",
                     core_id, errors);
        $finish;
    end

endmodule
