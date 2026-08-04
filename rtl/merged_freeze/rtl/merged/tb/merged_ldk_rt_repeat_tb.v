`timescale 1ns/1ps

/* Repeating LM75 model used only by the targeted LDK reliability check. */
module lm75_repeat_bus_model #(
    parameter integer TRANSACTIONS = 8
    )(
    input wire[15:0] temperature_word_i,
    input wire[3:0] nack_first_addr_attempts_i,
    input wire scl_i,
    inout wire sda_io,
    output reg[15:0] protocol_errors_o,
    output reg[31:0] start_count_o,
    output reg[31:0] stop_count_o,
    output reg[31:0] address_attempt_count_o,
    output reg[31:0] successful_read_count_o,
    output reg[31:0] injected_nack_count_o,
    output reg[63:0] minimum_bus_free_time_o
    );

    reg sda_drive_low;
    reg[7:0] sampled_byte;
    integer bit_index;
    reg have_stop_time;
    time last_stop_time;
    time bus_free_time;

    assign sda_io = sda_drive_low ? 1'b0 : 1'bz;

    task automatic wait_start;
        begin
            @(negedge sda_io);
            #1;
            if (scl_i !== 1'b1)
                protocol_errors_o = protocol_errors_o + 1'b1;
            if (have_stop_time) begin
                bus_free_time = $time - last_stop_time;
                if (bus_free_time < minimum_bus_free_time_o)
                    minimum_bus_free_time_o = bus_free_time;
            end
            start_count_o = start_count_o + 1;
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
            if (sda_io !== 1'b0)
                protocol_errors_o = protocol_errors_o + 1'b1;
            @(negedge scl_i);
            sda_drive_low = 1'b0;
        end
    endtask

    task automatic slave_nack;
        begin
            @(negedge scl_i);
            sda_drive_low = 1'b0;
            @(posedge scl_i);
            #1;
            if (sda_io !== 1'b1)
                protocol_errors_o = protocol_errors_o + 1'b1;
            @(negedge scl_i);
        end
    endtask

    task automatic wait_stop;
        begin
            @(posedge sda_io);
            #1;
            if (scl_i !== 1'b1)
                protocol_errors_o = protocol_errors_o + 1'b1;
            stop_count_o = stop_count_o + 1;
            last_stop_time = $time;
            have_stop_time = 1'b1;
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
                if (sda_io !== 1'b0)
                    protocol_errors_o = protocol_errors_o + 1'b1;
            end else begin
                if (sda_io !== 1'b1)
                    protocol_errors_o = protocol_errors_o + 1'b1;
            end
            @(negedge scl_i);
        end
    endtask

    initial begin
        sda_drive_low = 1'b0;
        sampled_byte = 8'h00;
        protocol_errors_o = 16'h0000;
        start_count_o = 0;
        stop_count_o = 0;
        address_attempt_count_o = 0;
        successful_read_count_o = 0;
        injected_nack_count_o = 0;
        minimum_bus_free_time_o = {64{1'b1}};
        have_stop_time = 1'b0;
        last_stop_time = 0;
        bus_free_time = 0;

        forever begin
            wait_start();
            read_master_byte(sampled_byte);
            if (sampled_byte !== 8'h90)
                protocol_errors_o = protocol_errors_o + 1'b1;
            address_attempt_count_o = address_attempt_count_o + 1;

            if (injected_nack_count_o < nack_first_addr_attempts_i) begin
                slave_nack();
                injected_nack_count_o = injected_nack_count_o + 1;
                wait_stop();
            end else begin
                slave_ack();

                read_master_byte(sampled_byte);
                if (sampled_byte !== 8'h00)
                    protocol_errors_o = protocol_errors_o + 1'b1;
                slave_ack();

                wait_start();
                read_master_byte(sampled_byte);
                if (sampled_byte !== 8'h91)
                    protocol_errors_o = protocol_errors_o + 1'b1;
                slave_ack();

                send_slave_byte(temperature_word_i[15:8], 1'b1);
                send_slave_byte(temperature_word_i[7:0], 1'b0);

                wait_stop();
                successful_read_count_o = successful_read_count_o + 1;
            end
        end
    end

endmodule

/* Exact-image check: eight LDK rT transactions must each emit 0x32. */
module merged_ldk_rt_repeat_tb;

    localparam[15:0] LM75_WORD = 16'h1900;

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

    integer cycles;
    integer uart_count;
    integer errors;
    integer finish_wait;
    integer i;
    reg[1023:0] mem_path;
    reg[255:0] scenario;
    reg[1023:0] vcd_path;
    reg[3:0] nack_first_addr_attempts;
    reg[7:0] expected_first_uart;
    integer expected_starts;
    integer expected_stops;
    integer expected_address_attempts;
    integer expected_successful_reads;
    integer expected_nacks;
    integer expected_cpu_acks;
    integer minimum_required_bus_free_time;
    integer i2c_ack_count;
    reg[7:0] uart_values[0:15];
    wire[15:0] model_errors;
    wire[31:0] model_starts;
    wire[31:0] model_stops;
    wire[31:0] model_address_attempts;
    wire[31:0] model_successful_reads;
    wire[31:0] model_injected_nacks;
    wire[63:0] model_minimum_bus_free_time;

    tinyriscv_merged_fpga_top dut(
        .clk(clk), .rst(rst), .chip_sel(chip_sel), .succ(succ),
        .uart_debug_pin(uart_debug_pin), .uart_tx_pin(uart_tx_pin),
        .uart_rx_pin(uart_rx_pin), .io_sda(io_sda), .io_scl(io_scl),
        .pwm_o(pwm_o)
    );

    lm75_repeat_bus_model #(.TRANSACTIONS(8)) u_lm75(
        .temperature_word_i(LM75_WORD),
        .nack_first_addr_attempts_i(nack_first_addr_attempts),
        .scl_i(io_scl), .sda_io(io_sda),
        .protocol_errors_o(model_errors),
        .start_count_o(model_starts), .stop_count_o(model_stops),
        .address_attempt_count_o(model_address_attempts),
        .successful_read_count_o(model_successful_reads),
        .injected_nack_count_o(model_injected_nacks),
        .minimum_bus_free_time_o(model_minimum_bus_free_time)
    );

    always #10 clk = ~clk;

    initial begin
        clk = 1'b0;
        rst = 1'b0;
        chip_sel = 2'd1;
        uart_debug_pin = 1'b0;
        uart_rx_pin = 1'b1;
        uart_count = 0;
        errors = 0;
        finish_wait = -1;
        i2c_ack_count = 0;
        scenario = "clean";
        nack_first_addr_attempts = 0;
        expected_first_uart = 8'h32;
        expected_starts = 16;
        expected_stops = 8;
        expected_address_attempts = 8;
        expected_successful_reads = 8;
        expected_nacks = 0;
        expected_cpu_acks = 8;
        minimum_required_bus_free_time = 0;
        for (i = 0; i < 16; i = i + 1)
            uart_values[i] = 8'h00;

        if ($value$plusargs("SCENARIO=%s", scenario)) begin
            if (scenario == "clean") begin
                nack_first_addr_attempts = 0;
            end else if (scenario == "legacy_single_nack") begin
                nack_first_addr_attempts = 1;
                expected_first_uart = 8'h00;
                expected_starts = 15;
                expected_stops = 8;
                expected_address_attempts = 8;
                expected_successful_reads = 7;
                expected_nacks = 1;
            end else if (scenario == "retry_single_nack") begin
                nack_first_addr_attempts = 1;
                expected_starts = 17;
                expected_stops = 9;
                expected_address_attempts = 9;
                expected_successful_reads = 8;
                expected_nacks = 1;
                minimum_required_bus_free_time = 80;
            end else if (scenario == "retry_exhausted") begin
                nack_first_addr_attempts = 3;
                expected_first_uart = 8'h00;
                expected_starts = 17;
                expected_stops = 10;
                expected_address_attempts = 10;
                expected_successful_reads = 7;
                expected_nacks = 3;
                minimum_required_bus_free_time = 80;
            end else begin
                $display("TEST_FAIL kind=LDK_RT_REPEAT reason=unknown_scenario scenario=%0s",
                         scenario);
                $finish;
            end
        end

        if ($value$plusargs("VCD=%s", vcd_path)) begin
            $dumpfile(vcd_path);
            $dumpvars(0, merged_ldk_rt_repeat_tb);
        end

        if (!$value$plusargs("MEM=%s", mem_path)) begin
            $display("TEST_FAIL kind=LDK_RT_REPEAT reason=missing_MEM_plusarg");
            $finish;
        end

        for (i = 0; i < 256; i = i + 1)
            dut.u_bridge_bank.u_shared_memory.rom_mem[i] = 32'h0000_0013;
        $readmemh(mem_path, dut.u_bridge_bank.u_shared_memory.rom_mem);

        repeat (5) @(posedge clk);
        rst <= 1'b1;

        for (cycles = 0; cycles < 2000000; cycles = cycles + 1) begin
            @(posedge clk);

            if (dut.u_chip.u_ldk_tile.i2c_ack === 1'b1)
                i2c_ack_count = i2c_ack_count + 1;

            if (dut.u_chip.u_ldk_tile.u_uart.tx_data_valid === 1'b1) begin
                if (uart_count < 16)
                    uart_values[uart_count] =
                        dut.u_chip.u_ldk_tile.u_uart.tx_data;
                if (dut.u_chip.u_ldk_tile.u_uart.tx_data !==
                    ((uart_count == 0) ? expected_first_uart : 8'h32)) begin
                    errors = errors + 1;
                    $display("ASSERT_FAIL kind=LDK_RT_REPEAT index=%0d got=%02x expected=%02x",
                             uart_count,
                             dut.u_chip.u_ldk_tile.u_uart.tx_data,
                             (uart_count == 0) ? expected_first_uart : 8'h32);
                end
                uart_count = uart_count + 1;
            end

            if ((dut.u_chip.u_shared_regs.regs[26] === 32'h1) &&
                (finish_wait == -1)) begin
                finish_wait = 20000;
            end else if (finish_wait > 0) begin
                finish_wait = finish_wait - 1;
            end else if (finish_wait == 0) begin
                if ((errors == 0) && (uart_count == 8) &&
                    (model_errors == 0) &&
                    (model_starts == expected_starts) &&
                    (model_stops == expected_stops) &&
                    (model_address_attempts == expected_address_attempts) &&
                    (model_successful_reads == expected_successful_reads) &&
                    (model_injected_nacks == expected_nacks) &&
                    (i2c_ack_count == expected_cpu_acks) &&
                    ((minimum_required_bus_free_time == 0) ||
                     (model_minimum_bus_free_time >=
                      minimum_required_bus_free_time)) &&
                    (dut.u_chip.u_shared_regs.regs[27] === 32'h1) &&
                    (succ === 1'b0)) begin
                    $display("TEST_PASS kind=LDK_RT_REPEAT scenario=%0s uart=%02x_%02x_%02x_%02x_%02x_%02x_%02x_%02x starts=%0d stops=%0d address_attempts=%0d successful_reads=%0d injected_nacks=%0d cpu_acks=%0d min_bus_free_ns=%0d",
                             scenario,
                             uart_values[0], uart_values[1], uart_values[2],
                             uart_values[3], uart_values[4], uart_values[5],
                             uart_values[6], uart_values[7],
                             model_starts, model_stops,
                             model_address_attempts, model_successful_reads,
                             model_injected_nacks, i2c_ack_count,
                             model_minimum_bus_free_time);
                end else begin
                    $display("TEST_FAIL kind=LDK_RT_REPEAT scenario=%0s bytes=%0d errors=%0d model_errors=%0d starts=%0d/%0d stops=%0d/%0d address_attempts=%0d/%0d successful_reads=%0d/%0d injected_nacks=%0d/%0d cpu_acks=%0d/%0d min_bus_free_ns=%0d/%0d x26=%08x x27=%08x succ=%b",
                             scenario,
                             uart_count, errors, model_errors, model_starts,
                             expected_starts, model_stops, expected_stops,
                             model_address_attempts, expected_address_attempts,
                             model_successful_reads, expected_successful_reads,
                             model_injected_nacks, expected_nacks,
                             i2c_ack_count, expected_cpu_acks,
                             model_minimum_bus_free_time,
                             minimum_required_bus_free_time,
                             dut.u_chip.u_shared_regs.regs[26],
                             dut.u_chip.u_shared_regs.regs[27], succ);
                end
                $finish;
            end
        end

        $display("TEST_FAIL kind=LDK_RT_REPEAT reason=timeout bytes=%0d state=%0d x20=%08x x26=%08x x27=%08x",
                 uart_count, dut.u_chip.u_ldk_tile.u_i2c.iic_cs,
                 dut.u_chip.u_shared_regs.regs[20],
                 dut.u_chip.u_shared_regs.regs[26],
                 dut.u_chip.u_shared_regs.regs[27]);
        $finish;
    end

endmodule
