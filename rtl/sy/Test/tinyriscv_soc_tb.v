`timescale 1 ns / 1 ps

`include "defines.v"

// select one option only
`define TEST_PROG  1
//`define TEST_JTAG  1


// testbench module
module tinyriscv_soc_tb;

    reg clk;
    reg rst;
    wire[7:0] chip_bridge_data;
    wire[7:0] fpga_bridge_data;
    wire[3:0] pwm;
    tri1 i2c_scl;
    tri1 i2c_sda;


    always #10 clk = ~clk;     // 50MHz

    wire[`RegBus] x3 = tinyriscv_soc_top_0.u_tinyriscv.u_regs.regs[3];
    wire[`RegBus] x26 = tinyriscv_soc_top_0.u_tinyriscv.u_regs.regs[26];
    wire[`RegBus] x27 = tinyriscv_soc_top_0.u_tinyriscv.u_regs.regs[27];

    integer r;

`ifdef TEST_JTAG
    reg TCK;
    reg TMS;
    reg TDI;
    wire TDO;

    integer i;
    reg[39:0] shift_reg;
    reg in;
    wire[39:0] req_data = tinyriscv_soc_top_0.u_jtag_top.u_jtag_driver.dtm_req_data;
    wire[4:0] ir_reg = tinyriscv_soc_top_0.u_jtag_top.u_jtag_driver.ir_reg;
    wire dtm_req_valid = tinyriscv_soc_top_0.u_jtag_top.u_jtag_driver.dtm_req_valid;
    wire[31:0] dmstatus = tinyriscv_soc_top_0.u_jtag_top.u_jtag_dm.dmstatus;
`endif

    initial begin
        clk = 0;
        rst = `RstEnable;
`ifdef TEST_JTAG
        TCK = 1;
        TMS = 1;
        TDI = 1;
`endif
        $display("test running...");
        #40
        rst = `RstDisable;
        #200

`ifdef TEST_PROG
        wait(x26 == 32'b1)   // wait sim end, when x26 == 1
        #1000
        if (x27 == 32'b1) begin
            $display("~~~~~~~~~~~~~~~~~~~ TEST_PASS ~~~~~~~~~~~~~~~~~~~");
            $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
            $display("~~~~~~~~~ #####     ##     ####    #### ~~~~~~~~~");
            $display("~~~~~~~~~ #    #   #  #   #       #     ~~~~~~~~~");
            $display("~~~~~~~~~ #    #  #    #   ####    #### ~~~~~~~~~");
            $display("~~~~~~~~~ #####   ######       #       #~~~~~~~~~");
            $display("~~~~~~~~~ #       #    #  #    #  #    #~~~~~~~~~");
            $display("~~~~~~~~~ #       #    #   ####    #### ~~~~~~~~~");
            $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
        end else begin
            $display("~~~~~~~~~~~~~~~~~~~ TEST_FAIL ~~~~~~~~~~~~~~~~~~~~");
            $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
            $display("~~~~~~~~~~######    ##       #    #     ~~~~~~~~~~");
            $display("~~~~~~~~~~#        #  #      #    #     ~~~~~~~~~~");
            $display("~~~~~~~~~~#####   #    #     #    #     ~~~~~~~~~~");
            $display("~~~~~~~~~~#       ######     #    #     ~~~~~~~~~~");
            $display("~~~~~~~~~~#       #    #     #    #     ~~~~~~~~~~");
            $display("~~~~~~~~~~#       #    #     #    ######~~~~~~~~~~");
            $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
            $display("fail testnum = %2d", x3);
            for (r = 0; r < 32; r = r + 1)
                $display("x%2d = 0x%x", r, tinyriscv_soc_top_0.u_tinyriscv.u_regs.regs[r]);
        end
`endif

`ifdef TEST_JTAG
        // reset
        for (i = 0; i < 8; i++) begin
            TMS = 1;
            TCK = 0;
            #100
            TCK = 1;
            #100
            TCK = 0;
        end

        // IR
        shift_reg = 40'b10001;

        // IDLE
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // SELECT-DR
        TMS = 1;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // SELECT-IR
        TMS = 1;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // CAPTURE-IR
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // SHIFT-IR
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // SHIFT-IR & EXIT1-IR
        for (i = 5; i > 0; i--) begin
            if (shift_reg[0] == 1'b1)
                TDI = 1'b1;
            else
                TDI = 1'b0;

            if (i == 1)
                TMS = 1;

            TCK = 0;
            #100
            in = TDO;
            TCK = 1;
            #100
            TCK = 0;

            shift_reg = {{(35){1'b0}}, in, shift_reg[4:1]};
        end

        // PAUSE-IR
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // EXIT2-IR
        TMS = 1;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // UPDATE-IR
        TMS = 1;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // IDLE
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // IDLE
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // IDLE
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // IDLE
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // dmi write
        shift_reg = {6'h10, {(32){1'b0}}, 2'b10};

        // SELECT-DR
        TMS = 1;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // CAPTURE-DR
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // SHIFT-DR
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // SHIFT-DR & EXIT1-DR
        for (i = 40; i > 0; i--) begin
            if (shift_reg[0] == 1'b1)
                TDI = 1'b1;
            else
                TDI = 1'b0;

            if (i == 1)
                TMS = 1;

            TCK = 0;
            #100
            in = TDO;
            TCK = 1;
            #100
            TCK = 0;

            shift_reg = {in, shift_reg[39:1]};
        end

        // PAUSE-DR
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // EXIT2-DR
        TMS = 1;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // UPDATE-DR
        TMS = 1;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // IDLE
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        $display("ir_reg = 0x%x", ir_reg);
        $display("dtm_req_valid = %d", dtm_req_valid);
        $display("req_data = 0x%x", req_data);

        // IDLE
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // IDLE
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        $display("dmstatus = 0x%x", dmstatus);

        // IDLE
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // SELECT-DR
        TMS = 1;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // dmi read
        shift_reg = {6'h11, {(32){1'b0}}, 2'b01};

        // CAPTURE-DR
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // SHIFT-DR
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // SHIFT-DR & EXIT1-DR
        for (i = 40; i > 0; i--) begin
            if (shift_reg[0] == 1'b1)
                TDI = 1'b1;
            else
                TDI = 1'b0;

            if (i == 1)
                TMS = 1;

            TCK = 0;
            #100
            in = TDO;
            TCK = 1;
            #100
            TCK = 0;

            shift_reg = {in, shift_reg[39:1]};
        end

        // PAUSE-DR
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // EXIT2-DR
        TMS = 1;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // UPDATE-DR
        TMS = 1;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // IDLE
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // IDLE
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // IDLE
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // IDLE
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // SELECT-DR
        TMS = 1;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // dmi read
        shift_reg = {6'h11, {(32){1'b0}}, 2'b00};

        // CAPTURE-DR
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // SHIFT-DR
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // SHIFT-DR & EXIT1-DR
        for (i = 40; i > 0; i--) begin
            if (shift_reg[0] == 1'b1)
                TDI = 1'b1;
            else
                TDI = 1'b0;

            if (i == 1)
                TMS = 1;

            TCK = 0;
            #100
            in = TDO;
            TCK = 1;
            #100
            TCK = 0;

            shift_reg = {in, shift_reg[39:1]};
        end

        #100

        $display("shift_reg = 0x%x", shift_reg[33:2]);

        if (dmstatus == shift_reg[33:2]) begin
            $display("######################");
            $display("### jtag test pass ###");
            $display("######################");
        end else begin
            $display("######################");
            $display("!!! jtag test fail !!!");
            $display("######################");
        end
`endif

  //      $finish;
    end

    // sim timeout
    initial begin
        #2000000
        $display("Time Out.");
        //$finish;
    end

    // read mem data
    initial begin
  
    //basic
    //$readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_add.data", bridge_fpga_0.u_rom_ext._rom);
   /*  $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_andi.data", bridge_fpga_0.u_rom_ext._rom);
     $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_auipc.data", bridge_fpga_0.u_rom_ext._rom);
     $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_beq.data", bridge_fpga_0.u_rom_ext._rom);
     $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_bge.data", bridge_fpga_0.u_rom_ext._rom);
     $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_bgeu.data", bridge_fpga_0.u_rom_ext._rom);
     $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_blt.data", bridge_fpga_0.u_rom_ext._rom);
     $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_bltu.data", bridge_fpga_0.u_rom_ext._rom);
     $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_bne.data", bridge_fpga_0.u_rom_ext._rom);
     $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_div.data", bridge_fpga_0.u_rom_ext._rom);
     $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_divu.data", bridge_fpga_0.u_rom_ext._rom);
     $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_jal.data", bridge_fpga_0.u_rom_ext._rom);
     $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_jalr.data", bridge_fpga_0.u_rom_ext._rom);
     $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_lui.data", bridge_fpga_0.u_rom_ext._rom);
     $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_or.data", bridge_fpga_0.u_rom_ext._rom);
     $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_rem.data", bridge_fpga_0.u_rom_ext._rom);
     $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_remu.data", bridge_fpga_0.u_rom_ext._rom);
     $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_simple.data", bridge_fpga_0.u_rom_ext._rom);
     $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_slli.data", bridge_fpga_0.u_rom_ext._rom);
     $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_slti.data", bridge_fpga_0.u_rom_ext._rom);
     $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_sltiu.data", bridge_fpga_0.u_rom_ext._rom);
     $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_srai.data", bridge_fpga_0.u_rom_ext._rom);
     $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_srli.data", bridge_fpga_0.u_rom_ext._rom);
     $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_xor.data", bridge_fpga_0.u_rom_ext._rom);
    */
    //extend
        //$readmemh ("D:/projectCH/reference/tinyriscv/tests/Extend_Inst_Example/sID/sID.data", bridge_fpga_0.u_rom_ext._rom);
        //$readmemh ("D:/projectCH/reference/IF.data", bridge_fpga_0.u_rom_ext._rom);
        //$readmemh("D:/projectCH/reference/tinyriscv/tests/Extend_Inst_Example/Temp/Temp.data", bridge_fpga_0.u_rom_ext._rom);
        //$readmemh("D:/projectCH/reference/tinyriscv/tests/Other_Example/PWM/PWM.data", bridge_fpga_0.u_rom_ext._rom);
        
    end

    // generate wave file, used by gtkwave
    initial begin
        $dumpfile("tinyriscv_soc_tb.vcd");
        $dumpvars(0, tinyriscv_soc_tb);
    end

    tinyriscv_soc_top tinyriscv_soc_top_0(
        .clk(clk),
        .rst(rst),
        .uart_debug_pin(1'b0),
        .bridge_data_i(fpga_bridge_data),
        .bridge_data_o(chip_bridge_data),
        .pwm(pwm),
        .i2c_scl(i2c_scl),
        .i2c_sda(i2c_sda)
`ifdef TEST_JTAG
        ,
        .jtag_TCK(TCK),
        .jtag_TMS(TMS),
        .jtag_TDI(TDI),
        .jtag_TDO(TDO)
`endif
    );

    bridge_fpga bridge_fpga_0(
        .clk(clk),
        .rst(rst),
        .bridge_data_i(chip_bridge_data),
        .bridge_data_o(fpga_bridge_data)
    );

endmodule