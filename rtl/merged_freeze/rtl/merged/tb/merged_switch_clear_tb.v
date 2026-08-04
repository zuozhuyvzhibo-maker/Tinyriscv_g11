`timescale 1ns/1ps

`include "tb/vcs_fsdb_dump.vh"

/* Switch/reset cancellation, RAM clear, ROM retention, and downloader abort. */
module merged_switch_clear_tb;

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

    reg[7:0] packet_buf[0:34];
    integer errors;
    integer i;
    integer j;
    integer wait_cycles;
    integer ready_cycles;
    reg[1023:0] vcd_path;

    tinyriscv_merged_fpga_top dut(
        .clk(clk), .rst(rst), .chip_sel(chip_sel), .succ(succ),
        .uart_debug_pin(uart_debug_pin), .uart_tx_pin(uart_tx_pin),
        .uart_rx_pin(uart_rx_pin), .io_sda(io_sda), .io_scl(io_scl),
        .pwm_o(pwm_o)
    );

    always #10 clk = ~clk;

    function automatic [31:0] enc_i;
        input signed[31:0] imm;
        input[4:0] rs1;
        input[4:0] rd;
        begin
            enc_i = {imm[11:0], rs1, 3'b000, rd, 7'b0010011};
        end
    endfunction

    function automatic [31:0] enc_u;
        input[19:0] upper;
        input[4:0] rd;
        begin
            enc_u = {upper, rd, 7'b0110111};
        end
    endfunction

    function automatic [31:0] enc_sw;
        input[4:0] rs2;
        input[4:0] rs1;
        begin
            enc_sw = {7'h00, rs2, rs1, 3'b010, 5'h00, 7'b0100011};
        end
    endfunction

    function automatic [15:0] packet_crc;
        integer b;
        integer k;
        reg[15:0] crc;
        begin
            crc = 16'hffff;
            for (b = 1; b <= 32; b = b + 1) begin
                crc = crc ^ packet_buf[b];
                for (k = 0; k < 8; k = k + 1)
                    crc = crc[0] ? ((crc >> 1) ^ 16'ha001) : (crc >> 1);
            end
            packet_crc = crc;
        end
    endfunction

    task automatic finish_packet;
        reg[15:0] crc;
        begin
            crc = packet_crc();
            packet_buf[33] = crc[7:0];
            packet_buf[34] = crc[15:8];
        end
    endtask

    task automatic uart_send_byte;
        input[7:0] value;
        integer bit_no;
        begin
            uart_rx_pin = 1'b0;
            // UART counters change bit after BAUD+1 clocks (8 -> 9 in fast sim).
            repeat (9) @(posedge clk);
            for (bit_no = 0; bit_no < 8; bit_no = bit_no + 1) begin
                uart_rx_pin = value[bit_no];
                repeat (9) @(posedge clk);
            end
            uart_rx_pin = 1'b1;
            repeat (9) @(posedge clk);
        end
    endtask

    task automatic uart_send_packet;
        integer n;
        begin
            for (n = 0; n < 35; n = n + 1)
                uart_send_byte(packet_buf[n]);
        end
    endtask

    task automatic fill_ram;
        input[31:0] base_value;
        begin
            for (j = 0; j < 16; j = j + 1)
                dut.u_bridge_bank.u_shared_memory.ram_mem[j] = base_value + j;
        end
    endtask

    task automatic switch_and_check;
        input[1:0] new_core;
        input[255:0] scenario;
        begin
            @(negedge clk);
            chip_sel = new_core;
            #1;
            if ((dut.memory_ready !== 1'b0) ||
                (dut.u_chip.shared_rst !== 1'b0) ||
                (dut.u_bridge_bank.selected_rom_we !== 1'b0) ||
                (dut.u_bridge_bank.selected_ram_we !== 1'b0)) begin
                errors = errors + 1;
                $display("ASSERT_FAIL test=switch_clear scenario=%s item=immediate_gate ready=%b chip_rst=%b rom_we=%b ram_we=%b",
                         scenario, dut.memory_ready, dut.u_chip.shared_rst,
                         dut.u_bridge_bank.selected_rom_we,
                         dut.u_bridge_bank.selected_ram_we);
            end

            ready_cycles = 0;
            while ((dut.memory_ready !== 1'b1) && (ready_cycles < 64)) begin
                @(posedge clk);
                #1;
                ready_cycles = ready_cycles + 1;
                if ((dut.memory_ready !== 1'b1) &&
                    (dut.u_chip.shared_rst !== 1'b0)) begin
                    errors = errors + 1;
                    $display("ASSERT_FAIL test=switch_clear scenario=%s item=reset_released_before_memory cycle=%0d",
                             scenario, ready_cycles);
                end
            end
            if ((ready_cycles < 19) || (ready_cycles >= 64)) begin
                errors = errors + 1;
                $display("ASSERT_FAIL test=switch_clear scenario=%s item=ready_latency cycles=%0d",
                         scenario, ready_cycles);
            end
            for (j = 0; j < 16; j = j + 1) begin
                if (dut.u_bridge_bank.u_shared_memory.ram_mem[j] !== 32'h0) begin
                    errors = errors + 1;
                    $display("ASSERT_FAIL test=switch_clear scenario=%s item=ram_clear word=%0d got=%08x",
                             scenario, j,
                             dut.u_bridge_bank.u_shared_memory.ram_mem[j]);
                end
            end
            if (dut.u_bridge_bank.u_shared_memory.rom_mem[200] !== 32'h1357_9bdf) begin
                errors = errors + 1;
                $display("ASSERT_FAIL test=switch_clear scenario=%s item=rom_retention got=%08x",
                         scenario,
                         dut.u_bridge_bank.u_shared_memory.rom_mem[200]);
            end
            repeat (8) @(posedge clk);
        end
    endtask

    task automatic wait_debug_state;
        input[13:0] wanted;
        input integer limit;
        begin
            wait_cycles = 0;
            while ((dut.u_chip.u_shared_uart_debug.state != wanted) &&
                   (wait_cycles < limit)) begin
                @(posedge clk);
                wait_cycles = wait_cycles + 1;
            end
            if (wait_cycles == limit) begin
                errors = errors + 1;
                $display("ASSERT_FAIL test=switch_clear scenario=downloader item=state_timeout wanted=%h got=%h rec_index=%0d need=%0d uart_status=%08x uart_rx=%02x",
                         wanted, dut.u_chip.u_shared_uart_debug.state,
                         dut.u_chip.u_shared_uart_debug.rec_bytes_index,
                         dut.u_chip.u_shared_uart_debug.need_to_rec_bytes,
                         dut.u_chip.u_wje_tile.u_uart.uart_status,
                         dut.u_chip.u_wje_tile.u_uart.uart_rx[7:0]);
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = 1'b0;
        chip_sel = 2'd0;
        uart_debug_pin = 1'b0;
        uart_rx_pin = 1'b1;
        errors = 0;

        if ($value$plusargs("VCD=%s", vcd_path)) begin
            `MERGED_DUMPFILE(vcd_path);
            `MERGED_DUMPVARS(dut);
            `MERGED_DUMPVARS(dut.u_chip.u_shared_regs.regs[26]);
            `MERGED_DUMPVARS(dut.u_chip.u_shared_regs.regs[27]);
            `MERGED_DUMPVARS(dut.u_bridge_bank.u_shared_memory.rom_mem[0]);
            `MERGED_DUMPVARS(dut.u_bridge_bank.u_shared_memory.rom_mem[200]);
            `MERGED_DUMPVARS(dut.u_bridge_bank.u_shared_memory.ram_mem[0]);
            `MERGED_DUMPVARS(dut.u_bridge_bank.u_shared_memory.ram_mem[15]);
            `MERGED_DUMPVARS(dut.u_chip.u_shared_pwm.period[0]);
            `MERGED_DUMPVARS(dut.u_chip.u_shared_pwm.high_time[0]);
            `MERGED_DUMPVARS(dut.u_chip.u_shared_pwm.counter[0]);
        end

        for (i = 0; i < 256; i = i + 1)
            dut.u_bridge_bank.u_shared_memory.rom_mem[i] = 32'h0000_006f;
        dut.u_bridge_bank.u_shared_memory.rom_mem[200] = 32'h1357_9bdf;

        repeat (5) @(posedge clk);
        rst = 1'b1;
        wait (dut.memory_ready === 1'b1);
        repeat (8) @(posedge clk);

        // Idle switch: choose the brief gap between LHR bridge frames.
        wait_cycles = 0;
        while (((dut.u_bridge_bank.u_lhr_bridge.state != 0) ||
                dut.u_chip.u_lhr_tile.debug_busy_o) && (wait_cycles < 2000)) begin
            @(posedge clk);
            wait_cycles = wait_cycles + 1;
        end
        fill_ram(32'h1111_0000);
        switch_and_check(2'd1, "idle");

        // Switch in the middle of an LDK ROM fetch frame.
        wait_cycles = 0;
        while (!((dut.u_bridge_bank.u_ldk_bridge.u_bridge_slave.cs >= 1) &&
                 (dut.u_bridge_bank.u_ldk_bridge.u_bridge_slave.cs <= 4)) &&
               (wait_cycles < 5000)) begin
            @(posedge clk);
            wait_cycles = wait_cycles + 1;
        end
        fill_ram(32'h2222_0000);
        switch_and_check(2'd2, "rom_read");

        // SY executes a RAM store; change core before adapter S_EXEC commits it.
        dut.u_bridge_bank.u_shared_memory.rom_mem[0] = enc_u(20'h10000, 5'd1);
        dut.u_bridge_bank.u_shared_memory.rom_mem[1] = enc_u(20'hdeadc, 5'd2);
        dut.u_bridge_bank.u_shared_memory.rom_mem[2] = enc_i(-273, 5'd2, 5'd2);
        dut.u_bridge_bank.u_shared_memory.rom_mem[3] = enc_sw(5'd2, 5'd1);
        dut.u_bridge_bank.u_shared_memory.rom_mem[4] = 32'h0000_006f;
        wait_cycles = 0;
        while (!((dut.u_bridge_bank.u_sy_bridge.target == 1'b1) &&
                 (dut.u_bridge_bank.u_sy_bridge.we == 1'b1) &&
                 (dut.u_bridge_bank.u_sy_bridge.state == 4'h4)) &&
               (wait_cycles < 100000)) begin
            @(posedge clk);
            wait_cycles = wait_cycles + 1;
        end
        if (wait_cycles == 100000) begin
            errors = errors + 1;
            $display("ASSERT_FAIL test=switch_clear scenario=ram_write item=transaction_not_seen");
        end
        fill_ram(32'h3333_0000);
        switch_and_check(2'd3, "ram_write");

        // Real serial header + data packet through the shared downloader.
        // Abort after the WJE bridge raises busy but before the ROM write ACK.
        uart_debug_pin = 1'b1;
        wait_debug_state(14'h0010, 5000);
        for (i = 0; i < 35; i = i + 1) packet_buf[i] = 8'h00;
        packet_buf[1] = "s"; packet_buf[2] = "w";
        packet_buf[28] = 8'd4;
        finish_packet();
        uart_send_packet();
        wait_debug_state(14'h0100, 20000);
        wait_debug_state(14'h0010, 20000);

        for (i = 0; i < 35; i = i + 1) packet_buf[i] = 8'h00;
        packet_buf[0] = 8'h01;
        packet_buf[1] = 8'h13;
        packet_buf[2] = 8'h00;
        packet_buf[3] = 8'h00;
        packet_buf[4] = 8'h00;
        finish_packet();
        uart_send_packet();
        wait_debug_state(14'h2000, 20000);
        wait_cycles = 0;
        while (!dut.u_chip.debug_busy && (wait_cycles < 2000)) begin
            @(posedge clk);
            wait_cycles = wait_cycles + 1;
        end
        if (wait_cycles == 2000) begin
            errors = errors + 1;
            $display("ASSERT_FAIL test=switch_clear scenario=downloader item=busy_not_seen");
        end
        dut.u_bridge_bank.u_shared_memory.rom_mem[0] = 32'ha5a5_5a5a;
        fill_ram(32'h4444_0000);
        switch_and_check(2'd0, "downloader");
        uart_debug_pin = 1'b0;
        if (dut.u_bridge_bank.u_shared_memory.rom_mem[0] !== 32'ha5a5_5a5a) begin
            errors = errors + 1;
            $display("ASSERT_FAIL test=switch_clear scenario=downloader item=old_write_not_cancelled got=%08x",
                     dut.u_bridge_bank.u_shared_memory.rom_mem[0]);
        end

        if (errors == 0)
            $display("TEST_PASS test=switch_clear scenarios=idle,rom_read,ram_write,downloader ram_words=16 guard_cycles=3 rom_retained");
        else
            $display("TEST_FAIL test=switch_clear errors=%0d", errors);
        $finish;
    end

endmodule
