`timescale 1ns/1ps

`include "tb/vcs_fsdb_dump.vh"

/*
 * Compact, toolchain-independent RV32I test programs for all four cores.
 * Programs are assembled with the encoding helpers below and loaded into
 * the one shared 256-word FPGA ROM.
 */
module merged_rv32i_directed_tb;

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
    integer program_words;
    integer errors;
    integer i;
    integer active_cycles;
    reg xz_seen;
    reg[255:0] test_name;
    reg[1023:0] vcd_path;

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

    function automatic [31:0] enc_r;
        input[6:0] funct7;
        input[4:0] rs2;
        input[4:0] rs1;
        input[2:0] funct3;
        input[4:0] rd;
        begin
            enc_r = {funct7, rs2, rs1, funct3, rd, 7'b0110011};
        end
    endfunction

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

    function automatic [31:0] enc_shift_i;
        input[6:0] funct7;
        input[4:0] shamt;
        input[4:0] rs1;
        input[2:0] funct3;
        input[4:0] rd;
        begin
            enc_shift_i = {funct7, shamt, rs1, funct3, rd, 7'b0010011};
        end
    endfunction

    function automatic [31:0] enc_s;
        input signed[31:0] imm;
        input[4:0] rs2;
        input[4:0] rs1;
        input[2:0] funct3;
        begin
            enc_s = {imm[11:5], rs2, rs1, funct3, imm[4:0], 7'b0100011};
        end
    endfunction

    function automatic [31:0] enc_b;
        input signed[31:0] imm;
        input[4:0] rs2;
        input[4:0] rs1;
        input[2:0] funct3;
        begin
            enc_b = {imm[12], imm[10:5], rs2, rs1, funct3,
                     imm[4:1], imm[11], 7'b1100011};
        end
    endfunction

    function automatic [31:0] enc_u;
        input[19:0] upper;
        input[4:0] rd;
        input[6:0] opcode;
        begin
            enc_u = {upper, rd, opcode};
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

    task automatic emit;
        input[31:0] instruction;
        begin
            if (program_words >= 256) begin
                $display("TEST_FAIL test=%s core=%0d reason=rom_overflow", test_name, core_id);
                $finish;
            end
            dut.u_bridge_bank.u_shared_memory.rom_mem[program_words] = instruction;
            program_words = program_words + 1;
        end
    endtask

    task automatic emit_finish;
        begin
            emit(enc_i(1, 5'd0, 3'b000, 5'd27, 7'b0010011));
            emit(enc_i(1, 5'd0, 3'b000, 5'd26, 7'b0010011));
            emit(enc_j(0, 5'd0));
        end
    endtask

    task automatic build_alu;
        begin
            emit(enc_i(5,  5'd0, 3'b000, 5'd1,  7'b0010011));
            emit(enc_i(3,  5'd0, 3'b000, 5'd2,  7'b0010011));
            emit(enc_i(-3, 5'd0, 3'b000, 5'd28, 7'b0010011));
            emit(enc_r(7'h00, 5'd2,  5'd1,  3'b000, 5'd3));
            emit(enc_r(7'h20, 5'd2,  5'd1,  3'b000, 5'd4));
            emit(enc_r(7'h00, 5'd2,  5'd1,  3'b001, 5'd5));
            emit(enc_r(7'h00, 5'd1,  5'd28, 3'b010, 5'd6));
            emit(enc_r(7'h00, 5'd1,  5'd28, 3'b011, 5'd7));
            emit(enc_r(7'h00, 5'd2,  5'd1,  3'b100, 5'd8));
            emit(enc_r(7'h00, 5'd2,  5'd28, 3'b101, 5'd9));
            emit(enc_r(7'h20, 5'd2,  5'd28, 3'b101, 5'd10));
            emit(enc_r(7'h00, 5'd2,  5'd1,  3'b110, 5'd11));
            emit(enc_r(7'h00, 5'd2,  5'd1,  3'b111, 5'd12));
            emit(enc_i(-5,  5'd1,  3'b000, 5'd13, 7'b0010011));
            emit(enc_i(-2,  5'd28, 3'b010, 5'd14, 7'b0010011));
            emit(enc_i(-1,  5'd1,  3'b011, 5'd15, 7'b0010011));
            emit(enc_i(-1,  5'd1,  3'b100, 5'd16, 7'b0010011));
            emit(enc_i(12'h120, 5'd1, 3'b110, 5'd17, 7'b0010011));
            emit(enc_i(12'h0ff, 5'd28, 3'b111, 5'd18, 7'b0010011));
            emit(enc_shift_i(7'h00, 5'd4, 5'd1, 3'b001, 5'd19));
            emit(enc_shift_i(7'h00, 5'd4, 5'd28, 3'b101, 5'd20));
            emit(enc_shift_i(7'h20, 5'd4, 5'd28, 3'b101, 5'd21));
            emit(enc_i(123, 5'd0, 3'b000, 5'd0, 7'b0010011));
            emit(enc_r(7'h00, 5'd1, 5'd0, 3'b000, 5'd22));
            emit_finish();
        end
    endtask

    task automatic build_load_store;
        begin
            emit(enc_u(20'h10000, 5'd1, 7'b0110111));
            emit(enc_u(20'ha1b2c, 5'd2, 7'b0110111));
            emit(enc_i(12'h3d4, 5'd2, 3'b000, 5'd2, 7'b0010011));
            emit(enc_s(0, 5'd2, 5'd1, 3'b010));
            emit(enc_i(0, 5'd1, 3'b000, 5'd3, 7'b0000011));
            emit(enc_i(0, 5'd1, 3'b100, 5'd4, 7'b0000011));
            emit(enc_i(1, 5'd1, 3'b000, 5'd5, 7'b0000011));
            emit(enc_i(2, 5'd1, 3'b100, 5'd6, 7'b0000011));
            emit(enc_i(0, 5'd1, 3'b001, 5'd7, 7'b0000011));
            emit(enc_i(0, 5'd1, 3'b101, 5'd8, 7'b0000011));
            emit(enc_i(2, 5'd1, 3'b001, 5'd9, 7'b0000011));
            emit(enc_i(2, 5'd1, 3'b101, 5'd10, 7'b0000011));
            emit(enc_i(0, 5'd1, 3'b010, 5'd11, 7'b0000011));
            emit(enc_i(8'h11, 5'd0, 3'b000, 5'd12, 7'b0010011));
            emit(enc_s(0, 5'd12, 5'd1, 3'b000));
            emit(enc_i(8'h22, 5'd0, 3'b000, 5'd12, 7'b0010011));
            emit(enc_s(1, 5'd12, 5'd1, 3'b000));
            emit(enc_i(8'h33, 5'd0, 3'b000, 5'd12, 7'b0010011));
            emit(enc_s(2, 5'd12, 5'd1, 3'b000));
            emit(enc_i(8'h44, 5'd0, 3'b000, 5'd12, 7'b0010011));
            emit(enc_s(3, 5'd12, 5'd1, 3'b000));
            emit(enc_i(0, 5'd1, 3'b010, 5'd13, 7'b0000011));
            emit(enc_u(20'h00005, 5'd14, 7'b0110111));
            emit(enc_i(12'h566, 5'd14, 3'b000, 5'd14, 7'b0010011));
            emit(enc_s(0, 5'd14, 5'd1, 3'b001));
            emit(enc_u(20'h00007, 5'd15, 7'b0110111));
            emit(enc_i(12'h788, 5'd15, 3'b000, 5'd15, 7'b0010011));
            emit(enc_s(2, 5'd15, 5'd1, 3'b001));
            emit(enc_i(0, 5'd1, 3'b010, 5'd16, 7'b0000011));
            emit(enc_u(20'hdeadc, 5'd17, 7'b0110111));
            emit(enc_i(-273, 5'd17, 3'b000, 5'd17, 7'b0010011));
            emit(enc_s(4, 5'd17, 5'd1, 3'b010));
            emit(enc_i(4, 5'd1, 3'b010, 5'd18, 7'b0000011));
            emit(enc_u(20'h10004, 5'd19, 7'b0110111));
            emit(enc_i(-4, 5'd19, 3'b000, 5'd19, 7'b0010011));
            emit(enc_s(0, 5'd17, 5'd19, 3'b010));
            emit(enc_i(0, 5'd19, 3'b010, 5'd20, 7'b0000011));
            emit(enc_i(60, 5'd1, 3'b000, 5'd21, 7'b0010011));
            emit(enc_i(0, 5'd21, 3'b010, 5'd22, 7'b0000011));
            emit(enc_i(4, 5'd1, 3'b010, 5'd23, 7'b0000011));
            emit(enc_i(1, 5'd23, 3'b000, 5'd24, 7'b0010011));
            emit_finish();
        end
    endtask

    task automatic branch_taken;
        input[2:0] funct3;
        input[4:0] rs1;
        input[4:0] rs2;
        input[4:0] dest;
        begin
            emit(enc_i(1, 5'd0, 3'b000, dest, 7'b0010011));
            emit(enc_b(8, rs2, rs1, funct3));
            emit(enc_i(99, 5'd0, 3'b000, dest, 7'b0010011));
            emit(32'h0000_0013);
        end
    endtask

    task automatic branch_not_taken;
        input[2:0] funct3;
        input[4:0] rs1;
        input[4:0] rs2;
        input[4:0] dest;
        begin
            emit(enc_i(1, 5'd0, 3'b000, dest, 7'b0010011));
            emit(enc_b(8, rs2, rs1, funct3));
            emit(enc_i(1, dest, 3'b000, dest, 7'b0010011));
            emit(32'h0000_0013);
        end
    endtask

    task automatic build_branch;
        begin
            emit(enc_i(-1, 5'd0, 3'b000, 5'd1, 7'b0010011));
            emit(enc_i( 1, 5'd0, 3'b000, 5'd2, 7'b0010011));
            branch_taken(3'b000, 5'd1, 5'd1, 5'd3);  // BEQ
            branch_taken(3'b001, 5'd1, 5'd2, 5'd4);  // BNE
            branch_taken(3'b100, 5'd1, 5'd2, 5'd5);  // BLT
            branch_taken(3'b101, 5'd2, 5'd1, 5'd6);  // BGE
            branch_taken(3'b110, 5'd2, 5'd1, 5'd7);  // BLTU
            branch_taken(3'b111, 5'd1, 5'd2, 5'd8);  // BGEU
            branch_not_taken(3'b000, 5'd1, 5'd2, 5'd9);
            branch_not_taken(3'b001, 5'd1, 5'd1, 5'd10);
            branch_not_taken(3'b100, 5'd2, 5'd1, 5'd11);
            branch_not_taken(3'b101, 5'd1, 5'd2, 5'd12);
            branch_not_taken(3'b110, 5'd1, 5'd2, 5'd13);
            branch_not_taken(3'b111, 5'd2, 5'd1, 5'd14);
            emit_finish();
        end
    endtask

    task automatic build_jump_upper;
        begin
            emit(enc_u(20'h12345, 5'd3, 7'b0110111));
            emit(enc_u(20'h00001, 5'd4, 7'b0010111));
            emit(32'h0000_000f);                         // FENCE
            emit(enc_j(8, 5'd5));                        // PC 12 -> 20
            emit(enc_i(99, 5'd0, 3'b000, 5'd6, 7'b0010011));
            emit(enc_i(1, 5'd0, 3'b000, 5'd6, 7'b0010011));
            emit(enc_i(41, 5'd0, 3'b000, 5'd7, 7'b0010011));
            emit(enc_i(0, 5'd7, 3'b000, 5'd8, 7'b1100111)); // JALR, bit 0 cleared
            emit(enc_i(99, 5'd0, 3'b000, 5'd9, 7'b0010011));
            emit(32'h0000_0013);                         // NOP
            emit(enc_i(1, 5'd0, 3'b000, 5'd9, 7'b0010011));
            emit(enc_i(123, 5'd0, 3'b000, 5'd0, 7'b0010011));
            emit(enc_i(7, 5'd0, 3'b000, 5'd10, 7'b0010011));
            emit_finish();
        end
    endtask

    task automatic build_hazards;
        begin
            emit(enc_i(2047, 5'd0, 3'b000, 5'd1, 7'b0010011));
            emit(enc_i(-2048, 5'd0, 3'b000, 5'd2, 7'b0010011));
            emit(enc_i(1, 5'd0, 3'b000, 5'd3, 7'b0010011));
            emit(enc_i(2, 5'd3, 3'b000, 5'd4, 7'b0010011));
            emit(enc_r(7'h00, 5'd3, 5'd4, 3'b000, 5'd5));
            emit(enc_i(1, 5'd0, 3'b000, 5'd6, 7'b0010011));
            emit(enc_b(8, 5'd6, 5'd6, 3'b000));
            emit(enc_i(99, 5'd0, 3'b000, 5'd7, 7'b0010011));
            emit(enc_b(8, 5'd0, 5'd6, 3'b001));
            emit(enc_i(99, 5'd0, 3'b000, 5'd8, 7'b0010011));
            emit(enc_i(1, 5'd0, 3'b000, 5'd7, 7'b0010011));
            emit(enc_i(1, 5'd0, 3'b000, 5'd8, 7'b0010011));
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

    task automatic check_alu;
        begin
            check_reg(0,  32'h00000000, "x0");
            check_reg(3,  32'h00000008, "ADD");
            check_reg(4,  32'h00000002, "SUB");
            check_reg(5,  32'h00000028, "SLL");
            check_reg(6,  32'h00000001, "SLT");
            check_reg(7,  32'h00000000, "SLTU");
            check_reg(8,  32'h00000006, "XOR");
            check_reg(9,  32'h1fffffff, "SRL");
            check_reg(10, 32'hffffffff, "SRA");
            check_reg(11, 32'h00000007, "OR");
            check_reg(12, 32'h00000001, "AND");
            check_reg(13, 32'h00000000, "ADDI");
            check_reg(14, 32'h00000001, "SLTI");
            check_reg(15, 32'h00000001, "SLTIU");
            check_reg(16, 32'hfffffffa, "XORI");
            check_reg(17, 32'h00000125, "ORI");
            check_reg(18, 32'h000000fd, "ANDI");
            check_reg(19, 32'h00000050, "SLLI");
            check_reg(20, 32'h0fffffff, "SRLI");
            check_reg(21, 32'hffffffff, "SRAI");
            check_reg(22, 32'h00000005, "x0_read");
        end
    endtask

    task automatic check_load_store;
        begin
            check_reg(3,  32'hffffffd4, "LB_lane0_sign");
            check_reg(4,  32'h000000d4, "LBU_lane0");
            check_reg(5,  32'hffffffc3, "LB_lane1_sign");
            check_reg(6,  32'h000000b2, "LBU_lane2");
            check_reg(7,  32'hffffc3d4, "LH_low_sign");
            check_reg(8,  32'h0000c3d4, "LHU_low");
            check_reg(9,  32'hffffa1b2, "LH_high_sign");
            check_reg(10, 32'h0000a1b2, "LHU_high");
            check_reg(11, 32'ha1b2c3d4, "LW");
            check_reg(13, 32'h44332211, "SB_all_lanes");
            check_reg(16, 32'h77885566, "SH_both_lanes");
            check_reg(18, 32'hdeadbeef, "SW_LW");
            check_reg(20, 32'hdeadbeef, "alias_high_address");
            check_reg(22, 32'hdeadbeef, "alias_low_address");
            check_reg(24, 32'hdeadbef0, "load_use");
            if (dut.u_bridge_bank.u_shared_memory.ram_mem[0] !== 32'h77885566) begin
                errors = errors + 1;
                $display("ASSERT_FAIL test=%s core=%0d item=RAM_word0 got=%08x expected=77885566 cycle=%0d pc=%08x",
                         test_name, core_id,
                         dut.u_bridge_bank.u_shared_memory.ram_mem[0], cycles, current_pc);
            end
            if (dut.u_bridge_bank.u_shared_memory.ram_mem[15] !== 32'hdeadbeef) begin
                errors = errors + 1;
                $display("ASSERT_FAIL test=%s core=%0d item=RAM_alias_word15 got=%08x expected=deadbeef cycle=%0d pc=%08x",
                         test_name, core_id,
                         dut.u_bridge_bank.u_shared_memory.ram_mem[15], cycles, current_pc);
            end
        end
    endtask

    task automatic check_branch;
        begin
            for (i = 3; i <= 8; i = i + 1) check_reg(i, 32'd1, "branch_taken");
            for (i = 9; i <= 14; i = i + 1) check_reg(i, 32'd2, "branch_not_taken");
        end
    endtask

    task automatic check_jump_upper;
        begin
            check_reg(3, 32'h12345000, "LUI");
            check_reg(4, 32'h00001004, "AUIPC");
            check_reg(5, 32'h00000010, "JAL_link");
            check_reg(6, 32'h00000001, "JAL_target");
            check_reg(7, 32'h00000029, "JALR_source_odd");
            check_reg(8, 32'h00000020, "JALR_link");
            check_reg(9, 32'h00000001, "JALR_target_bit0_clear");
            check_reg(10, 32'h00000007, "FENCE_NOP_x0");
            check_reg(0, 32'h00000000, "x0_constant");
        end
    endtask

    task automatic check_hazards;
        begin
            check_reg(1, 32'h000007ff, "positive_imm_boundary");
            check_reg(2, 32'hfffff800, "negative_imm_boundary");
            check_reg(3, 32'h00000001, "forward_source");
            check_reg(4, 32'h00000003, "forward_I");
            check_reg(5, 32'h00000004, "forward_R");
            check_reg(7, 32'h00000001, "consecutive_branch_1");
            check_reg(8, 32'h00000001, "consecutive_branch_2");
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = 1'b0;
        chip_sel = 2'd0;
        uart_debug_pin = 1'b0;
        uart_rx_pin = 1'b1;
        program_words = 0;
        errors = 0;
        active_cycles = 0;
        xz_seen = 1'b0;
        test_name = "rv32i_alu";

        if (!$value$plusargs("CORE=%d", core_id)) begin
            $display("TEST_FAIL reason=missing_CORE_plusarg");
            $finish;
        end
        if (!$value$plusargs("TEST=%s", test_name)) begin
            $display("TEST_FAIL reason=missing_TEST_plusarg");
            $finish;
        end
        if ((core_id < 0) || (core_id > 3)) begin
            $display("TEST_FAIL test=%s reason=invalid_CORE core=%0d", test_name, core_id);
            $finish;
        end
        if ($value$plusargs("VCD=%s", vcd_path)) begin
            `MERGED_DUMPFILE(vcd_path);
            `MERGED_DUMPVARS(dut);
            `MERGED_DUMPVARS(dut.u_chip.u_shared_regs.regs[26]);
            `MERGED_DUMPVARS(dut.u_chip.u_shared_regs.regs[27]);
            `MERGED_DUMPVARS(dut.u_bridge_bank.u_shared_memory.ram_mem[0]);
            `MERGED_DUMPVARS(dut.u_bridge_bank.u_shared_memory.ram_mem[15]);
        end

        chip_sel = core_id[1:0];
        for (i = 0; i < 256; i = i + 1) begin
            dut.u_bridge_bank.u_shared_memory.rom_mem[i] = 32'h0000_0013;
        end

        if (test_name == "rv32i_alu") begin
            build_alu();
        end else if (test_name == "load_store_alias") begin
            build_load_store();
        end else if (test_name == "rv32i_branch") begin
            build_branch();
        end else if (test_name == "rv32i_jump_upper") begin
            build_jump_upper();
        end else if (test_name == "rv32i_hazards") begin
            build_hazards();
        end else begin
            $display("TEST_FAIL test=%s core=%0d reason=unknown_TEST", test_name, core_id);
            $finish;
        end

        repeat (5) @(posedge clk);
        rst <= 1'b1;

        for (cycles = 0; cycles < 400000; cycles = cycles + 1) begin
            @(posedge clk);
            if (!dut.u_chip.shared_rst) active_cycles = 0;
            else active_cycles = active_cycles + 1;
            // Ignore the defined reset-release fill interval; audit active
            // execution after every pipeline and adapter has clocked state.
            if ((active_cycles > 5) && !xz_seen &&
                ($isunknown(succ) || $isunknown(uart_tx_pin) ||
                 $isunknown(pwm_o) || $isunknown(current_pc) ||
                 $isunknown(current_inst) ||
                 $isunknown(dut.u_chip.u_shared_regs.regs[26]) ||
                 $isunknown(dut.u_chip.u_shared_regs.regs[27]) ||
                 $isunknown(dut.u_bridge_bank.selected_rom_we) ||
                 $isunknown(dut.u_bridge_bank.selected_ram_we))) begin
                xz_seen = 1'b1;
                errors = errors + 1;
                $display("ASSERT_FAIL test=%s core=%0d item=unexpected_XZ cycle=%0d pc=%08x inst=%08x flags=%b%b%b%b%b%b%b%b%b",
                         test_name, core_id, cycles, current_pc, current_inst,
                         $isunknown(succ), $isunknown(uart_tx_pin),
                         $isunknown(pwm_o), $isunknown(current_pc),
                         $isunknown(current_inst),
                         $isunknown(dut.u_chip.u_shared_regs.regs[26]),
                         $isunknown(dut.u_chip.u_shared_regs.regs[27]),
                         $isunknown(dut.u_bridge_bank.selected_rom_we),
                         $isunknown(dut.u_bridge_bank.selected_ram_we));
            end
            if (dut.u_chip.u_shared_regs.regs[26] === 32'h00000001) begin
                repeat (20) @(posedge clk);
                if (test_name == "rv32i_alu") check_alu();
                else if (test_name == "load_store_alias") check_load_store();
                else if (test_name == "rv32i_branch") check_branch();
                else if (test_name == "rv32i_jump_upper") check_jump_upper();
                else if (test_name == "rv32i_hazards") check_hazards();

                check_reg(26, 32'h00000001, "completion_x26");
                check_reg(27, 32'h00000001, "success_x27");
                if (succ !== 1'b0) begin
                    errors = errors + 1;
                    $display("ASSERT_FAIL test=%s core=%0d item=succ got=%b expected=0 cycle=%0d pc=%08x",
                             test_name, core_id, succ, cycles, current_pc);
                end

                if (errors == 0) begin
                    $display("TEST_PASS test=%s core=%0d assertions=all program_words=%0d cycles=%0d pc=%08x",
                             test_name, core_id, program_words, cycles, current_pc);
                end else begin
                    $display("TEST_FAIL test=%s core=%0d errors=%0d program_words=%0d cycles=%0d pc=%08x inst=%08x",
                             test_name, core_id, errors, program_words,
                             cycles, current_pc, current_inst);
                end
                $finish;
            end
        end

        $display("TEST_FAIL test=%s core=%0d reason=timeout cycles=%0d x26=%08x x27=%08x succ=%b pc=%08x inst=%08x",
                 test_name, core_id, cycles,
                 dut.u_chip.u_shared_regs.regs[26],
                 dut.u_chip.u_shared_regs.regs[27], succ,
                 current_pc, current_inst);
        $finish;
    end

endmodule
