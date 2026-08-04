`timescale 1ns/1ps

/*
 * Companion testbench for all_isa_selfcheck.data.
 *
 * This is intentionally outside filelist_sim.f so the frozen 211-test
 * regression remains unchanged.  Compile it together with
 * merged_extensions_tb.v, which provides the bus-level lm75_bus_model.
 */
module merged_all_isa_selfcheck_tb;

    reg clk;
    reg rst;
    reg[1:0] chip_sel;
    reg uart_debug_pin;
    reg uart_rx_pin;
    wire succ;
    wire uart_tx_pin;
    tri1 io_sda;
    tri1 io_scl;
    wire[3:0] pwm_o;

    integer core_id;
    integer cycles;
    integer errors;
    integer uart_count;
    integer i;
    integer terminal_seen;
    reg[1023:0] mem_path;
    reg[15:0] lm75_word;
    reg[7:0] uart_bytes[0:31];

    wire uart_valid =
        (core_id == 0) ? dut.u_chip.u_lhr_tile.u_uart.tx_data_valid :
        (core_id == 1) ? dut.u_chip.u_ldk_tile.u_uart.tx_data_valid :
        (core_id == 2) ? dut.u_chip.u_sy_tile.u_uart.tx_data_valid :
                         dut.u_chip.u_wje_tile.u_uart.tx_data_valid;
    wire[7:0] uart_data =
        (core_id == 0) ? dut.u_chip.u_lhr_tile.u_uart.tx_data :
        (core_id == 1) ? dut.u_chip.u_ldk_tile.u_uart.tx_data :
        (core_id == 2) ? dut.u_chip.u_sy_tile.u_uart.tx_data :
                         dut.u_chip.u_wje_tile.u_uart.tx_data;
    wire[31:0] current_pc =
        (core_id == 0) ? dut.u_chip.u_lhr_tile.u_core.pc_pc_o :
        (core_id == 1) ? dut.u_chip.u_ldk_tile.u_core.pc_pc_o :
        (core_id == 2) ? dut.u_chip.u_sy_tile.u_core.pc_pc_o :
                         dut.u_chip.u_wje_tile.u_core.pc_pc_o;
    wire[31:0] current_inst =
        (core_id == 0) ? dut.u_chip.u_lhr_tile.u_core.ie_inst_o :
        (core_id == 1) ? dut.u_chip.u_ldk_tile.u_core.ie_inst_o :
        (core_id == 2) ? dut.u_chip.u_sy_tile.u_core.ie_inst_o :
                         dut.u_chip.u_wje_tile.u_core.ie_inst_o;

    wire lm75_done;
    wire[7:0] lm75_errors;
    wire[3:0] lm75_starts;
    wire[3:0] lm75_stops;
    wire lm75_first_ack;
    wire lm75_final_nack;

    tinyriscv_merged_fpga_top dut(
        .clk(clk),
        .rst(rst),
        .chip_sel(chip_sel),
        .succ(succ),
        .uart_debug_pin(uart_debug_pin),
        .uart_tx_pin(uart_tx_pin),
        .uart_rx_pin(uart_rx_pin),
        .io_sda(io_sda),
        .io_scl(io_scl),
        .pwm_o(pwm_o)
    );

    lm75_bus_model u_lm75(
        .enable_i(1'b1),
        .temperature_word_i(lm75_word),
        .scl_i(io_scl),
        .sda_io(io_sda),
        .done_o(lm75_done),
        .protocol_errors_o(lm75_errors),
        .start_count_o(lm75_starts),
        .stop_count_o(lm75_stops),
        .first_read_ack_seen_o(lm75_first_ack),
        .final_read_nack_seen_o(lm75_final_nack)
    );

    always #10 clk = ~clk;

    function automatic [7:0] sid_expected;
        input integer selected_core;
        input integer byte_index;
        reg[79:0] id_string;
        begin
            case (selected_core)
                0: id_string = "2023310936";
                1: id_string = "2025210905";
                2: id_string = "2025210870";
                default: id_string = "2025316191";
            endcase
            sid_expected = id_string[79 - byte_index * 8 -: 8];
        end
    endfunction

    task automatic record_error;
        input[511:0] item;
        begin
            errors = errors + 1;
            $display("ASSERT_FAIL kind=ALL_ISA core=%0d item=%s cycle=%0d pc=%08x inst=%08x",
                     core_id, item, cycles, current_pc, current_inst);
        end
    endtask

    always @ (posedge clk) begin
        if ((rst == 1'b1) && (uart_valid === 1'b1)) begin
            if (uart_count < 32) uart_bytes[uart_count] = uart_data;
            uart_count = uart_count + 1;
        end
    end

    initial begin
        clk = 1'b0;
        rst = 1'b0;
        chip_sel = 2'd0;
        uart_debug_pin = 1'b0;
        uart_rx_pin = 1'b1;
        errors = 0;
        uart_count = 0;
        terminal_seen = 0;
        lm75_word = 16'h1900;
        for (i = 0; i < 32; i = i + 1) uart_bytes[i] = 8'h00;

        if (!$value$plusargs("CORE=%d", core_id)) begin
            $display("TEST_FAIL kind=ALL_ISA reason=missing_CORE_plusarg");
            $finish;
        end
        if (!$value$plusargs("MEM=%s", mem_path)) begin
            $display("TEST_FAIL kind=ALL_ISA reason=missing_MEM_plusarg");
            $finish;
        end
        if (!$value$plusargs("LM75_WORD=%h", lm75_word)) lm75_word = 16'h1900;
        if ((core_id < 0) || (core_id > 3)) begin
            $display("TEST_FAIL kind=ALL_ISA reason=invalid_CORE core=%0d", core_id);
            $finish;
        end

        chip_sel = core_id[1:0];
        for (i = 0; i < 256; i = i + 1) begin
            dut.u_bridge_bank.u_shared_memory.rom_mem[i] = 32'h00000013;
        end
        $readmemh(mem_path, dut.u_bridge_bank.u_shared_memory.rom_mem);

        repeat (5) @(posedge clk);
        rst <= 1'b1;

        for (cycles = 0; cycles < 800000; cycles = cycles + 1) begin
            @(posedge clk);
            if ((dut.u_chip.u_shared_regs.regs[26] === 32'h00000001) &&
                (terminal_seen == 0)) begin
                terminal_seen = 1;
                // The firmware polls the UART before its terminal flag; keep
                // a smaller final observation window for the monitor itself.
                repeat (20000) @(posedge clk);

                if (dut.u_chip.u_shared_regs.regs[27] !== 32'h00000001)
                    record_error("x27_success_flag");
                if (dut.u_chip.u_shared_regs.regs[25] !== 32'h00000000)
                    record_error("x25_failure_code_nonzero");
                if (succ !== 1'b0) record_error("active_low_succ_output");

                if (uart_count != 11) begin
                    errors = errors + 1;
                    $display("ASSERT_FAIL kind=ALL_ISA core=%0d item=uart_count got=%0d expected=11 failure_code=%0d",
                             core_id, uart_count,
                             dut.u_chip.u_shared_regs.regs[25]);
                end
                for (i = 0; i < 10; i = i + 1) begin
                    if (uart_bytes[i] !== sid_expected(core_id, i)) begin
                        errors = errors + 1;
                        $display("ASSERT_FAIL kind=ALL_ISA core=%0d item=sid_byte index=%0d got=%02x expected=%02x",
                                 core_id, i, uart_bytes[i], sid_expected(core_id, i));
                    end
                end
                if (uart_bytes[10] !== 8'hA5) begin
                    errors = errors + 1;
                    $display("ASSERT_FAIL kind=ALL_ISA core=%0d item=if_marker got=%02x expected=a5",
                             core_id, uart_bytes[10]);
                end

                if (lm75_done !== 1'b1) record_error("lm75_transaction_not_done");
                if (dut.u_chip.u_shared_regs.regs[14] !== {24'h0, lm75_word[14:7]})
                    record_error("rT_result_x14");
                if ((lm75_errors != 0) || (lm75_starts != 2) ||
                    (lm75_stops != 1) || !lm75_first_ack || !lm75_final_nack) begin
                    errors = errors + 1;
                    $display("ASSERT_FAIL kind=ALL_ISA core=%0d item=i2c_protocol errors=%0d starts=%0d stops=%0d first_ack=%b final_nack=%b",
                             core_id, lm75_errors, lm75_starts, lm75_stops,
                             lm75_first_ack, lm75_final_nack);
                end

                if (errors == 0) begin
                    $display("TEST_PASS kind=ALL_ISA core=%0d uart_bytes=%0d lm75=%04x starts=%0d stops=%0d cycles=%0d",
                             core_id, uart_count, lm75_word,
                             lm75_starts, lm75_stops, cycles);
                end else begin
                    $display("TEST_FAIL kind=ALL_ISA core=%0d errors=%0d failure_code=%0d x26=%08x x27=%08x uart_bytes=%0d pc=%08x inst=%08x",
                             core_id, errors,
                             dut.u_chip.u_shared_regs.regs[25],
                             dut.u_chip.u_shared_regs.regs[26],
                             dut.u_chip.u_shared_regs.regs[27],
                             uart_count, current_pc, current_inst);
                end
                $finish;
            end
        end

        $display("TEST_FAIL kind=ALL_ISA core=%0d reason=timeout failure_code=%0d x26=%08x x27=%08x uart_bytes=%0d lm75_done=%b pc=%08x inst=%08x",
                 core_id, dut.u_chip.u_shared_regs.regs[25],
                 dut.u_chip.u_shared_regs.regs[26],
                 dut.u_chip.u_shared_regs.regs[27], uart_count,
                 lm75_done, current_pc, current_inst);
        $finish;
    end

endmodule
