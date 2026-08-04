`timescale 1 ns / 1 ps

`include "defines.v"

module tinyriscv_bridge_validation_tb;

    reg clk;
    reg rst;
    wire succ;
    wire uart_tx_pin;
    wire[2:0] pwm_o;
    wire io_scl;
    tri1 io_sda;

    reg lm75_sda_low;
    assign io_sda = lm75_sda_low ? 1'b0 : 1'bz;

    reg[1023:0] mem_file;
    reg[1023:0] vcd_file;
    reg[8*32-1:0] test_kind;
    integer max_cycles;
    integer mem_words;
    integer cycle_count;
    integer uart_count;
    integer trace_en;
    integer trace_bridge_en;
    integer finish_wait;
    integer sid_error;
    integer i2c_start_count;
    integer i2c_stop_count;
    integer i2c_scl_edge_count;
    integer i;
    reg[7:0] last_uart_byte;
    reg[3:0] pwm_seen_high;
    reg[3:0] pwm_seen_low;
    reg prev_scl;
    reg[3:0] prev_i2c_state;
    localparam [15:0] LM75_WORD = 16'h1900;

    wire[`RegBus] x3 = dut.u_chip.u_tinyriscv.u_regs.regs[3];
    wire[`RegBus] x7 = dut.u_chip.u_tinyriscv.u_regs.regs[7];
    wire[`RegBus] x8 = dut.u_chip.u_tinyriscv.u_regs.regs[8];
    wire[`RegBus] x9 = dut.u_chip.u_tinyriscv.u_regs.regs[9];
    wire[`RegBus] x10 = dut.u_chip.u_tinyriscv.u_regs.regs[10];
    wire[`RegBus] x11 = dut.u_chip.u_tinyriscv.u_regs.regs[11];
    wire[`RegBus] x12 = dut.u_chip.u_tinyriscv.u_regs.regs[12];
    wire[`RegBus] x13 = dut.u_chip.u_tinyriscv.u_regs.regs[13];
    wire[`RegBus] x14 = dut.u_chip.u_tinyriscv.u_regs.regs[14];
    wire[`RegBus] x26 = dut.u_chip.u_tinyriscv.u_regs.regs[26];
    wire[`RegBus] x27 = dut.u_chip.u_tinyriscv.u_regs.regs[27];
    wire[`RegBus] x30 = dut.u_chip.u_tinyriscv.u_regs.regs[30];
    wire[`RegBus] x31 = dut.u_chip.u_tinyriscv.u_regs.regs[31];

    function [7:0] sid_expected;
        input integer index;
        begin
            case (index)
                0: sid_expected = 8'h32;
                1: sid_expected = 8'h30;
                2: sid_expected = 8'h32;
                3: sid_expected = 8'h33;
                4: sid_expected = 8'h33;
                5: sid_expected = 8'h31;
                6: sid_expected = 8'h30;
                7: sid_expected = 8'h39;
                8: sid_expected = 8'h33;
                default: sid_expected = 8'h36;
            endcase
        end
    endfunction

    // Minimal LM75 model. It acknowledges all address phases and returns
    // 16'h1900 (25 C in LM75 format). Course rT selects bits [14:7], so the
    // expected instruction result is 8'h32.
    always @ (*) begin
        lm75_sda_low = 1'b0;
        if ((dut.u_chip.i2c_0.state == 4'd4) ||
            (dut.u_chip.i2c_0.state == 4'd5)) begin
            lm75_sda_low = 1'b1;
        end else if ((dut.u_chip.i2c_0.state == 4'd9) ||
                     (dut.u_chip.i2c_0.state == 4'd10)) begin
            if (dut.u_chip.i2c_0.step == 2'd2) begin
                lm75_sda_low = ~LM75_WORD[8 + dut.u_chip.i2c_0.bit_cnt];
            end else begin
                lm75_sda_low = ~LM75_WORD[dut.u_chip.i2c_0.bit_cnt];
            end
        end
    end

    always #10 clk = ~clk;

    initial begin
        clk = 1'b0;
        rst = `RstEnable;
        cycle_count = 0;
        uart_count = 0;
        trace_en = 0;
        trace_bridge_en = 0;
        finish_wait = -1;
        sid_error = 0;
        i2c_start_count = 0;
        i2c_stop_count = 0;
        i2c_scl_edge_count = 0;
        last_uart_byte = 8'h00;
        pwm_seen_high = 4'h0;
        pwm_seen_low = 4'h0;
        prev_scl = 1'b1;
        prev_i2c_state = 4'd0;
        max_cycles = 200000;
        mem_words = 256;
        test_kind = "BASIC";

        if (!$value$plusargs("MEMFILE=%s", mem_file)) begin
            mem_file = "tests/programs/basic/inst_add.data";
        end
        if (!$value$plusargs("MEM_WORDS=%d", mem_words)) begin
            mem_words = 256;
        end
        if (!$value$plusargs("MAX_CYCLES=%d", max_cycles)) begin
            max_cycles = 200000;
        end
        if (!$value$plusargs("TEST=%s", test_kind)) begin
            test_kind = "BASIC";
        end
        if (!$value$plusargs("TRACE=%d", trace_en)) begin
            trace_en = 0;
        end
        if (!$value$plusargs("TRACE_BRIDGE=%d", trace_bridge_en)) begin
            trace_bridge_en = 0;
        end

        for (i = 0; i < `RomNum; i = i + 1) begin
            dut.u_bridge_fpga.rom_mem[i] = `INST_NOP;
        end
        for (i = 0; i < `MemNum; i = i + 1) begin
            dut.u_bridge_fpga.ram_mem[i] = `ZeroWord;
        end

        $display("TEST_BEGIN kind=%0s mem=%0s words=%0d max_cycles=%0d",
                 test_kind, mem_file, mem_words, max_cycles);
        $readmemh(mem_file, dut.u_bridge_fpga.rom_mem, 0, mem_words - 1);

        if ($value$plusargs("VCD=%s", vcd_file)) begin
            $dumpfile(vcd_file);
            $dumpvars(0, tinyriscv_bridge_validation_tb);
        end

        #40;
        // Do not let the I2C reset value mask a failed sensor read.
        if (test_kind == "I2C") begin
            dut.u_chip.i2c_0.input_data = 16'h0000;
        end
        rst = `RstDisable;
    end

    always @ (posedge clk) begin
        if (rst == `RstDisable) begin
            cycle_count <= cycle_count + 1;
            pwm_seen_high <= pwm_seen_high | dut.pwm_all;
            pwm_seen_low <= pwm_seen_low | ~dut.pwm_all;

            if (io_scl !== prev_scl) begin
                i2c_scl_edge_count <= i2c_scl_edge_count + 1;
            end
            if ((dut.u_chip.i2c_0.state == 4'd1) &&
                (prev_i2c_state != 4'd1)) begin
                i2c_start_count <= i2c_start_count + 1;
            end
            if ((dut.u_chip.i2c_0.state == 4'd15) &&
                (prev_i2c_state != 4'd15)) begin
                i2c_stop_count <= i2c_stop_count + 1;
                if (test_kind == "I2C") begin
                    if ((i2c_start_count > 0) &&
                        (i2c_scl_edge_count >= 64) &&
                        (dut.u_chip.i2c_0.input_data == 16'h1900)) begin
                        $display("TEST_PASS kind=I2C cycles=%0d starts=%0d stops=%0d scl_edges=%0d raw=0x%04x converted=0x%02x",
                                 cycle_count, i2c_start_count,
                                 i2c_stop_count + 1, i2c_scl_edge_count,
                                 dut.u_chip.i2c_0.input_data,
                                 dut.u_chip.i2c_0.input_data[14:7]);
                        $finish;
                    end else begin
                        $fatal(1, "TEST_FAIL kind=I2C starts=%0d stops=%0d edges=%0d raw=0x%04x state=%0d step=%0d",
                               i2c_start_count, i2c_stop_count + 1,
                               i2c_scl_edge_count,
                               dut.u_chip.i2c_0.input_data,
                               dut.u_chip.i2c_0.state,
                               dut.u_chip.i2c_0.step);
                    end
                end
            end
            prev_scl <= io_scl;
            prev_i2c_state <= dut.u_chip.i2c_0.state;

            if (dut.u_chip.uart_0.tx_data_valid == 1'b1) begin
                last_uart_byte <= dut.u_chip.uart_0.tx_data;
                uart_count <= uart_count + 1;
                $display("UART_TX cycle=%0d index=%0d byte=0x%02x",
                         cycle_count, uart_count,
                         dut.u_chip.uart_0.tx_data);

                if (test_kind == "SID") begin
                    if (dut.u_chip.uart_0.tx_data != sid_expected(uart_count)) begin
                        sid_error <= 1;
                    end
                    if (uart_count == 9) begin
                        if ((sid_error == 0) &&
                            (dut.u_chip.uart_0.tx_data == sid_expected(9))) begin
                            $display("TEST_PASS kind=SID cycles=%0d bytes=2023310936",
                                     cycle_count);
                            $finish;
                        end else begin
                            $fatal(1, "TEST_FAIL kind=SID UART byte mismatch");
                        end
                    end
                end else if (test_kind == "IF") begin
                    if (dut.u_chip.uart_0.tx_data == 8'h8a) begin
                        $display("TEST_PASS kind=IF cycles=%0d uart=0x8a x14=0x%08x x31=0x%08x",
                                 cycle_count, x14, x31);
                        $finish;
                    end else begin
                        $fatal(1, "TEST_FAIL kind=IF expected UART 0x8a");
                    end
                end
            end

            if (trace_en != 0 &&
                dut.u_chip.u_tinyriscv.ex_reg_we_o == `WriteEnable) begin
                $display("TRACE_EX cycle=%0d pc=0x%08x inst=0x%08x rd=x%0d data=0x%08x",
                         cycle_count,
                         dut.u_chip.u_tinyriscv.ie_inst_addr_o,
                         dut.u_chip.u_tinyriscv.ie_inst_o,
                         dut.u_chip.u_tinyriscv.ex_reg_waddr_o,
                         dut.u_chip.u_tinyriscv.ex_reg_wdata_o);
            end

            if (trace_bridge_en != 0 &&
                dut.u_chip.u_ext_mem_bridge.ready_o == 1'b1) begin
                $display("BRIDGE_READY cycle=%0d addr=0x%08x we=%b rdata=0x%08x error=%b",
                         cycle_count,
                         dut.u_chip.u_ext_mem_bridge.req_addr,
                         dut.u_chip.u_ext_mem_bridge.cmd,
                         dut.u_chip.u_ext_mem_bridge.rdata_o,
                         dut.u_chip.u_ext_mem_bridge.error_o);
            end

            if ((test_kind == "BASIC") ||
                (test_kind == "BRIDGE_RAM") ||
                (test_kind == "M_REMOVED")) begin
                if (x26 == 32'h1) begin
                    if (finish_wait < 0) begin
                        finish_wait <= 200;
                    end else if (finish_wait > 0) begin
                        finish_wait <= finish_wait - 1;
                    end else if (x27 !== 32'h1) begin
                        $fatal(1, "TEST_FAIL kind=%0s x27=0x%08x", test_kind, x27);
                    end else if (succ !== 1'b0) begin
                        $fatal(1, "TEST_FAIL kind=%0s succ=%b", test_kind, succ);
                    end else if ((test_kind == "BRIDGE_RAM") &&
                                 (x30 != 32'h00000055)) begin
                        $fatal(1, "TEST_FAIL kind=BRIDGE_RAM x30=0x%08x", x30);
                    end else if ((test_kind == "M_REMOVED") &&
                                 ((x7  != 32'h00000051) ||
                                  (x8  != 32'h00000052) ||
                                  (x9  != 32'h00000053) ||
                                  (x10 != 32'h00000054) ||
                                  (x11 != 32'h00000055) ||
                                  (x12 != 32'h00000056) ||
                                  (x13 != 32'h00000057) ||
                                  (x14 != 32'h00000058))) begin
                        $fatal(1, "TEST_FAIL kind=M_REMOVED x7..x14=%08x,%08x,%08x,%08x,%08x,%08x,%08x,%08x",
                               x7, x8, x9, x10, x11, x12, x13, x14);
                    end else if (test_kind == "M_REMOVED") begin
                        $display("TEST_PASS kind=M_REMOVED cycles=%0d all_RV32M_destinations_unchanged x7..x14=%08x,%08x,%08x,%08x,%08x,%08x,%08x,%08x succ=%b",
                                 cycle_count, x7, x8, x9, x10, x11, x12,
                                 x13, x14, succ);
                        $finish;
                    end else begin
                        $display("TEST_PASS kind=%0s cycles=%0d x3=0x%08x x7=0x%08x x8=0x%08x x26=0x%08x x27=0x%08x x30=0x%08x succ=%b",
                                 test_kind, cycle_count, x3, x7, x8,
                                 x26, x27, x30, succ);
                        $finish;
                    end
                end
            end else if (test_kind == "RT") begin
                if ((x26 == 32'h1) && (uart_count >= 1)) begin
                    if ((x14 == 32'h00000032) &&
                        (last_uart_byte == 8'h32)) begin
                        $display("TEST_PASS kind=RT cycles=%0d raw=0x1900 x14=0x%08x uart=0x%02x",
                                 cycle_count, x14, last_uart_byte);
                        $finish;
                    end else begin
                        $fatal(1, "TEST_FAIL kind=RT x14=0x%08x uart=0x%02x", x14, last_uart_byte);
                    end
                end
            end else if (test_kind == "PWM") begin
                if ((dut.u_chip.pwm_0.enable == 4'hf) &&
                    (pwm_seen_high == 4'hf)) begin
                    if ((x14 == 32'h0000000f) &&
                        (pwm_seen_low == 4'hf)) begin
                        $display("TEST_PASS kind=PWM cycles=%0d enable=0x%x seen_high=0x%x seen_low=0x%x board_pwm=%b",
                                 cycle_count, dut.u_chip.pwm_0.enable,
                                 pwm_seen_high, pwm_seen_low, pwm_o);
                        $finish;
                    end else begin
                        $fatal(1, "TEST_FAIL kind=PWM x14=0x%08x high=0x%x low=0x%x", x14, pwm_seen_high, pwm_seen_low);
                    end
                end
            end

            if (cycle_count >= max_cycles) begin
                $fatal(1, "TEST_TIMEOUT kind=%0s cycles=%0d pc=0x%08x x14=0x%08x x26=0x%08x x27=0x%08x uart_count=%0d pwm_all=0x%x i2c_start=%0d i2c_stop=%0d",
                       test_kind, cycle_count,
                       dut.u_chip.u_tinyriscv.pc_pc_o,
                       x14, x26, x27, uart_count, dut.pwm_all,
                       i2c_start_count, i2c_stop_count);
            end
        end
    end

    tinyriscv_soc_top_bridge_fpga dut(
        .clk(clk),
        .rst(rst),
        .succ(succ),
        .uart_debug_pin(1'b0),
        .uart_tx_pin(uart_tx_pin),
        .uart_rx_pin(1'b1),
        .pwm_o(pwm_o),
        .io_scl(io_scl),
        .io_sda(io_sda)
    );

endmodule
