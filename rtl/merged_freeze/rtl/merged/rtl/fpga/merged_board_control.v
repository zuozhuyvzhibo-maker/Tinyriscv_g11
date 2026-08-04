/*
 * AX7035 board control for the merged four-core FPGA image.
 *
 * The board keys are active low. KEY2 and KEY3 select the next and previous
 * core. KEY4 is a level-controlled display key and does not alter chip_sel.
 */
module merged_button_debouncer #(
    parameter integer DEBOUNCE_CYCLES = 500000,
    parameter integer COUNTER_WIDTH = 19
    )(
    input wire clk,
    input wire rst,
    input wire key_n,
    output reg stable_n,
    output wire press_pulse
    );

    (* ASYNC_REG = "TRUE" *) reg key_meta;
    (* ASYNC_REG = "TRUE" *) reg key_sync;
    reg stable_n_q;
    reg[COUNTER_WIDTH-1:0] debounce_count;

    assign press_pulse = stable_n_q && !stable_n;

    always @ (posedge clk) begin
        if (rst == 1'b0) begin
            key_meta <= 1'b1;
            key_sync <= 1'b1;
            stable_n <= 1'b1;
            stable_n_q <= 1'b1;
            debounce_count <= {COUNTER_WIDTH{1'b0}};
        end else begin
            key_meta <= key_n;
            key_sync <= key_meta;
            stable_n_q <= stable_n;

            if (key_sync == stable_n) begin
                debounce_count <= {COUNTER_WIDTH{1'b0}};
            end else if (debounce_count == DEBOUNCE_CYCLES - 1) begin
                stable_n <= key_sync;
                debounce_count <= {COUNTER_WIDTH{1'b0}};
            end else begin
                debounce_count <= debounce_count + 1'b1;
            end
        end
    end

endmodule

module merged_reset_sync(
    input wire clk,
    input wire rst_n_async,
    output wire rst_n_sync
    );

    (* ASYNC_REG = "TRUE" *) reg[1:0] reset_release_sync = 2'b00;

    // Both assertion and release are sampled by clk. The complete design uses
    // synchronous active-low reset, so this also prevents an asynchronously
    // reset register from driving inferred block-RAM write enables.
    always @ (posedge clk) begin
        if (rst_n_async == 1'b0) begin
            reset_release_sync <= 2'b00;
        end else begin
            reset_release_sync <= {reset_release_sync[0], 1'b1};
        end
    end

    assign rst_n_sync = reset_release_sync[1];

endmodule

module merged_board_control #(
    parameter integer DEBOUNCE_CYCLES = 500000,
    parameter integer COUNTER_WIDTH = 19
    )(
    input wire clk,
    input wire rst,
    input wire key_next_n,
    input wire key_prev_n,
    input wire key_pwm_view_n,
    output reg[1:0] chip_sel = 2'b00,
    output wire pwm_view
    );

    wire next_press;
    wire prev_press;
    wire next_stable_n;
    wire prev_stable_n;
    wire view_stable_n;
    wire view_press_unused;

    merged_button_debouncer #(
        .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES),
        .COUNTER_WIDTH(COUNTER_WIDTH)
    ) u_next_debouncer(
        .clk(clk),
        .rst(rst),
        .key_n(key_next_n),
        .stable_n(next_stable_n),
        .press_pulse(next_press)
    );

    merged_button_debouncer #(
        .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES),
        .COUNTER_WIDTH(COUNTER_WIDTH)
    ) u_prev_debouncer(
        .clk(clk),
        .rst(rst),
        .key_n(key_prev_n),
        .stable_n(prev_stable_n),
        .press_pulse(prev_press)
    );

    merged_button_debouncer #(
        .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES),
        .COUNTER_WIDTH(COUNTER_WIDTH)
    ) u_view_debouncer(
        .clk(clk),
        .rst(rst),
        .key_n(key_pwm_view_n),
        .stable_n(view_stable_n),
        .press_pulse(view_press_unused)
    );

    assign pwm_view = !view_stable_n;

    always @ (posedge clk) begin
        if (rst == 1'b0) begin
            // Keep the selected core across a board RESET. The FPGA INIT
            // value selects LHR after configuration, while later resets can
            // restart LDK, SY, or WJE without silently switching back to LHR.
            chip_sel <= chip_sel;
        end else begin
            case ({next_press, prev_press})
                2'b10: chip_sel <= chip_sel + 1'b1;
                2'b01: chip_sel <= chip_sel - 1'b1;
                default: chip_sel <= chip_sel;
            endcase
        end
    end

endmodule

module merged_status_leds(
    input wire[1:0] chip_sel,
    input wire succ,
    input wire pwm_view,
    input wire[3:0] pwm,
    output reg[3:0] led_n
    );

    reg[3:0] selected_core_led_n;

    always @ (*) begin
        case (chip_sel)
            2'b00: selected_core_led_n = 4'b1110;
            2'b01: selected_core_led_n = 4'b1101;
            2'b10: selected_core_led_n = 4'b1011;
            2'b11: selected_core_led_n = 4'b0111;
            default: selected_core_led_n = 4'b1111;
        endcase

        if (pwm_view == 1'b1) begin
            // AX7035 LEDs are active low. Invert the PWM signals so a logical
            // PWM high level is visible as an illuminated LED.
            led_n = ~pwm;
        end else if (succ == 1'b0) begin
            led_n = 4'b0000;
        end else begin
            led_n = selected_core_led_n;
        end
    end

endmodule
