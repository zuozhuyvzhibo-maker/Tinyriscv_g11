`timescale 1 ns / 1 ps

module tinyriscv_merge_validation_tb;

    localparam RST_ENABLE  = 1'b0;
    localparam RST_DISABLE = 1'b1;
    localparam INST_NOP    = 32'h00000013;
    localparam ZERO_WORD   = 32'h00000000;

    reg clk;
    reg rst;
    reg[2:0] chip_sel;
    wire over;
    wire succ;
    wire uart_tx_pin;
    wire[3:0] pwm_o;
    tri1 io_scl;
    tri1 io_sda;
    wire lm75_sda_o;
    wire lm75_sda_oe;
    wire ldk_lm75_sda_low;

    assign io_sda = ldk_lm75_sda_low ? 1'b0 :
                    (((chip_sel != 3'd1) && lm75_sda_oe) ? lm75_sda_o : 1'bz);

    reg[1023:0] mem_file;
    reg[1023:0] vcd_file;
    reg[8*32-1:0] test_kind;
    integer max_cycles;
    integer mem_words;
    integer cycle_count;
    integer uart_count;
    integer finish_wait;
    integer sid_error;
    integer i;
    integer chip_sel_arg;
    integer trace_ldk;
    reg[7:0] last_uart_byte;
    reg[3:0] pwm_seen_high;
    reg[3:0] pwm_seen_low;

    wire[31:0] lhr_x14 = dut.u_lhr_top.u_chip.u_tinyriscv.u_regs.lhr_regs[14];
    wire[31:0] lhr_x26 = dut.u_lhr_top.u_chip.u_tinyriscv.u_regs.lhr_regs[26];
    wire[31:0] lhr_x27 = dut.u_lhr_top.u_chip.u_tinyriscv.u_regs.lhr_regs[27];

    wire[31:0] ldk_x14 = dut.u_ldk_top.u_tinyriscv_soc_top.u_tinyriscv.u_regs.ldk_regs[14];
    wire[31:0] ldk_x26 = dut.u_ldk_top.u_tinyriscv_soc_top.u_tinyriscv.u_regs.ldk_regs[26];
    wire[31:0] ldk_x27 = dut.u_ldk_top.u_tinyriscv_soc_top.u_tinyriscv.u_regs.ldk_regs[27];

    wire[31:0] wje_x14 = dut.u_wje_top.u_soc.u_tinyriscv.u_regs.wje_regs[14];
    wire[31:0] wje_x26 = dut.u_wje_top.u_soc.u_tinyriscv.u_regs.wje_regs[26];
    wire[31:0] wje_x27 = dut.u_wje_top.u_soc.u_tinyriscv.u_regs.wje_regs[27];

    wire[31:0] sy_x14 = dut.u_sy_top.tinyriscv_soc_top_0.u_tinyriscv.u_regs.sy_regs[14];
    wire[31:0] sy_x26 = dut.u_sy_top.tinyriscv_soc_top_0.u_tinyriscv.u_regs.sy_regs[26];
    wire[31:0] sy_x27 = dut.u_sy_top.tinyriscv_soc_top_0.u_tinyriscv.u_regs.sy_regs[27];
    wire[31:0] sy_pc = dut.u_sy_top.tinyriscv_soc_top_0.u_tinyriscv.pc_pc_o;
    wire[31:0] sy_ex_inst = dut.u_sy_top.tinyriscv_soc_top_0.u_tinyriscv.ie_inst_o;
    wire[31:0] sy_ex_addr = dut.u_sy_top.tinyriscv_soc_top_0.u_tinyriscv.rib_ex_addr_o;
    wire[31:0] sy_iic_data = dut.u_sy_top.tinyriscv_soc_top_0.u_iic.in_reg;
    wire[3:0] sy_iic_state = dut.u_sy_top.tinyriscv_soc_top_0.u_iic.state;
    wire[3:0] sy_bridge_state = dut.u_sy_top.tinyriscv_soc_top_0.u_bridge.state;
    wire sy_bridge_done = dut.u_sy_top.tinyriscv_soc_top_0.u_bridge.done;
    wire sy_bridge_done_wait = dut.u_sy_top.tinyriscv_soc_top_0.u_bridge.done_wait;
    wire sy_bridge_same_req = dut.u_sy_top.tinyriscv_soc_top_0.u_bridge.same_req;
    wire sy_bridge_hold = dut.u_sy_top.tinyriscv_soc_top_0.u_bridge.hold;
    wire[3:0] sy_fpga_bridge_state = dut.u_sy_top.bridge_fpga_0.state;

    wire[31:0] active_x14 = (chip_sel == 3'd0) ? lhr_x14 :
                            (chip_sel == 3'd1) ? ldk_x14 :
                            (chip_sel == 3'd2) ? wje_x14 :
                                                  sy_x14;
    wire[31:0] active_x26 = (chip_sel == 3'd0) ? lhr_x26 :
                            (chip_sel == 3'd1) ? ldk_x26 :
                            (chip_sel == 3'd2) ? wje_x26 :
                                                  sy_x26;
    wire[31:0] active_x27 = (chip_sel == 3'd0) ? lhr_x27 :
                            (chip_sel == 3'd1) ? ldk_x27 :
                            (chip_sel == 3'd2) ? wje_x27 :
                                                  sy_x27;
    wire[7:0] expected_rt_byte = (chip_sel == 3'd2) ? 8'h19 : 8'h32;

    function [7:0] sid_expected;
        input integer index;
        begin
            if (chip_sel == 3'd1) begin
                case (index)
                    0: sid_expected = 8'h32;
                    1: sid_expected = 8'h30;
                    2: sid_expected = 8'h32;
                    3: sid_expected = 8'h35;
                    4: sid_expected = 8'h32;
                    5: sid_expected = 8'h31;
                    6: sid_expected = 8'h30;
                    7: sid_expected = 8'h39;
                    8: sid_expected = 8'h30;
                    default: sid_expected = 8'h35;
                endcase
            end else if (chip_sel == 3'd2) begin
                case (index)
                    0: sid_expected = 8'h32;
                    1: sid_expected = 8'h30;
                    2: sid_expected = 8'h32;
                    3: sid_expected = 8'h35;
                    4: sid_expected = 8'h33;
                    5: sid_expected = 8'h31;
                    6: sid_expected = 8'h36;
                    7: sid_expected = 8'h31;
                    8: sid_expected = 8'h39;
                    default: sid_expected = 8'h31;
                endcase
            end else if (chip_sel == 3'd3) begin
                case (index)
                    0: sid_expected = 8'h32;
                    1: sid_expected = 8'h30;
                    2: sid_expected = 8'h32;
                    3: sid_expected = 8'h35;
                    4: sid_expected = 8'h32;
                    5: sid_expected = 8'h31;
                    6: sid_expected = 8'h30;
                    7: sid_expected = 8'h38;
                    8: sid_expected = 8'h37;
                    default: sid_expected = 8'h30;
                endcase
            end else begin
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
        end
    endfunction

    always #10 clk = ~clk;

    initial begin
        clk = 1'b0;
        rst = RST_ENABLE;
        chip_sel = 3'd0;
        cycle_count = 0;
        uart_count = 0;
        finish_wait = -1;
        sid_error = 0;
        trace_ldk = 0;
        last_uart_byte = 8'h00;
        pwm_seen_high = 4'h0;
        pwm_seen_low = 4'h0;
        max_cycles = 200000;
        mem_words = 256;
        test_kind = "BASIC";

        if ($value$plusargs("CHIP_SEL=%d", chip_sel_arg)) begin
            chip_sel = chip_sel_arg[2:0];
        end
        if (!$value$plusargs("MEMFILE=%s", mem_file)) begin
            mem_file = "rtl_tomerge/rtl/merge_version/lhr/tests/programs/basic/inst_add.data";
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
        if (!$value$plusargs("TRACE_LDK=%d", trace_ldk)) begin
            trace_ldk = 0;
        end

        init_all_memories;

        $display("TEST_BEGIN chip_sel=%0d kind=%0s mem=%0s words=%0d max_cycles=%0d",
                 chip_sel, test_kind, mem_file, mem_words, max_cycles);
        load_active_rom;

        if ($value$plusargs("VCD=%s", vcd_file)) begin
            $dumpfile(vcd_file);
            $dumpvars(0, tinyriscv_merge_validation_tb);
        end

        #200;
        rst = RST_DISABLE;
    end

    task init_all_memories;
        begin
            for (i = 0; i < 256; i = i + 1) begin
                dut.u_lhr_top.u_bridge_fpga.rom_mem[i] = INST_NOP;
                dut.u_wje_top.u_bridge_fpga.fpga_rom[i] = INST_NOP;
                dut.u_sy_top.bridge_fpga_0.u_rom_ext._rom[i] = INST_NOP;
            end
            for (i = 0; i < 16; i = i + 1) begin
                dut.u_lhr_top.u_bridge_fpga.ram_mem[i] = ZERO_WORD;
                dut.u_wje_top.u_bridge_fpga.fpga_ram[i] = ZERO_WORD;
                dut.u_sy_top.bridge_fpga_0.u_ram_ext._ram[i] = ZERO_WORD;
            end
            for (i = 0; i < 4096; i = i + 1) begin
                dut.u_ldk_top.u_bridge_slave_top.u_rom._rom[i] = INST_NOP;
                dut.u_ldk_top.u_bridge_slave_top.u_ram._ram[i] = ZERO_WORD;
            end
            dut.u_sy_top.tinyriscv_soc_top_0.u_iic.in_reg = 32'h00000032;
        end
    endtask

    task load_active_rom;
        begin
            if (chip_sel == 3'd0) begin
                $readmemh(mem_file, dut.u_lhr_top.u_bridge_fpga.rom_mem, 0, mem_words - 1);
            end else if (chip_sel == 3'd1) begin
                $readmemh(mem_file, dut.u_ldk_top.u_bridge_slave_top.u_rom._rom, 0, mem_words - 1);
            end else if (chip_sel == 3'd2) begin
                $readmemh(mem_file, dut.u_wje_top.u_bridge_fpga.fpga_rom, 0, mem_words - 1);
            end else begin
                $readmemh(mem_file, dut.u_sy_top.bridge_fpga_0.u_rom_ext._rom, 0, mem_words - 1);
            end
        end
    endtask

    always @ (posedge clk) begin
        if (rst == RST_DISABLE) begin
            cycle_count <= cycle_count + 1;
            pwm_seen_high <= pwm_seen_high | pwm_o;
            pwm_seen_low <= pwm_seen_low | ~pwm_o;

            if (uart_tx_event) begin
                last_uart_byte <= uart_tx_byte;
                uart_count <= uart_count + 1;
                $display("UART_TX chip_sel=%0d cycle=%0d index=%0d byte=0x%02x",
                         chip_sel, cycle_count, uart_count, uart_tx_byte);

                if (test_kind == "SID") begin
                    if (uart_tx_byte != sid_expected(uart_count)) begin
                        sid_error <= 1;
                    end
                    if (uart_count == 9) begin
                        if ((sid_error == 0) && (uart_tx_byte == sid_expected(9))) begin
                            $display("TEST_PASS chip_sel=%0d kind=SID cycles=%0d bytes_checked=10",
                                     chip_sel, cycle_count);
                            $finish;
                        end else begin
                            $fatal(1, "TEST_FAIL chip_sel=%0d kind=SID byte mismatch", chip_sel);
                        end
                    end
                end else if (test_kind == "IF") begin
                    if (uart_tx_byte == 8'h8a) begin
                        $display("TEST_PASS chip_sel=%0d kind=IF cycles=%0d uart=0x8a x14=0x%08x",
                                 chip_sel, cycle_count, active_x14);
                        $finish;
                    end else begin
                        $fatal(1, "TEST_FAIL chip_sel=%0d kind=IF expected 0x8a got 0x%02x",
                               chip_sel, uart_tx_byte);
                    end
                end else if (test_kind == "RT") begin
                    if (uart_tx_byte == expected_rt_byte) begin
                        $display("TEST_PASS chip_sel=%0d kind=RT cycles=%0d uart=0x%02x x14=0x%08x",
                                 chip_sel, cycle_count, uart_tx_byte, active_x14);
                        $finish;
                    end
                end
            end

            if ((trace_ldk != 0) && (chip_sel == 3'd1)) begin
                if ((dut.u_ldk_top.u_tinyriscv_soc_top.u_iic_dk.ack_o == 1'b1) ||
                    (uart_tx_event == 1'b1)) begin
                    $display("TRACE_LDK cycle=%0d pc=0x%08x inst=0x%08x ctrl_state=0x%0x mem_req=%b mem_we=%b mem_ack=%b mem_addr=0x%08x mem_wdata=0x%08x mem_rdata=0x%08x iic_busy=%b iic_cs=%0d iic_ack=%b iic_data=0x%04x x15=0x%08x",
                             cycle_count,
                             dut.u_ldk_top.u_tinyriscv_soc_top.u_tinyriscv.pc_pc_o,
                             dut.u_ldk_top.u_tinyriscv_soc_top.u_tinyriscv.ie_inst_o,
                             dut.u_ldk_top.u_tinyriscv_soc_top.u_tinyriscv.ctrl_state_o,
                             dut.u_ldk_top.u_tinyriscv_soc_top.u_tinyriscv.rib_ex_req_o,
                             dut.u_ldk_top.u_tinyriscv_soc_top.u_tinyriscv.rib_ex_we_o,
                             dut.u_ldk_top.u_tinyriscv_soc_top.u_tinyriscv.rib_ex_ack_i,
                             dut.u_ldk_top.u_tinyriscv_soc_top.u_tinyriscv.rib_ex_addr_o,
                             dut.u_ldk_top.u_tinyriscv_soc_top.u_tinyriscv.rib_ex_data_o,
                             dut.u_ldk_top.u_tinyriscv_soc_top.u_tinyriscv.rib_ex_data_i,
                             dut.u_ldk_top.u_tinyriscv_soc_top.u_iic_dk.iic_busy,
                             dut.u_ldk_top.u_tinyriscv_soc_top.u_iic_dk.iic_cs,
                             dut.u_ldk_top.u_tinyriscv_soc_top.u_iic_dk.ack_o,
                             dut.u_ldk_top.u_tinyriscv_soc_top.u_iic_dk.data_out_reg[15:0],
                             dut.u_ldk_top.u_tinyriscv_soc_top.u_tinyriscv.u_regs.ldk_regs[15]);
                end
                if ((dut.u_ldk_top.u_tinyriscv_soc_top.u_iic_dk.iic_tick == 1'b1) &&
                    (dut.u_ldk_top.u_tinyriscv_soc_top.u_iic_dk.scl_phrase == 2'b01) &&
                    ((dut.u_ldk_top.u_tinyriscv_soc_top.u_iic_dk.iic_cs == 5'd3) ||
                     (dut.u_ldk_top.u_tinyriscv_soc_top.u_iic_dk.iic_cs == 5'd10) ||
                     (dut.u_ldk_top.u_tinyriscv_soc_top.u_iic_dk.iic_cs == 5'd12))) begin
                    $display("TRACE_LDK_SAMPLE cycle=%0d state=%0d bit=%0d sda=%b force_low=%b data=0x%04x",
                             cycle_count,
                             dut.u_ldk_top.u_tinyriscv_soc_top.u_iic_dk.iic_cs,
                             dut.u_ldk_top.u_tinyriscv_soc_top.u_iic_dk.sda_counter,
                             io_sda,
                             ldk_lm75_sda_low,
                             dut.u_ldk_top.u_tinyriscv_soc_top.u_iic_dk.data_out_reg[15:0]);
                end
            end

            if (test_kind == "BASIC") begin
                if (active_x26 == 32'h1) begin
                    if (finish_wait < 0) begin
                        finish_wait <= 200;
                    end else if (finish_wait > 0) begin
                        finish_wait <= finish_wait - 1;
                    end else if (active_x27 == 32'h1) begin
                        $display("TEST_PASS chip_sel=%0d kind=BASIC cycles=%0d x26=0x%08x x27=0x%08x succ=%b over=%b",
                                 chip_sel, cycle_count, active_x26, active_x27, succ, over);
                        $finish;
                    end else begin
                        $fatal(1, "TEST_FAIL chip_sel=%0d kind=BASIC x26=0x%08x x27=0x%08x succ=%b",
                               chip_sel, active_x26, active_x27, succ);
                    end
                end
            end else if (test_kind == "PWM") begin
                if ((pwm_seen_high == 4'hf) && (pwm_seen_low == 4'hf)) begin
                    $display("TEST_PASS chip_sel=%0d kind=PWM cycles=%0d seen_high=0x%x seen_low=0x%x pwm_o=0x%x x14=0x%08x",
                             chip_sel, cycle_count, pwm_seen_high, pwm_seen_low, pwm_o, active_x14);
                    $finish;
                end
            end

            if (cycle_count >= max_cycles) begin
                $fatal(1, "TEST_TIMEOUT chip_sel=%0d kind=%0s cycles=%0d x14=0x%08x x26=0x%08x x27=0x%08x uart_count=%0d pwm_seen_high=0x%x pwm_seen_low=0x%x sy_pc=0x%08x sy_ex_inst=0x%08x sy_ex_addr=0x%08x sy_iic_state=0x%x sy_iic_data=0x%08x sy_bridge_state=0x%x sy_bridge_done=%b sy_bridge_done_wait=%b sy_bridge_same_req=%b sy_bridge_hold=%b sy_fpga_bridge_state=0x%x",
                       chip_sel, test_kind, cycle_count, active_x14, active_x26,
                       active_x27, uart_count, pwm_seen_high, pwm_seen_low,
                       sy_pc, sy_ex_inst, sy_ex_addr, sy_iic_state, sy_iic_data,
                       sy_bridge_state, sy_bridge_done, sy_bridge_done_wait,
                       sy_bridge_same_req, sy_bridge_hold, sy_fpga_bridge_state);
            end
        end
    end

    wire lhr_uart_event = dut.u_lhr_top.u_chip.uart_0.tx_data_valid;
    wire[7:0] lhr_uart_byte = dut.u_lhr_top.u_chip.uart_0.tx_data;
    wire ldk_uart_event = dut.u_ldk_top.u_tinyriscv_soc_top.uart_0.tx_data_valid;
    wire[7:0] ldk_uart_byte = dut.u_ldk_top.u_tinyriscv_soc_top.uart_0.tx_data;
    wire wje_uart_event = dut.u_wje_top.u_soc.uart_0.tx_data_valid;
    wire[7:0] wje_uart_byte = dut.u_wje_top.u_soc.uart_0.tx_data;
    wire sy_uart_event = dut.u_sy_top.tinyriscv_soc_top_0.uart_0.tx_data_valid;
    wire[7:0] sy_uart_byte = dut.u_sy_top.tinyriscv_soc_top_0.uart_0.tx_data;

    wire uart_tx_event = (chip_sel == 3'd0) ? lhr_uart_event :
                         (chip_sel == 3'd1) ? ldk_uart_event :
                         (chip_sel == 3'd2) ? wje_uart_event :
                                               sy_uart_event;
    wire[7:0] uart_tx_byte = (chip_sel == 3'd0) ? lhr_uart_byte :
                             (chip_sel == 3'd1) ? ldk_uart_byte :
                             (chip_sel == 3'd2) ? wje_uart_byte :
                                                   sy_uart_byte;

    wire[15:0] ldk_lm75_word = 16'h1900;
    wire[4:0] ldk_iic_state = dut.u_ldk_top.u_tinyriscv_soc_top.u_iic_dk.iic_cs;
    wire[3:0] ldk_iic_bit = dut.u_ldk_top.u_tinyriscv_soc_top.u_iic_dk.sda_counter;
    wire ldk_iic_ack_state = (ldk_iic_state == 5'd3) ||
                             (ldk_iic_state == 5'd5) ||
                             (ldk_iic_state == 5'd7) ||
                             (ldk_iic_state == 5'd9);
    wire ldk_iic_rd_hi_zero = (ldk_iic_state == 5'd10) &&
                              (ldk_lm75_word[15 - ldk_iic_bit] == 1'b0);
    wire ldk_iic_rd_lo_zero = (ldk_iic_state == 5'd12) &&
                              (ldk_lm75_word[7 - ldk_iic_bit] == 1'b0);
    assign ldk_lm75_sda_low = (chip_sel == 3'd1) &&
                              (ldk_iic_ack_state ||
                               ldk_iic_rd_hi_zero ||
                               ldk_iic_rd_lo_zero);

    tinyriscv_merge_top dut(
        .clk(clk),
        .rst(rst),
        .chip_sel(chip_sel),
        .over(over),
        .succ(succ),
        .uart_debug_pin(1'b0),
        .uart_tx_pin(uart_tx_pin),
        .uart_rx_pin(1'b1),
        .pwm_o(pwm_o),
        .io_scl(io_scl),
        .io_sda(io_sda)
    );

    lm75_slave_model #(
        .TEMP_REG_VALUE(16'h1900)
    ) u_lm75_slave (
        .sys_clk(clk),
        .rst_n(rst),
        .hw_addr(3'b000),
        .scl_i(io_scl),
        .sda_i(io_sda),
        .sda_o(lm75_sda_o),
        .sda_oe(lm75_sda_oe)
    );

endmodule
