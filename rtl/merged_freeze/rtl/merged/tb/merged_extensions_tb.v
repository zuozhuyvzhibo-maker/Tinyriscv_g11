`timescale 1ns/1ps

`include "tb/vcs_fsdb_dump.vh"

/* Bus-level LM75 model. It observes only SCL/SDA and never peeks at a core. */
module lm75_bus_model(
    input wire enable_i,
    input wire[15:0] temperature_word_i,
    input wire scl_i,
    inout wire sda_io,
    output reg done_o,
    output reg[7:0] protocol_errors_o,
    output reg[3:0] start_count_o,
    output reg[3:0] stop_count_o,
    output reg first_read_ack_seen_o,
    output reg final_read_nack_seen_o
    );

    reg sda_drive_low;
    reg[7:0] sampled_byte;
    integer bit_index;

    assign sda_io = sda_drive_low ? 1'b0 : 1'bz;

    task automatic wait_start;
        begin
            @(negedge sda_io);
            #1;
            if (scl_i !== 1'b1) protocol_errors_o = protocol_errors_o + 1'b1;
            start_count_o = start_count_o + 1'b1;
        end
    endtask

    task automatic read_master_byte;
        output[7:0] value;
        begin
            value = 8'h00;
            for (bit_index = 7; bit_index >= 0; bit_index = bit_index - 1) begin
                @(posedge scl_i);
                #1;
                value[bit_index] = sda_io;
            end
        end
    endtask

    task automatic slave_ack;
        begin
            @(negedge scl_i);
            sda_drive_low = 1'b1;
            @(posedge scl_i);
            #1;
            if (sda_io !== 1'b0) protocol_errors_o = protocol_errors_o + 1'b1;
            @(negedge scl_i);
            sda_drive_low = 1'b0;
        end
    endtask

    task automatic send_slave_byte;
        input[7:0] value;
        input expected_master_ack_low;
        begin
            sda_drive_low = (value[7] == 1'b0);
            for (bit_index = 7; bit_index >= 0; bit_index = bit_index - 1) begin
                @(posedge scl_i);
                if (bit_index != 0) begin
                    @(negedge scl_i);
                    sda_drive_low = (value[bit_index - 1] == 1'b0);
                end
            end
            @(negedge scl_i);
            sda_drive_low = 1'b0;
            @(posedge scl_i);
            #1;
            if (expected_master_ack_low) begin
                if (sda_io === 1'b0) first_read_ack_seen_o = 1'b1;
                else protocol_errors_o = protocol_errors_o + 1'b1;
            end else begin
                if (sda_io === 1'b1) final_read_nack_seen_o = 1'b1;
                else protocol_errors_o = protocol_errors_o + 1'b1;
            end
            @(negedge scl_i);
        end
    endtask

    initial begin
        sda_drive_low = 1'b0;
        done_o = 1'b0;
        protocol_errors_o = 8'h00;
        start_count_o = 4'h0;
        stop_count_o = 4'h0;
        first_read_ack_seen_o = 1'b0;
        final_read_nack_seen_o = 1'b0;
        sampled_byte = 8'h00;

        wait (enable_i == 1'b1);
        wait_start();
        read_master_byte(sampled_byte);
        if (sampled_byte !== 8'h90) protocol_errors_o = protocol_errors_o + 1'b1;
        slave_ack();

        read_master_byte(sampled_byte);
        if (sampled_byte !== 8'h00) protocol_errors_o = protocol_errors_o + 1'b1;
        slave_ack();

        wait_start();
        read_master_byte(sampled_byte);
        if (sampled_byte !== 8'h91) protocol_errors_o = protocol_errors_o + 1'b1;
        slave_ack();

        send_slave_byte(temperature_word_i[15:8], 1'b1);
        send_slave_byte(temperature_word_i[7:0], 1'b0);

        @(posedge sda_io);
        #1;
        if (scl_i !== 1'b1) protocol_errors_o = protocol_errors_o + 1'b1;
        stop_count_o = stop_count_o + 1'b1;
        done_o = 1'b1;
    end

endmodule

/* Four-core sID, IF, and rT directed regression. */
module merged_extensions_tb;

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
    integer program_words;
    integer cycles;
    integer errors;
    integer uart_count;
    integer i;
    integer quiet_start_count;
    reg[255:0] test_name;
    reg[1023:0] vcd_path;
    reg[15:0] lm75_word;
    reg lm75_enable;

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
        .clk(clk), .rst(rst), .chip_sel(chip_sel), .succ(succ),
        .uart_debug_pin(uart_debug_pin), .uart_tx_pin(uart_tx_pin),
        .uart_rx_pin(uart_rx_pin), .io_sda(io_sda), .io_scl(io_scl),
        .pwm_o(pwm_o)
    );

    lm75_bus_model u_lm75(
        .enable_i(lm75_enable),
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

    function automatic [31:0] enc_i;
        input signed[31:0] imm;
        input[4:0] rs1;
        input[2:0] funct3;
        input[4:0] rd;
        input[6:0] opcode;
        begin
            enc_i = {imm[11:0], rs1, funct3, rd, opcode};
        end
    endfunction

    function automatic [31:0] enc_u;
        input[19:0] upper;
        input[4:0] rd;
        begin
            enc_u = {upper, rd, 7'b0110111};
        end
    endfunction

    function automatic [31:0] enc_j;
        input signed[31:0] imm;
        input[4:0] rd;
        begin
            enc_j = {imm[20], imm[10:1], imm[11], imm[19:12],
                     rd, 7'b1101111};
        end
    endfunction

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

    function automatic [7:0] if_expected;
        input integer byte_index;
        begin
            case (byte_index)
                0: if_expected = 8'h00;
                1: if_expected = 8'hff;
                default: if_expected = 8'h01;
            endcase
        end
    endfunction

    task automatic emit;
        input[31:0] instruction;
        begin
            dut.u_bridge_bank.u_shared_memory.rom_mem[program_words] = instruction;
            program_words = program_words + 1;
        end
    endtask

    task automatic emit_nops;
        input integer count;
        begin
            for (i = 0; i < count; i = i + 1) emit(32'h0000_0013);
        end
    endtask

    task automatic emit_finish;
        begin
            emit(enc_i(1, 5'd0, 3'b000, 5'd27, 7'b0010011));
            emit(enc_i(1, 5'd0, 3'b000, 5'd26, 7'b0010011));
            emit(enc_j(0, 5'd0));
        end
    endtask

    task automatic build_sid;
        begin
            emit(enc_u(20'h30000, 5'd20));
            emit(enc_i(1, 5'd0, 3'b000, 5'd21, 7'b0010011));
            emit({7'h00, 5'd21, 5'd20, 3'b010, 5'h00, 7'b0100011});
            emit(enc_i(0, 5'd0, 3'b000, 5'd0, 7'b0101111));
            emit_finish();
        end
    endtask

    task automatic build_if;
        begin
            emit(enc_u(20'h30000, 5'd20));
            emit(enc_i(1, 5'd0, 3'b000, 5'd21, 7'b0010011));
            emit({7'h00, 5'd21, 5'd20, 3'b010, 5'h00, 7'b0100011});
            emit(enc_u(20'h80000, 5'd31));
            emit(enc_u(20'h80000, 5'd1));
            emit(enc_i(-1, 5'd1, 3'b000, 5'd1, 7'b0010011));
            emit(enc_i(0, 5'd1, 3'b010, 5'd10, 7'b0101111)); // <, no UART
            emit(enc_u(20'h80000, 5'd2));
            emit(enc_i(0, 5'd2, 3'b010, 5'd11, 7'b0101111)); // =, UART 00
            emit_nops(16);
            emit(enc_i(-1, 5'd0, 3'b000, 5'd3, 7'b0010011));
            emit(enc_i(0, 5'd3, 3'b010, 5'd12, 7'b0101111)); // >, UART ff
            emit_nops(16);
            emit(enc_u(20'h80000, 5'd4));
            emit(enc_i(1, 5'd4, 3'b000, 5'd4, 7'b0010011));
            emit(enc_i(0, 5'd4, 3'b010, 5'd15, 7'b0101111)); // high unsigned, UART 01
            emit_nops(16);
            emit(enc_i(10, 5'd0, 3'b000, 5'd5, 7'b0010011));
            emit(enc_i(7, 5'd5, 3'b010, 5'd13, 7'b0101111));
            emit(enc_i(-3, 5'd5, 3'b010, 5'd14, 7'b0101111));
            emit_finish();
        end
    endtask

    task automatic build_rt;
        begin
            emit(enc_i(0, 5'd0, 3'b001, 5'd14, 7'b0101111));
            emit_finish();
        end
    endtask

    task automatic check_reg;
        input integer index;
        input[31:0] expected;
        input[255:0] label_name;
        begin
            if (dut.u_chip.u_shared_regs.regs[index] !== expected) begin
                errors = errors + 1;
                $display("ASSERT_FAIL test=%s core=%0d item=%s reg=x%0d got=%08x expected=%08x cycle=%0d pc=%08x inst=%08x",
                         test_name, core_id, label_name, index,
                         dut.u_chip.u_shared_regs.regs[index], expected,
                         cycles, current_pc, current_inst);
            end
        end
    endtask

    always @ (posedge clk) begin
        if ((rst == 1'b1) && (uart_valid === 1'b1)) begin
            if (test_name == "sid") begin
                if ((uart_count >= 10) ||
                    (uart_data !== sid_expected(core_id, uart_count))) begin
                    errors = errors + 1;
                    $display("ASSERT_FAIL test=sid core=%0d item=uart_byte index=%0d got=%02x expected=%02x cycle=%0d pc=%08x",
                             core_id, uart_count, uart_data,
                             (uart_count < 10) ? sid_expected(core_id, uart_count) : 8'hxx,
                             cycles, current_pc);
                end
            end else if (test_name == "if") begin
                if ((uart_count >= 3) ||
                    (uart_data !== if_expected(uart_count))) begin
                    errors = errors + 1;
                    $display("ASSERT_FAIL test=if core=%0d item=uart_byte index=%0d got=%02x cycle=%0d pc=%08x",
                             core_id, uart_count, uart_data, cycles, current_pc);
                end
            end
            uart_count = uart_count + 1;
        end
    end

    initial begin
        clk = 1'b0;
        rst = 1'b0;
        chip_sel = 2'd0;
        uart_debug_pin = 1'b0;
        uart_rx_pin = 1'b1;
        program_words = 0;
        errors = 0;
        uart_count = 0;
        quiet_start_count = 0;
        lm75_word = 16'h1900;
        lm75_enable = 1'b0;
        test_name = "sid";

        if (!$value$plusargs("CORE=%d", core_id)) begin
            $display("TEST_FAIL reason=missing_CORE_plusarg");
            $finish;
        end
        if (!$value$plusargs("TEST=%s", test_name)) begin
            $display("TEST_FAIL reason=missing_TEST_plusarg");
            $finish;
        end
        if (!$value$plusargs("LM75_WORD=%h", lm75_word)) lm75_word = 16'h1900;
        if ((core_id < 0) || (core_id > 3)) begin
            $display("TEST_FAIL test=%s reason=invalid_CORE core=%0d", test_name, core_id);
            $finish;
        end
        if ($value$plusargs("VCD=%s", vcd_path)) begin
            `MERGED_DUMPFILE(vcd_path);
            `MERGED_DUMPVARS(dut);
            `MERGED_DUMPVARS(u_lm75);
            `MERGED_DUMPVARS(dut.u_chip.u_shared_regs.regs[14]);
            `MERGED_DUMPVARS(dut.u_chip.u_shared_regs.regs[26]);
            `MERGED_DUMPVARS(dut.u_chip.u_shared_regs.regs[27]);
        end

        chip_sel = core_id[1:0];
        lm75_enable = (test_name == "rt");
        for (i = 0; i < 256; i = i + 1) begin
            dut.u_bridge_bank.u_shared_memory.rom_mem[i] = 32'h0000_0013;
        end
        if (test_name == "sid") build_sid();
        else if (test_name == "if") build_if();
        else if (test_name == "rt") build_rt();
        else begin
            $display("TEST_FAIL test=%s core=%0d reason=unknown_TEST", test_name, core_id);
            $finish;
        end

        repeat (5) @(posedge clk);
        rst <= 1'b1;

        for (cycles = 0; cycles < 500000; cycles = cycles + 1) begin
            @(posedge clk);
            if ((dut.u_chip.u_shared_regs.regs[26] === 32'h1) &&
                ((test_name != "sid") || (uart_count >= 10)) &&
                ((test_name != "if") || (uart_count >= 3)) &&
                ((test_name != "rt") || (lm75_done === 1'b1))) begin

                if (test_name == "sid") begin
                    quiet_start_count = uart_count;
                    repeat (20000) @(posedge clk);
                    if ((uart_count != 10) || (uart_count != quiet_start_count)) begin
                        errors = errors + 1;
                        $display("ASSERT_FAIL test=sid core=%0d item=single_trigger bytes=%0d quiet_start=%0d",
                                 core_id, uart_count, quiet_start_count);
                    end
                end else if (test_name == "if") begin
                    repeat (2000) @(posedge clk);
                    check_reg(10, 32'h7fffffff, "if_less_passthrough");
                    check_reg(11, 32'h00000000, "if_equal_fire");
                    check_reg(12, 32'h00000000, "if_greater_fire");
                    check_reg(15, 32'h00000000, "if_unsigned_high_fire");
                    check_reg(13, 32'h00000011, "if_positive_immediate");
                    check_reg(14, 32'h00000007, "if_negative_immediate");
                    if (uart_count != 3) begin
                        errors = errors + 1;
                        $display("ASSERT_FAIL test=if core=%0d item=fire_only_uart_count got=%0d expected=3",
                                 core_id, uart_count);
                    end
                end else begin
                    check_reg(14, {24'h0, lm75_word[14:7]}, "rT_LM75_bits_14_7");
                    if ((lm75_errors != 0) || (lm75_starts != 2) ||
                        (lm75_stops != 1) || !lm75_first_ack || !lm75_final_nack) begin
                        errors = errors + 1;
                        $display("ASSERT_FAIL test=rt core=%0d item=i2c_protocol errors=%0d starts=%0d stops=%0d first_ack=%b final_nack=%b",
                                 core_id, lm75_errors, lm75_starts, lm75_stops,
                                 lm75_first_ack, lm75_final_nack);
                    end
                end

                check_reg(26, 32'h1, "completion_x26");
                check_reg(27, 32'h1, "success_x27");
                if (succ !== 1'b0) errors = errors + 1;
                if (errors == 0) begin
                    $display("TEST_PASS test=%s core=%0d uart_bytes=%0d lm75=%04x starts=%0d stops=%0d cycles=%0d pc=%08x",
                             test_name, core_id, uart_count, lm75_word,
                             lm75_starts, lm75_stops, cycles, current_pc);
                end else begin
                    $display("TEST_FAIL test=%s core=%0d errors=%0d uart_bytes=%0d lm75=%04x cycle=%0d pc=%08x inst=%08x",
                             test_name, core_id, errors, uart_count,
                             lm75_word, cycles, current_pc, current_inst);
                end
                $finish;
            end
        end

        $display("TEST_FAIL test=%s core=%0d reason=timeout cycle=%0d x14=%08x x26=%08x x27=%08x uart_bytes=%0d lm75_done=%b starts=%0d stops=%0d pc=%08x inst=%08x",
                 test_name, core_id, cycles,
                 dut.u_chip.u_shared_regs.regs[14],
                 dut.u_chip.u_shared_regs.regs[26],
                 dut.u_chip.u_shared_regs.regs[27], uart_count,
                 lm75_done, lm75_starts, lm75_stops,
                 current_pc, current_inst);
        $finish;
    end

endmodule
