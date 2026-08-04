`timescale 1ns/1ps

/* Four-core, CPU-driven shared PWM regression. */
module merged_pwm_tb;

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
    integer i;
    integer sample_count;
    integer model0;
    integer model1;
    integer model3;
    reg enabled_seen;
    reg disabled_seen;
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
        input[2:0] funct3;
        input[4:0] rd;
        begin
            enc_i = {imm[11:0], rs1, funct3, rd, 7'b0010011};
        end
    endfunction

    function automatic [31:0] enc_s;
        input signed[31:0] imm;
        input[4:0] rs2;
        input[4:0] rs1;
        begin
            enc_s = {imm[11:5], rs2, rs1, 3'b010,
                     imm[4:0], 7'b0100011};
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
        begin
            enc_j = {imm[20], imm[10:1], imm[11], imm[19:12],
                     5'd0, 7'b1101111};
        end
    endfunction

    task automatic emit;
        input[31:0] instruction;
        begin
            dut.u_bridge_bank.u_shared_memory.rom_mem[program_words] = instruction;
            program_words = program_words + 1;
        end
    endtask

    task automatic write_pwm;
        input[19:0] address_upper;
        input signed[31:0] value;
        begin
            emit(enc_u(address_upper, 5'd1));
            emit(enc_i(value, 5'd0, 3'b000, 5'd2));
            emit(enc_s(0, 5'd2, 5'd1));
        end
    endtask

    task automatic check_output_relation;
        begin
            if (pwm_o[0] !== ((model0 < 2) ? 1'b1 : 1'b0)) begin
                errors = errors + 1;
                $display("ASSERT_FAIL test=pwm core=%0d channel=0 sample=%0d got=%b expected=%b",
                         core_id, sample_count, pwm_o[0], (model0 < 2));
            end
            if (pwm_o[1] !== ((model1 < 4) ? 1'b1 : 1'b0)) begin
                errors = errors + 1;
                $display("ASSERT_FAIL test=pwm core=%0d channel=1 sample=%0d got=%b expected=%b",
                         core_id, sample_count, pwm_o[1], (model1 < 4));
            end
            if (pwm_o[2] !== 1'b0) begin
                errors = errors + 1;
                $display("ASSERT_FAIL test=pwm core=%0d channel=2 period_zero_output=%b",
                         core_id, pwm_o[2]);
            end
            if (pwm_o[3] !== ((model3 < 1) ? 1'b1 : 1'b0)) begin
                errors = errors + 1;
                $display("ASSERT_FAIL test=pwm core=%0d channel=3 sample=%0d got=%b expected=%b",
                         core_id, sample_count, pwm_o[3], (model3 < 1));
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = 1'b0;
        chip_sel = 2'd0;
        uart_debug_pin = 1'b0;
        uart_rx_pin = 1'b1;
        program_words = 0;
        cycles = 0;
        errors = 0;
        enabled_seen = 1'b0;
        disabled_seen = 1'b0;

        if (!$value$plusargs("CORE=%d", core_id) ||
            (core_id < 0) || (core_id > 3)) begin
            $display("TEST_FAIL test=pwm reason=invalid_or_missing_CORE");
            $finish;
        end
        if ($value$plusargs("VCD=%s", vcd_path)) begin
            $dumpfile(vcd_path);
            $dumpvars(0, dut);
            $dumpvars(0, dut.u_chip.u_shared_pwm.period[0]);
            $dumpvars(0, dut.u_chip.u_shared_pwm.period[1]);
            $dumpvars(0, dut.u_chip.u_shared_pwm.period[2]);
            $dumpvars(0, dut.u_chip.u_shared_pwm.period[3]);
            $dumpvars(0, dut.u_chip.u_shared_pwm.high_time[0]);
            $dumpvars(0, dut.u_chip.u_shared_pwm.high_time[1]);
            $dumpvars(0, dut.u_chip.u_shared_pwm.high_time[2]);
            $dumpvars(0, dut.u_chip.u_shared_pwm.high_time[3]);
            $dumpvars(0, dut.u_chip.u_shared_pwm.counter[0]);
            $dumpvars(0, dut.u_chip.u_shared_pwm.counter[1]);
            $dumpvars(0, dut.u_chip.u_shared_pwm.counter[2]);
            $dumpvars(0, dut.u_chip.u_shared_pwm.counter[3]);
        end
        chip_sel = core_id[1:0];

        for (i = 0; i < 256; i = i + 1)
            dut.u_bridge_bank.u_shared_memory.rom_mem[i] = 32'h0000_0013;

        write_pwm(20'h60000, 4);  // period 0
        write_pwm(20'h60010, 5);  // period 1
        write_pwm(20'h60020, 0);  // period 2: explicit zero case
        write_pwm(20'h60030, 3);  // period 3
        write_pwm(20'h60100, 2);  // high 0
        write_pwm(20'h60110, 4);  // high 1
        write_pwm(20'h60120, 7);  // ignored while period 2 is zero
        write_pwm(20'h60130, 1);  // high 3
        write_pwm(20'h60040, 15); // enable all four
        for (i = 0; i < 100; i = i + 1) emit(32'h0000_0013);
        write_pwm(20'h60040, 14); // disable channel 0
        emit(enc_i(1, 5'd0, 3'b000, 5'd27));
        emit(enc_i(1, 5'd0, 3'b000, 5'd26));
        emit(enc_j(0));

        repeat (5) @(posedge clk);
        rst <= 1'b1;

        // Find the core's enable write, then verify independent reference
        // counters for 20 consecutive shared-PWM clock edges.
        while (!enabled_seen && (cycles < 400000)) begin
            @(posedge clk);
            #1;
            cycles = cycles + 1;
            if (dut.u_chip.u_shared_pwm.enable === 4'hf) begin
                enabled_seen = 1'b1;
                model0 = dut.u_chip.u_shared_pwm.counter[0];
                model1 = dut.u_chip.u_shared_pwm.counter[1];
                model3 = dut.u_chip.u_shared_pwm.counter[3];
                for (sample_count = 0; sample_count < 20;
                     sample_count = sample_count + 1) begin
                    check_output_relation();
                    @(posedge clk);
                    #1;
                    model0 = (model0 == 3) ? 0 : model0 + 1;
                    model1 = (model1 == 4) ? 0 : model1 + 1;
                    model3 = (model3 == 2) ? 0 : model3 + 1;
                    if (dut.u_chip.u_shared_pwm.counter[0] !== model0) errors = errors + 1;
                    if (dut.u_chip.u_shared_pwm.counter[1] !== model1) errors = errors + 1;
                    if (dut.u_chip.u_shared_pwm.counter[2] !== 0) errors = errors + 1;
                    if (dut.u_chip.u_shared_pwm.counter[3] !== model3) errors = errors + 1;
                end
            end
        end

        while (!disabled_seen && (cycles < 400000)) begin
            @(posedge clk);
            #1;
            cycles = cycles + 1;
            if (dut.u_chip.u_shared_pwm.enable === 4'he)
                disabled_seen = 1'b1;
        end

        if (!enabled_seen || !disabled_seen) begin
            errors = errors + 1;
            $display("ASSERT_FAIL test=pwm core=%0d enabled_seen=%b disabled_seen=%b",
                     core_id, enabled_seen, disabled_seen);
        end
        repeat (4) begin
            @(posedge clk);
            #1;
            if ((pwm_o[0] !== 1'b0) ||
                (dut.u_chip.u_shared_pwm.counter[0] !== 32'd0)) begin
                errors = errors + 1;
                $display("ASSERT_FAIL test=pwm core=%0d item=disable channel0=%b counter=%0d",
                         core_id, pwm_o[0], dut.u_chip.u_shared_pwm.counter[0]);
            end
        end

        i = 0;
        while ((dut.u_chip.u_shared_regs.regs[26] !== 32'd1) &&
               (i < 400000)) begin
            @(posedge clk);
            i = i + 1;
        end
        if (i == 400000) begin
            errors = errors + 1;
            $display("ASSERT_FAIL test=pwm core=%0d item=completion_timeout", core_id);
        end
        repeat (20) @(posedge clk);
        if ((dut.u_chip.u_shared_pwm.period[0] !== 32'd4) ||
            (dut.u_chip.u_shared_pwm.period[1] !== 32'd5) ||
            (dut.u_chip.u_shared_pwm.period[2] !== 32'd0) ||
            (dut.u_chip.u_shared_pwm.period[3] !== 32'd3) ||
            (dut.u_chip.u_shared_pwm.high_time[0] !== 32'd2) ||
            (dut.u_chip.u_shared_pwm.high_time[1] !== 32'd4) ||
            (dut.u_chip.u_shared_pwm.high_time[2] !== 32'd7) ||
            (dut.u_chip.u_shared_pwm.high_time[3] !== 32'd1) ||
            (dut.u_chip.u_shared_pwm.enable !== 4'he) ||
            (dut.u_chip.u_shared_regs.regs[26] !== 32'd1) ||
            (dut.u_chip.u_shared_regs.regs[27] !== 32'd1) ||
            (succ !== 1'b0)) begin
            errors = errors + 1;
            $display("ASSERT_FAIL test=pwm core=%0d item=final_state x26=%08x x27=%08x succ=%b enable=%x",
                     core_id, dut.u_chip.u_shared_regs.regs[26],
                     dut.u_chip.u_shared_regs.regs[27], succ,
                     dut.u_chip.u_shared_pwm.enable);
        end

        if (errors == 0)
            $display("TEST_PASS test=pwm core=%0d period=4,5,0,3 high=2,4,7,1 enable=f->e cycles=%0d",
                     core_id, cycles);
        else
            $display("TEST_FAIL test=pwm core=%0d errors=%0d cycles=%0d",
                     core_id, errors, cycles);
        $finish;
    end

endmodule
