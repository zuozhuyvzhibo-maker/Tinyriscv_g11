/*
 * Four-core TinyRISC-V chip top.
 * chip_sel values 0, 1, 2, and 3 select LHR, LDK, SY, and WJE.
 */

// One register file, PWM block, and UART downloader are shared. The selected
// tile supplies all requests and receives all return data.
module tinyriscv_merged_chip_top(
    input wire clk,
    input wire rst,
    input wire[1:0] chip_sel,

    output wire succ,
    input wire uart_debug_pin,
    output wire uart_tx_pin,
    input wire uart_rx_pin,

    inout wire io_sda,
    output wire io_scl,
    output wire[3:0] pwm_o,

    output wire[7:0] bridge_data_o,
    input wire[7:0] bridge_data_i
    );

    localparam [1:0] CORE_LHR = 2'd0;
    localparam [1:0] CORE_LDK = 2'd1;
    localparam [1:0] CORE_SY  = 2'd2;
    localparam [1:0] CORE_WJE = 2'd3;
    localparam [2:0] SWITCH_RESET_CYCLES = 3'd3;

    reg[1:0] chip_sel_q;
    reg[2:0] switch_reset_count;
    wire selection_changed = (chip_sel != chip_sel_q);
    wire shared_rst = rst && !selection_changed &&
                      (switch_reset_count == 3'd0);

    // rst is active low. A selector change immediately stops every core and
    // holds the selected core plus all shared state in reset for several full
    // clock edges. This prevents pipeline, peripheral, or downloader state
    // from leaking from the previously selected core.
    always @ (posedge clk) begin
        if (rst == 1'b0) begin
            chip_sel_q <= chip_sel;
            switch_reset_count <= SWITCH_RESET_CYCLES;
        end else begin
            chip_sel_q <= chip_sel;
            if (selection_changed) begin
                switch_reset_count <= SWITCH_RESET_CYCLES;
            end else if (switch_reset_count != 3'd0) begin
                switch_reset_count <= switch_reset_count - 1'b1;
            end
        end
    end

    wire lhr_rst = shared_rst && (chip_sel == CORE_LHR);
    wire ldk_rst = shared_rst && (chip_sel == CORE_LDK);
    wire sy_rst  = shared_rst && (chip_sel == CORE_SY);
    wire wje_rst = shared_rst && (chip_sel == CORE_WJE);

    wire debug_req;
    wire debug_we;
    wire[31:0] debug_addr;
    wire[31:0] debug_wdata;
    reg[31:0] debug_rdata;
    reg debug_busy;

    wire[31:0] lhr_debug_rdata;
    wire[31:0] ldk_debug_rdata;
    wire[31:0] sy_debug_rdata;
    wire[31:0] wje_debug_rdata;
    wire lhr_debug_busy;
    wire ldk_debug_busy;
    wire sy_debug_busy;
    wire wje_debug_busy;

    shared_uart_debug u_shared_uart_debug(
        .clk(clk),
        .rst(shared_rst),
        .debug_en_i(uart_debug_pin),
        .req_o(debug_req),
        .mem_we_o(debug_we),
        .mem_addr_o(debug_addr),
        .mem_wdata_o(debug_wdata),
        .mem_rdata_i(debug_rdata),
        .mem_busy_i(debug_busy)
    );

    always @ (*) begin
        case (chip_sel)
            CORE_LHR: begin
                debug_rdata = lhr_debug_rdata;
                debug_busy = lhr_debug_busy;
            end
            CORE_LDK: begin
                debug_rdata = ldk_debug_rdata;
                debug_busy = ldk_debug_busy;
            end
            CORE_SY: begin
                debug_rdata = sy_debug_rdata;
                debug_busy = sy_debug_busy;
            end
            CORE_WJE: begin
                debug_rdata = wje_debug_rdata;
                debug_busy = wje_debug_busy;
            end
            default: begin
                debug_rdata = 32'h0000_0000;
                debug_busy = 1'b0;
            end
        endcase
    end

    wire[4:0] lhr_rf_raddr1;
    wire[4:0] lhr_rf_raddr2;
    wire lhr_rf_we;
    wire[4:0] lhr_rf_waddr;
    wire[31:0] lhr_rf_wdata;
    wire[4:0] ldk_rf_raddr1;
    wire[4:0] ldk_rf_raddr2;
    wire ldk_rf_we;
    wire[4:0] ldk_rf_waddr;
    wire[31:0] ldk_rf_wdata;
    wire[4:0] sy_rf_raddr1;
    wire[4:0] sy_rf_raddr2;
    wire sy_rf_we;
    wire[4:0] sy_rf_waddr;
    wire[31:0] sy_rf_wdata;
    wire[4:0] wje_rf_raddr1;
    wire[4:0] wje_rf_raddr2;
    wire wje_rf_we;
    wire[4:0] wje_rf_waddr;
    wire[31:0] wje_rf_wdata;

    reg[4:0] shared_rf_raddr1;
    reg[4:0] shared_rf_raddr2;
    reg shared_rf_we;
    reg[4:0] shared_rf_waddr;
    reg[31:0] shared_rf_wdata;
    wire[31:0] shared_rf_rdata1;
    wire[31:0] shared_rf_rdata2;
    wire over_unused;

    always @ (*) begin
        shared_rf_raddr1 = 5'h00;
        shared_rf_raddr2 = 5'h00;
        shared_rf_we = 1'b0;
        shared_rf_waddr = 5'h00;
        shared_rf_wdata = 32'h0000_0000;
        case (chip_sel)
            CORE_LHR: begin
                shared_rf_raddr1 = lhr_rf_raddr1;
                shared_rf_raddr2 = lhr_rf_raddr2;
                shared_rf_we = lhr_rf_we;
                shared_rf_waddr = lhr_rf_waddr;
                shared_rf_wdata = lhr_rf_wdata;
            end
            CORE_LDK: begin
                shared_rf_raddr1 = ldk_rf_raddr1;
                shared_rf_raddr2 = ldk_rf_raddr2;
                shared_rf_we = ldk_rf_we;
                shared_rf_waddr = ldk_rf_waddr;
                shared_rf_wdata = ldk_rf_wdata;
            end
            CORE_SY: begin
                shared_rf_raddr1 = sy_rf_raddr1;
                shared_rf_raddr2 = sy_rf_raddr2;
                shared_rf_we = sy_rf_we;
                shared_rf_waddr = sy_rf_waddr;
                shared_rf_wdata = sy_rf_wdata;
            end
            CORE_WJE: begin
                shared_rf_raddr1 = wje_rf_raddr1;
                shared_rf_raddr2 = wje_rf_raddr2;
                shared_rf_we = wje_rf_we;
                shared_rf_waddr = wje_rf_waddr;
                shared_rf_wdata = wje_rf_wdata;
            end
            default: begin
            end
        endcase
    end

    shared_regs u_shared_regs(
        .clk(clk),
        .rst(shared_rst),
        .we_i(shared_rf_we),
        .waddr_i(shared_rf_waddr),
        .wdata_i(shared_rf_wdata),
        .raddr1_i(shared_rf_raddr1),
        .rdata1_o(shared_rf_rdata1),
        .raddr2_i(shared_rf_raddr2),
        .rdata2_o(shared_rf_rdata2),
        .over_o(over_unused),
        .succ_o(succ)
    );

    wire lhr_pwm_we;
    wire[31:0] lhr_pwm_addr;
    wire[31:0] lhr_pwm_wdata;
    wire ldk_pwm_we;
    wire[31:0] ldk_pwm_addr;
    wire[31:0] ldk_pwm_wdata;
    wire sy_pwm_we;
    wire[31:0] sy_pwm_addr;
    wire[31:0] sy_pwm_wdata;
    wire wje_pwm_we;
    wire[31:0] wje_pwm_addr;
    wire[31:0] wje_pwm_wdata;
    reg shared_pwm_we;
    reg[31:0] shared_pwm_addr;
    reg[31:0] shared_pwm_wdata;
    wire[31:0] shared_pwm_rdata;

    always @ (*) begin
        shared_pwm_we = 1'b0;
        shared_pwm_addr = 32'h0000_0000;
        shared_pwm_wdata = 32'h0000_0000;
        case (chip_sel)
            CORE_LHR: begin
                shared_pwm_we = lhr_pwm_we;
                shared_pwm_addr = lhr_pwm_addr;
                shared_pwm_wdata = lhr_pwm_wdata;
            end
            CORE_LDK: begin
                shared_pwm_we = ldk_pwm_we;
                shared_pwm_addr = ldk_pwm_addr;
                shared_pwm_wdata = ldk_pwm_wdata;
            end
            CORE_SY: begin
                shared_pwm_we = sy_pwm_we;
                shared_pwm_addr = sy_pwm_addr;
                shared_pwm_wdata = sy_pwm_wdata;
            end
            CORE_WJE: begin
                shared_pwm_we = wje_pwm_we;
                shared_pwm_addr = wje_pwm_addr;
                shared_pwm_wdata = wje_pwm_wdata;
            end
            default: begin
            end
        endcase
    end

    shared_pwm u_shared_pwm(
        .clk(clk),
        .rst(shared_rst),
        .we_i(shared_pwm_we),
        .addr_i(shared_pwm_addr),
        .data_i(shared_pwm_wdata),
        .data_o(shared_pwm_rdata),
        .pwm_o(pwm_o)
    );

    wire lhr_uart_tx;
    wire ldk_uart_tx;
    wire sy_uart_tx;
    wire wje_uart_tx;
    reg selected_uart_tx;
    assign uart_tx_pin = shared_rst ? selected_uart_tx : 1'b1;

    always @ (*) begin
        case (chip_sel)
            CORE_LHR: selected_uart_tx = lhr_uart_tx;
            CORE_LDK: selected_uart_tx = ldk_uart_tx;
            CORE_SY: selected_uart_tx = sy_uart_tx;
            CORE_WJE: selected_uart_tx = wje_uart_tx;
            default: selected_uart_tx = 1'b1;
        endcase
    end

    wire lhr_scl_drive_low;
    wire lhr_sda_drive_low;
    wire ldk_scl_drive_low;
    wire ldk_sda_drive_low;
    wire sy_scl_drive_low;
    wire sy_sda_drive_low;
    wire wje_scl_drive_low;
    wire wje_sda_drive_low;
    reg selected_scl_drive_low;
    reg selected_sda_drive_low;

    assign io_scl = (shared_rst && selected_scl_drive_low) ? 1'b0 : 1'bz;
    assign io_sda = (shared_rst && selected_sda_drive_low) ? 1'b0 : 1'bz;

    always @ (*) begin
        selected_scl_drive_low = 1'b0;
        selected_sda_drive_low = 1'b0;
        case (chip_sel)
            CORE_LHR: begin
                selected_scl_drive_low = lhr_scl_drive_low;
                selected_sda_drive_low = lhr_sda_drive_low;
            end
            CORE_LDK: begin
                selected_scl_drive_low = ldk_scl_drive_low;
                selected_sda_drive_low = ldk_sda_drive_low;
            end
            CORE_SY: begin
                selected_scl_drive_low = sy_scl_drive_low;
                selected_sda_drive_low = sy_sda_drive_low;
            end
            CORE_WJE: begin
                selected_scl_drive_low = wje_scl_drive_low;
                selected_sda_drive_low = wje_sda_drive_low;
            end
            default: begin
            end
        endcase
    end

    wire[7:0] lhr_bridge_data;
    wire[7:0] ldk_bridge_data;
    wire[7:0] sy_bridge_data;
    wire[7:0] wje_bridge_data;
    reg[7:0] selected_bridge_data;
    assign bridge_data_o = shared_rst ? selected_bridge_data : 8'h00;

    always @ (*) begin
        case (chip_sel)
            CORE_LHR: selected_bridge_data = lhr_bridge_data;
            CORE_LDK: selected_bridge_data = ldk_bridge_data;
            CORE_SY: selected_bridge_data = sy_bridge_data;
            CORE_WJE: selected_bridge_data = wje_bridge_data;
            default: selected_bridge_data = 8'h00;
        endcase
    end

    lhr_core_tile u_lhr_tile(
        .clk(clk),
        .rst(lhr_rst),
        .debug_req_i(debug_req && (chip_sel == CORE_LHR)),
        .debug_we_i(debug_we),
        .debug_addr_i(debug_addr),
        .debug_wdata_i(debug_wdata),
        .debug_rdata_o(lhr_debug_rdata),
        .debug_busy_o(lhr_debug_busy),
        .rf_raddr1_o(lhr_rf_raddr1),
        .rf_raddr2_o(lhr_rf_raddr2),
        .rf_rdata1_i(shared_rf_rdata1),
        .rf_rdata2_i(shared_rf_rdata2),
        .rf_we_o(lhr_rf_we),
        .rf_waddr_o(lhr_rf_waddr),
        .rf_wdata_o(lhr_rf_wdata),
        .pwm_we_o(lhr_pwm_we),
        .pwm_addr_o(lhr_pwm_addr),
        .pwm_wdata_o(lhr_pwm_wdata),
        .pwm_rdata_i(shared_pwm_rdata),
        .uart_tx_o(lhr_uart_tx),
        .uart_rx_i(uart_rx_pin),
        .i2c_scl_drive_low_o(lhr_scl_drive_low),
        .i2c_sda_drive_low_o(lhr_sda_drive_low),
        .i2c_sda_i(io_sda),
        .bridge_data_o(lhr_bridge_data),
        .bridge_data_i(bridge_data_i)
    );

    ldk_core_tile u_ldk_tile(
        .clk(clk),
        .rst(ldk_rst),
        .debug_req_i(debug_req && (chip_sel == CORE_LDK)),
        .debug_we_i(debug_we),
        .debug_addr_i(debug_addr),
        .debug_wdata_i(debug_wdata),
        .debug_rdata_o(ldk_debug_rdata),
        .debug_busy_o(ldk_debug_busy),
        .rf_raddr1_o(ldk_rf_raddr1),
        .rf_raddr2_o(ldk_rf_raddr2),
        .rf_rdata1_i(shared_rf_rdata1),
        .rf_rdata2_i(shared_rf_rdata2),
        .rf_we_o(ldk_rf_we),
        .rf_waddr_o(ldk_rf_waddr),
        .rf_wdata_o(ldk_rf_wdata),
        .pwm_we_o(ldk_pwm_we),
        .pwm_addr_o(ldk_pwm_addr),
        .pwm_wdata_o(ldk_pwm_wdata),
        .pwm_rdata_i(shared_pwm_rdata),
        .uart_tx_o(ldk_uart_tx),
        .uart_rx_i(uart_rx_pin),
        .i2c_scl_drive_low_o(ldk_scl_drive_low),
        .i2c_sda_drive_low_o(ldk_sda_drive_low),
        .i2c_sda_i(io_sda),
        .bridge_data_o(ldk_bridge_data),
        .bridge_data_i(bridge_data_i)
    );

    sy_core_tile u_sy_tile(
        .clk(clk),
        .rst(sy_rst),
        .debug_req_i(debug_req && (chip_sel == CORE_SY)),
        .debug_we_i(debug_we),
        .debug_addr_i(debug_addr),
        .debug_wdata_i(debug_wdata),
        .debug_rdata_o(sy_debug_rdata),
        .debug_busy_o(sy_debug_busy),
        .rf_raddr1_o(sy_rf_raddr1),
        .rf_raddr2_o(sy_rf_raddr2),
        .rf_rdata1_i(shared_rf_rdata1),
        .rf_rdata2_i(shared_rf_rdata2),
        .rf_we_o(sy_rf_we),
        .rf_waddr_o(sy_rf_waddr),
        .rf_wdata_o(sy_rf_wdata),
        .pwm_we_o(sy_pwm_we),
        .pwm_addr_o(sy_pwm_addr),
        .pwm_wdata_o(sy_pwm_wdata),
        .pwm_rdata_i(shared_pwm_rdata),
        .uart_tx_o(sy_uart_tx),
        .uart_rx_i(uart_rx_pin),
        .i2c_scl_drive_low_o(sy_scl_drive_low),
        .i2c_sda_drive_low_o(sy_sda_drive_low),
        .i2c_sda_i(io_sda),
        .bridge_data_o(sy_bridge_data),
        .bridge_data_i(bridge_data_i)
    );

    wje_core_tile u_wje_tile(
        .clk(clk),
        .rst(wje_rst),
        .debug_req_i(debug_req && (chip_sel == CORE_WJE)),
        .debug_we_i(debug_we),
        .debug_addr_i(debug_addr),
        .debug_wdata_i(debug_wdata),
        .debug_rdata_o(wje_debug_rdata),
        .debug_busy_o(wje_debug_busy),
        .rf_raddr1_o(wje_rf_raddr1),
        .rf_raddr2_o(wje_rf_raddr2),
        .rf_rdata1_i(shared_rf_rdata1),
        .rf_rdata2_i(shared_rf_rdata2),
        .rf_we_o(wje_rf_we),
        .rf_waddr_o(wje_rf_waddr),
        .rf_wdata_o(wje_rf_wdata),
        .pwm_we_o(wje_pwm_we),
        .pwm_addr_o(wje_pwm_addr),
        .pwm_wdata_o(wje_pwm_wdata),
        .pwm_rdata_i(shared_pwm_rdata),
        .uart_tx_o(wje_uart_tx),
        .uart_rx_i(uart_rx_pin),
        .i2c_scl_drive_low_o(wje_scl_drive_low),
        .i2c_scl_i(io_scl),
        .i2c_sda_drive_low_o(wje_sda_drive_low),
        .i2c_sda_i(io_sda),
        .bridge_data_o(wje_bridge_data),
        .bridge_data_i(bridge_data_i)
    );

endmodule
