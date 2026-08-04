`timescale 1ns/1ps

`include "tb/vcs_fsdb_dump.vh"

/* Native chip-side masters against the four shared-memory protocol adapters. */
module merged_bridge_protocol_tb;

    reg clk;
    reg rst;
    reg[1:0] chip_sel;
    wire memory_ready;
    wire[7:0] bank_to_master;
    wire[7:0] master_to_bank;

    integer core_id;
    integer errors;
    integer timeout_count;
    reg[31:0] result;
    reg[31:0] rom_test_data;
    reg[31:0] ram_test_data;
    reg[1023:0] vcd_path;

    reg lhr_req;
    reg lhr_we;
    reg[31:0] lhr_addr;
    reg[31:0] lhr_wdata;
    reg[3:0] lhr_byteen;
    wire[31:0] lhr_rdata;
    wire lhr_ready;
    wire lhr_busy;
    wire lhr_error;
    wire[7:0] lhr_data;

    reg ldk_req;
    reg ldk_we;
    reg[31:0] ldk_addr;
    reg[31:0] ldk_wdata;
    wire[31:0] ldk_rdata;
    wire ldk_ack;
    wire ldk_busy;
    wire[7:0] ldk_data;

    reg sy_rom_req;
    reg sy_rom_we;
    reg sy_ram_req;
    reg sy_ram_we;
    reg[3:0] sy_ram_byteen;
    reg[31:0] sy_addr;
    reg[31:0] sy_wdata;
    wire[31:0] sy_rom_rdata;
    wire[31:0] sy_ram_rdata;
    wire[2:0] sy_rom_hold;
    wire[2:0] sy_ram_hold;
    wire[7:0] sy_data;

    reg wje_rom_req;
    reg wje_rom_we;
    reg wje_ram_req;
    reg wje_ram_we;
    reg[3:0] wje_ram_byteen;
    reg[31:0] wje_addr;
    reg[31:0] wje_wdata;
    wire[31:0] wje_rom_rdata;
    wire[31:0] wje_ram_rdata;
    wire wje_rom_valid;
    wire[31:0] wje_rom_resp_addr;
    wire wje_busy;
    wire[7:0] wje_data;

    wire lhr_master_rst = rst && memory_ready && (chip_sel == 2'd0);
    wire ldk_master_rst = rst && memory_ready && (chip_sel == 2'd1);
    wire sy_master_rst  = rst && memory_ready && (chip_sel == 2'd2);
    wire wje_master_rst = rst && memory_ready && (chip_sel == 2'd3);

    assign master_to_bank = (chip_sel == 2'd0) ? lhr_data :
                            (chip_sel == 2'd1) ? ldk_data :
                            (chip_sel == 2'd2) ? sy_data  : wje_data;

    merged_fpga_bridge_bank dut(
        .clk(clk), .rst(rst), .chip_sel(chip_sel),
        .chip_data_i(master_to_bank), .chip_data_o(bank_to_master),
        .memory_ready_o(memory_ready)
    );

    lhr_ext_mem_bridge u_lhr_master(
        .clk(clk), .rst(lhr_master_rst), .req_i(lhr_req), .we_i(lhr_we),
        .addr_i(lhr_addr), .wdata_i(lhr_wdata), .byteen_i(lhr_byteen),
        .rdata_o(lhr_rdata), .ready_o(lhr_ready), .busy_o(lhr_busy),
        .error_o(lhr_error), .ext_data_o(lhr_data),
        .ext_data_i(bank_to_master)
    );

    ldk_bridge_master u_ldk_master(
        .clk(clk), .rst(ldk_master_rst), .rib_req_i(ldk_req),
        .rib_we_i(ldk_we), .rib_addr_i(ldk_addr),
        .rib_data_i(ldk_wdata), .rib_data_o(ldk_rdata),
        .bmaster_RX_data(bank_to_master), .bmaster_TX_data(ldk_data),
        .rib_ack_o(ldk_ack), .hold_flag_o(ldk_busy)
    );

    sy_bridge u_sy_master(
        .clk(clk), .rst(sy_master_rst),
        .rom_req_i(sy_rom_req), .rom_we_i(sy_rom_we),
        .rom_addr_i(sy_addr), .rom_data_i(sy_wdata),
        .rom_data_o(sy_rom_rdata), .rom_hold_o(sy_rom_hold),
        .ram_req_i(sy_ram_req), .ram_we_i(sy_ram_we),
        .ram_byte_en_i(sy_ram_byteen), .ram_addr_i(sy_addr),
        .ram_data_i(sy_wdata), .ram_data_o(sy_ram_rdata),
        .ram_hold_o(sy_ram_hold), .bridge_data_i(bank_to_master),
        .bridge_data_o(sy_data)
    );

    wje_bridge u_wje_master(
        .clk(clk), .rst(wje_master_rst),
        .rom_req_i(wje_rom_req), .rom_we_i(wje_rom_we),
        .rom_addr_i(wje_addr), .rom_data_i(wje_wdata),
        .rom_data_o(wje_rom_rdata), .rom_resp_valid_o(wje_rom_valid),
        .rom_resp_addr_o(wje_rom_resp_addr),
        .ram_req_i(wje_ram_req), .ram_we_i(wje_ram_we),
        .ram_byte_en_i(wje_ram_byteen), .ram_addr_i(wje_addr),
        .ram_data_i(wje_wdata), .ram_data_o(wje_ram_rdata),
        .fpga_data_i(bank_to_master), .fpga_data_o(wje_data),
        .busy_o(wje_busy)
    );

    always #10 clk = ~clk;

    task automatic clear_requests;
        begin
            lhr_req = 1'b0;
            ldk_req = 1'b0;
            sy_rom_req = 1'b0;
            sy_ram_req = 1'b0;
            wje_rom_req = 1'b0;
            wje_ram_req = 1'b0;
        end
    endtask

    task automatic transact;
        input target_ram;
        input do_write;
        input[31:0] address;
        input[31:0] write_data;
        input[3:0] byte_enable;
        output[31:0] read_data;
        begin
            read_data = 32'h0000_0000;
            timeout_count = 0;
            case (core_id)
                0: begin
                    lhr_we = do_write;
                    lhr_addr = address;
                    lhr_wdata = write_data;
                    lhr_byteen = byte_enable;
                    lhr_req = 1'b1;
                    while (!lhr_ready && (timeout_count < 500)) begin
                        @(posedge clk);
                        timeout_count = timeout_count + 1;
                    end
                    read_data = lhr_rdata;
                    lhr_req = 1'b0;
                    if (lhr_error) errors = errors + 1;
                end
                1: begin
                    ldk_we = do_write;
                    ldk_addr = address;
                    ldk_wdata = write_data;
                    ldk_req = 1'b1;
                    while (!ldk_ack && (timeout_count < 500)) begin
                        @(posedge clk);
                        timeout_count = timeout_count + 1;
                    end
                    read_data = ldk_rdata;
                    ldk_req = 1'b0;
                end
                2: begin
                    sy_rom_we = do_write;
                    sy_ram_we = do_write;
                    sy_addr = address;
                    sy_wdata = write_data;
                    sy_ram_byteen = byte_enable;
                    if (target_ram) sy_ram_req = 1'b1;
                    else sy_rom_req = 1'b1;
                    // The native SY hold drops only after the response is complete.
                    @(posedge clk);
                    while (((target_ram ? sy_ram_hold : sy_rom_hold) != 3'b000) &&
                           (timeout_count < 500)) begin
                        @(posedge clk);
                        timeout_count = timeout_count + 1;
                    end
                    read_data = target_ram ? sy_ram_rdata : sy_rom_rdata;
                    sy_rom_req = 1'b0;
                    sy_ram_req = 1'b0;
                end
                default: begin
                    wje_rom_we = do_write;
                    wje_ram_we = do_write;
                    wje_addr = address;
                    wje_wdata = write_data;
                    wje_ram_byteen = byte_enable;
                    if (target_ram) wje_ram_req = 1'b1;
                    else wje_rom_req = 1'b1;
                    @(posedge clk);
                    while (wje_busy && (timeout_count < 1000)) begin
                        @(posedge clk);
                        timeout_count = timeout_count + 1;
                    end
                    read_data = target_ram ? wje_ram_rdata : wje_rom_rdata;
                    wje_rom_req = 1'b0;
                    wje_ram_req = 1'b0;
                end
            endcase
            if (timeout_count >= ((core_id == 3) ? 1000 : 500)) begin
                errors = errors + 1;
                $display("ASSERT_FAIL test=bridge_protocol core=%0d item=timeout ram=%b write=%b",
                         core_id, target_ram, do_write);
            end
            repeat (4) @(posedge clk);
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = 1'b0;
        chip_sel = 2'd0;
        errors = 0;
        clear_requests();
        lhr_we = 0; lhr_addr = 0; lhr_wdata = 0; lhr_byteen = 4'hf;
        ldk_we = 0; ldk_addr = 0; ldk_wdata = 0;
        sy_rom_we = 0; sy_ram_we = 0; sy_addr = 0; sy_wdata = 0;
        sy_ram_byteen = 4'hf;
        wje_rom_we = 0; wje_ram_we = 0; wje_addr = 0; wje_wdata = 0;
        wje_ram_byteen = 4'hf;

        if ($value$plusargs("VCD=%s", vcd_path)) begin
            `MERGED_DUMPFILE(vcd_path);
            `MERGED_DUMPVARS(dut);
            `MERGED_DUMPVARS(dut.u_shared_memory.rom_mem[8]);
            `MERGED_DUMPVARS(dut.u_shared_memory.ram_mem[0]);
            `MERGED_DUMPVARS(dut.u_shared_memory.ram_mem[15]);
        end

        if (!$value$plusargs("CORE=%d", core_id) ||
            (core_id < 0) || (core_id > 3)) begin
            $display("TEST_FAIL test=bridge_protocol reason=invalid_or_missing_CORE");
            $finish;
        end
        chip_sel = core_id[1:0];
        rom_test_data = 32'hc001_0000 | core_id;
        ram_test_data = 32'h5a00_1000 | core_id;

        repeat (5) @(posedge clk);
        rst = 1'b1;
        wait (memory_ready === 1'b1);
        repeat (3) @(posedge clk);

        transact(1'b0, 1'b1, 32'h0000_0020 + (core_id << 2),
                 rom_test_data, 4'hf, result);
        if (dut.u_shared_memory.rom_mem[8 + core_id] !== rom_test_data) begin
            errors = errors + 1;
            $display("ASSERT_FAIL test=bridge_protocol core=%0d item=rom_write got=%08x expected=%08x",
                     core_id, dut.u_shared_memory.rom_mem[8 + core_id], rom_test_data);
        end
        transact(1'b0, 1'b0, 32'h0000_0020 + (core_id << 2),
                 32'h0, 4'hf, result);
        if (result !== rom_test_data) begin
            errors = errors + 1;
            $display("ASSERT_FAIL test=bridge_protocol core=%0d item=rom_read got=%08x expected=%08x",
                     core_id, result, rom_test_data);
        end

        transact(1'b1, 1'b1, 32'h1000_3ffc,
                 ram_test_data, 4'hf, result);
        if (core_id == 0) begin
            transact(1'b1, 1'b1, 32'h1000_3ffc,
                     32'haabb_ccdd, 4'b0101, result);
            ram_test_data = 32'h5abb_10dd;
        end
        if (dut.u_shared_memory.ram_mem[15] !== ram_test_data) begin
            errors = errors + 1;
            $display("ASSERT_FAIL test=bridge_protocol core=%0d item=ram_write got=%08x expected=%08x",
                     core_id, dut.u_shared_memory.ram_mem[15], ram_test_data);
        end
        transact(1'b1, 1'b0, 32'h1000_003c,
                 32'h0, 4'hf, result);
        if (result !== ram_test_data) begin
            errors = errors + 1;
            $display("ASSERT_FAIL test=bridge_protocol core=%0d item=ram_alias_read got=%08x expected=%08x",
                     core_id, result, ram_test_data);
        end

        if (errors == 0)
            $display("TEST_PASS test=bridge_protocol core=%0d rom=%08x ram=%08x alias=word15",
                     core_id, rom_test_data, ram_test_data);
        else
            $display("TEST_FAIL test=bridge_protocol core=%0d errors=%0d",
                     core_id, errors);
        $finish;
    end

endmodule
