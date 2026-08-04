/*
 * FPGA bridge bank for the four-core integration.
 *
 * The protocol state machines are kept separate, but they all access one
 * physical 256-word ROM and one physical 16-word RAM.  A selector change
 * immediately quiesces every adapter, clears the shared RAM, and then keeps
 * the chip in reset for an additional three clock cycles.
 */
module merged_fpga_bridge_bank(
    input wire clk,
    input wire rst,
    input wire[1:0] chip_sel,
    input wire[7:0] chip_data_i,
    output reg[7:0] chip_data_o,
    output wire memory_ready_o
    );

    localparam[1:0] CORE_LHR = 2'd0;
    localparam[1:0] CORE_LDK = 2'd1;
    localparam[1:0] CORE_SY  = 2'd2;
    localparam[1:0] CORE_WJE = 2'd3;
    localparam[2:0] SWITCH_GUARD_CYCLES = 3'd3;

    reg[1:0] chip_sel_q;
    reg[2:0] guard_count;
    wire selection_changed = (chip_sel != chip_sel_q);
    wire memory_storage_ready;
    wire bridge_active = rst && !selection_changed &&
                         memory_storage_ready && (guard_count == 3'd0);
    // Stable name retained for existing waveform/testbench consumers.
    wire bridge_rst = bridge_active;

    assign memory_ready_o = bridge_active;

    always @ (posedge clk) begin
        if (rst == 1'b0) begin
            chip_sel_q <= chip_sel;
            guard_count <= SWITCH_GUARD_CYCLES;
        end else begin
            chip_sel_q <= chip_sel;
            if (selection_changed || !memory_storage_ready) begin
                guard_count <= SWITCH_GUARD_CYCLES;
            end else if (guard_count != 3'd0) begin
                guard_count <= guard_count - 1'b1;
            end
        end
    end

    wire lhr_rst = bridge_active && (chip_sel == CORE_LHR);
    wire ldk_rst = bridge_active && (chip_sel == CORE_LDK);
    wire sy_rst  = bridge_active && (chip_sel == CORE_SY);
    wire wje_rst = bridge_active && (chip_sel == CORE_WJE);

    wire[7:0] lhr_data_i = lhr_rst ? chip_data_i : 8'h00;
    wire[7:0] ldk_data_i = ldk_rst ? chip_data_i : 8'h00;
    wire[7:0] sy_data_i  = sy_rst  ? chip_data_i : 8'h00;
    wire[7:0] wje_data_i = wje_rst ? chip_data_i : 8'h00;
    wire[7:0] lhr_data_o;
    wire[7:0] ldk_data_o;
    wire[7:0] sy_data_o;
    wire[7:0] wje_data_o;

    always @ (*) begin
        chip_data_o = 8'h00;
        if (bridge_active) begin
            case (chip_sel)
                CORE_LHR: chip_data_o = lhr_data_o;
                CORE_LDK: chip_data_o = ldk_data_o;
                CORE_SY:  chip_data_o = sy_data_o;
                CORE_WJE: chip_data_o = wje_data_o;
                default:  chip_data_o = 8'h00;
            endcase
        end
    end

    wire lhr_rom_we;
    wire[31:0] lhr_rom_addr;
    wire[31:0] lhr_rom_wdata;
    wire[3:0] lhr_rom_wstrb;
    wire lhr_ram_we;
    wire[31:0] lhr_ram_addr;
    wire[31:0] lhr_ram_wdata;
    wire[3:0] lhr_ram_wstrb;

    wire ldk_rom_we;
    wire[31:0] ldk_rom_addr;
    wire[31:0] ldk_rom_wdata;
    wire[3:0] ldk_rom_wstrb;
    wire ldk_ram_we;
    wire[31:0] ldk_ram_addr;
    wire[31:0] ldk_ram_wdata;
    wire[3:0] ldk_ram_wstrb;

    wire sy_rom_we;
    wire[31:0] sy_rom_addr;
    wire[31:0] sy_rom_wdata;
    wire[3:0] sy_rom_wstrb;
    wire sy_ram_we;
    wire[31:0] sy_ram_addr;
    wire[31:0] sy_ram_wdata;
    wire[3:0] sy_ram_wstrb;

    wire wje_rom_we;
    wire[31:0] wje_rom_addr;
    wire[31:0] wje_rom_wdata;
    wire[3:0] wje_rom_wstrb;
    wire wje_ram_we;
    wire[31:0] wje_ram_addr;
    wire[31:0] wje_ram_wdata;
    wire[3:0] wje_ram_wstrb;

    wire[31:0] selected_rom_addr =
        (chip_sel == CORE_LHR) ? lhr_rom_addr :
        (chip_sel == CORE_LDK) ? ldk_rom_addr :
        (chip_sel == CORE_SY)  ? sy_rom_addr  : wje_rom_addr;
    wire[31:0] selected_rom_wdata =
        (chip_sel == CORE_LHR) ? lhr_rom_wdata :
        (chip_sel == CORE_LDK) ? ldk_rom_wdata :
        (chip_sel == CORE_SY)  ? sy_rom_wdata  : wje_rom_wdata;
    wire[3:0] selected_rom_wstrb =
        (chip_sel == CORE_LHR) ? lhr_rom_wstrb :
        (chip_sel == CORE_LDK) ? ldk_rom_wstrb :
        (chip_sel == CORE_SY)  ? sy_rom_wstrb  : wje_rom_wstrb;
    wire selected_rom_we = bridge_active &&
        (((chip_sel == CORE_LHR) && lhr_rom_we) ||
         ((chip_sel == CORE_LDK) && ldk_rom_we) ||
         ((chip_sel == CORE_SY)  && sy_rom_we)  ||
         ((chip_sel == CORE_WJE) && wje_rom_we));

    wire[31:0] selected_ram_addr =
        (chip_sel == CORE_LHR) ? lhr_ram_addr :
        (chip_sel == CORE_LDK) ? ldk_ram_addr :
        (chip_sel == CORE_SY)  ? sy_ram_addr  : wje_ram_addr;
    wire[31:0] selected_ram_wdata =
        (chip_sel == CORE_LHR) ? lhr_ram_wdata :
        (chip_sel == CORE_LDK) ? ldk_ram_wdata :
        (chip_sel == CORE_SY)  ? sy_ram_wdata  : wje_ram_wdata;
    wire[3:0] selected_ram_wstrb =
        (chip_sel == CORE_LHR) ? lhr_ram_wstrb :
        (chip_sel == CORE_LDK) ? ldk_ram_wstrb :
        (chip_sel == CORE_SY)  ? sy_ram_wstrb  : wje_ram_wstrb;
    wire selected_ram_we = bridge_active &&
        (((chip_sel == CORE_LHR) && lhr_ram_we) ||
         ((chip_sel == CORE_LDK) && ldk_ram_we) ||
         ((chip_sel == CORE_SY)  && sy_ram_we)  ||
         ((chip_sel == CORE_WJE) && wje_ram_we));

    wire[31:0] shared_rom_rdata;
    wire[31:0] shared_ram_rdata;

    shared_fpga_memory u_shared_memory(
        .clk(clk),
        .rst(rst),
        .clear_i(selection_changed),
        .ready_o(memory_storage_ready),
        .rom_we_i(selected_rom_we),
        .rom_addr_i(selected_rom_addr),
        .rom_wdata_i(selected_rom_wdata),
        .rom_wstrb_i(selected_rom_wstrb),
        .rom_rdata_o(shared_rom_rdata),
        .ram_we_i(selected_ram_we),
        .ram_addr_i(selected_ram_addr),
        .ram_wdata_i(selected_ram_wdata),
        .ram_wstrb_i(selected_ram_wstrb),
        .ram_rdata_o(shared_ram_rdata)
    );

    lhr_fpga_bridge_adapter u_lhr_bridge(
        .clk(clk), .rst(lhr_rst),
        .chip_data_i(lhr_data_i), .chip_data_o(lhr_data_o),
        .rom_we_o(lhr_rom_we), .rom_addr_o(lhr_rom_addr),
        .rom_wdata_o(lhr_rom_wdata), .rom_wstrb_o(lhr_rom_wstrb),
        .rom_rdata_i(shared_rom_rdata),
        .ram_we_o(lhr_ram_we), .ram_addr_o(lhr_ram_addr),
        .ram_wdata_o(lhr_ram_wdata), .ram_wstrb_o(lhr_ram_wstrb),
        .ram_rdata_i(shared_ram_rdata)
    );

    ldk_fpga_bridge_adapter u_ldk_bridge(
        .clk(clk), .rst(ldk_rst),
        .chip_data_i(ldk_data_i), .chip_data_o(ldk_data_o),
        .rom_we_o(ldk_rom_we), .rom_addr_o(ldk_rom_addr),
        .rom_wdata_o(ldk_rom_wdata), .rom_wstrb_o(ldk_rom_wstrb),
        .rom_rdata_i(shared_rom_rdata),
        .ram_we_o(ldk_ram_we), .ram_addr_o(ldk_ram_addr),
        .ram_wdata_o(ldk_ram_wdata), .ram_wstrb_o(ldk_ram_wstrb),
        .ram_rdata_i(shared_ram_rdata)
    );

    sy_fpga_bridge_adapter u_sy_bridge(
        .clk(clk), .rst(sy_rst),
        .chip_data_i(sy_data_i), .chip_data_o(sy_data_o),
        .rom_we_o(sy_rom_we), .rom_addr_o(sy_rom_addr),
        .rom_wdata_o(sy_rom_wdata), .rom_wstrb_o(sy_rom_wstrb),
        .rom_rdata_i(shared_rom_rdata),
        .ram_we_o(sy_ram_we), .ram_addr_o(sy_ram_addr),
        .ram_wdata_o(sy_ram_wdata), .ram_wstrb_o(sy_ram_wstrb),
        .ram_rdata_i(shared_ram_rdata)
    );

    wje_fpga_bridge_adapter u_wje_bridge(
        .clk(clk), .rst(wje_rst),
        .chip_data_i(wje_data_i), .chip_data_o(wje_data_o),
        .rom_we_o(wje_rom_we), .rom_addr_o(wje_rom_addr),
        .rom_wdata_o(wje_rom_wdata), .rom_wstrb_o(wje_rom_wstrb),
        .rom_rdata_i(shared_rom_rdata),
        .ram_we_o(wje_ram_we), .ram_addr_o(wje_ram_addr),
        .ram_wdata_o(wje_ram_wdata), .ram_wstrb_o(wje_ram_wstrb),
        .ram_rdata_i(shared_ram_rdata)
    );

endmodule
