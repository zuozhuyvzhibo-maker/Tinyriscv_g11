`timescale 1ns/1ps

/*
 * Four-core smoke test through the complete merged FPGA top.
 * The same basic image is loaded into the single shared FPGA ROM.
 */
module merged_core_smoke_tb;

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
    integer finish_wait;
    reg[1023:0] mem_path;

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

    always #10 clk = ~clk;

    initial begin
        clk = 1'b0;
        rst = 1'b0;
        chip_sel = 2'd0;
        uart_debug_pin = 1'b0;
        uart_rx_pin = 1'b1;
        finish_wait = -1;

        if (!$value$plusargs("CORE=%d", core_id)) begin
            $display("TEST_FAIL reason=missing_CORE_plusarg");
            $finish;
        end
        if (!$value$plusargs("MEM=%s", mem_path)) begin
            $display("TEST_FAIL reason=missing_MEM_plusarg");
            $finish;
        end
        if ((core_id < 0) || (core_id > 3)) begin
            $display("TEST_FAIL reason=invalid_CORE core=%0d", core_id);
            $finish;
        end

        chip_sel = core_id[1:0];
        $readmemh(mem_path, dut.u_bridge_bank.u_shared_memory.rom_mem);

        repeat (5) @(posedge clk);
        rst <= 1'b1;

        for (cycles = 0; cycles < 100000; cycles = cycles + 1) begin
            @(posedge clk);

            if ((dut.u_chip.u_shared_regs.regs[26] === 32'h1) &&
                (finish_wait == -1)) begin
                finish_wait = 200;
            end else if (finish_wait > 0) begin
                finish_wait = finish_wait - 1;
            end else if (finish_wait == 0) begin
                if ((dut.u_chip.u_shared_regs.regs[27] === 32'h1) &&
                    (succ === 1'b0)) begin
                    $display("TEST_PASS kind=CORE_SMOKE core=%0d x26=%08x x27=%08x succ=%b",
                             core_id,
                             dut.u_chip.u_shared_regs.regs[26],
                             dut.u_chip.u_shared_regs.regs[27],
                             succ);
                end else begin
                    $display("TEST_FAIL kind=CORE_SMOKE core=%0d x26=%08x x27=%08x succ=%b",
                             core_id,
                             dut.u_chip.u_shared_regs.regs[26],
                             dut.u_chip.u_shared_regs.regs[27],
                             succ);
                end
                $finish;
            end
        end

        $display("TEST_FAIL kind=CORE_SMOKE core=%0d reason=timeout x26=%08x x27=%08x succ=%b",
                 core_id,
                 dut.u_chip.u_shared_regs.regs[26],
                 dut.u_chip.u_shared_regs.regs[27],
                 succ);
        $finish;
    end

endmodule
