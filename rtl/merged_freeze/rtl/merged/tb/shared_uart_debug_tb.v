`timescale 1ns/1ps

`include "tb/vcs_fsdb_dump.vh"

/*
 * Behavioral MMIO-UART harness for the shared 35-byte downloader.
 * It supplies real CRC-16/Modbus packets and models bridge backpressure.
 */
module shared_uart_debug_tb;

    localparam[31:0] UART_STATUS = 32'h3000_0004;
    localparam[31:0] UART_TX     = 32'h3000_000c;
    localparam[31:0] UART_RX     = 32'h3000_0010;

    reg clk;
    reg rst;
    reg debug_en;
    wire req;
    wire mem_we;
    wire[31:0] mem_addr;
    wire[31:0] mem_wdata;
    reg[31:0] mem_rdata;
    reg mem_busy;

    reg[7:0] rx_queue[0:2047];
    reg[7:0] packet_buf[0:34];
    reg[31:0] mirror[0:255];
    reg[7:0] responses[0:63];
    integer queue_write;
    integer queue_read;
    integer response_count;
    integer write_count;
    integer busy_countdown;
    integer cycles;
    integer errors;
    integer image_size;
    integer packet_count;
    integer packet_index;
    integer byte_index;
    integer offset;
    integer expected_words;
    integer expected_responses;
    reg write_armed;
    reg corrupt_crc;
    reg legal_image;
    reg[255:0] test_name;
    reg[1023:0] vcd_path;

    shared_uart_debug dut(
        .clk(clk), .rst(rst), .debug_en_i(debug_en), .req_o(req),
        .mem_we_o(mem_we), .mem_addr_o(mem_addr),
        .mem_wdata_o(mem_wdata), .mem_rdata_i(mem_rdata),
        .mem_busy_i(mem_busy)
    );

    always #10 clk = ~clk;

    function automatic [7:0] image_byte;
        input integer image_offset;
        begin
            image_byte = ((image_offset * 13) + 8'h5a) & 8'hff;
        end
    endfunction

    function automatic [15:0] packet_crc;
        integer b;
        integer k;
        reg[15:0] crc;
        begin
            crc = 16'hffff;
            for (b = 1; b <= 32; b = b + 1) begin
                crc = crc ^ packet_buf[b];
                for (k = 0; k < 8; k = k + 1) begin
                    if (crc[0]) crc = (crc >> 1) ^ 16'ha001;
                    else crc = crc >> 1;
                end
            end
            packet_crc = crc;
        end
    endfunction

    task automatic append_packet;
        input integer number;
        input integer payload_start;
        input integer payload_length;
        input header_packet;
        input bad_crc;
        integer j;
        reg[15:0] crc;
        begin
            for (j = 0; j < 35; j = j + 1) packet_buf[j] = 8'h00;
            packet_buf[0] = number[7:0];
            if (header_packet) begin
                packet_buf[1] = "t";
                packet_buf[2] = "e";
                packet_buf[3] = "s";
                packet_buf[4] = "t";
                packet_buf[25] = image_size[31:24];
                packet_buf[26] = image_size[23:16];
                packet_buf[27] = image_size[15:8];
                packet_buf[28] = image_size[7:0];
            end else begin
                for (j = 0; j < payload_length; j = j + 1)
                    packet_buf[1 + j] = image_byte(payload_start + j);
            end
            crc = packet_crc();
            if (bad_crc) crc = crc ^ 16'h0001;
            packet_buf[33] = crc[7:0];
            packet_buf[34] = crc[15:8];
            for (j = 0; j < 35; j = j + 1) begin
                rx_queue[queue_write] = packet_buf[j];
                queue_write = queue_write + 1;
            end
        end
    endtask

    always @(*) begin
        mem_rdata = 32'h0000_0000;
        if (mem_addr == UART_STATUS)
            mem_rdata = (queue_read < queue_write) ? 32'h0000_0002 : 32'h0;
        else if (mem_addr == UART_RX)
            mem_rdata = (queue_read < queue_write) ?
                        {24'h0, rx_queue[queue_read]} : 32'h0;
    end

    always @(posedge clk) begin
        if (!rst || !debug_en) begin
            queue_read <= 0;
            response_count <= 0;
            write_count <= 0;
            busy_countdown <= 0;
            mem_busy <= 1'b0;
            write_armed <= 1'b1;
        end else begin
            if (dut.state == 14'h0020 && (queue_read < queue_write))
                queue_read <= queue_read + 1;

            if (mem_we && (mem_addr == UART_TX)) begin
                responses[response_count] <= mem_wdata[7:0];
                response_count <= response_count + 1;
            end

            if (!mem_we || (mem_addr >= 32'h0000_0400))
                write_armed <= 1'b1;

            if (!mem_busy && write_armed && req && mem_we &&
                (mem_addr < 32'h0000_0400)) begin
                mem_busy <= 1'b1;
                busy_countdown <= 2;
                write_armed <= 1'b0;
                if (mem_addr[1:0] != 2'b00) begin
                    errors = errors + 1;
                    $display("ASSERT_FAIL test=%s item=unaligned_write addr=%08x",
                             test_name, mem_addr);
                end
                if (mem_addr[9:2] >= 256) begin
                    errors = errors + 1;
                    $display("ASSERT_FAIL test=%s item=write_out_of_range addr=%08x",
                             test_name, mem_addr);
                end else begin
                    mirror[mem_addr[9:2]] <= mem_wdata;
                end
                write_count <= write_count + 1;
            end else if (mem_busy) begin
                if (busy_countdown == 0)
                    mem_busy <= 1'b0;
                else
                    busy_countdown <= busy_countdown - 1;
            end
        end
    end

    initial begin
        clk = 1'b0;
        rst = 1'b0;
        debug_en = 1'b0;
        queue_write = 0;
        queue_read = 0;
        response_count = 0;
        write_count = 0;
        busy_countdown = 0;
        mem_busy = 1'b0;
        write_armed = 1'b1;
        cycles = 0;
        errors = 0;
        image_size = 0;
        corrupt_crc = 1'b0;
        legal_image = 1'b1;
        test_name = "size0";
        for (byte_index = 0; byte_index < 256; byte_index = byte_index + 1)
            mirror[byte_index] = 32'hdead_beef;

        if (!$value$plusargs("TEST=%s", test_name)) begin
            $display("TEST_FAIL test=uart_download reason=missing_TEST");
            $finish;
        end
        if ($value$plusargs("VCD=%s", vcd_path)) begin
            `MERGED_DUMPFILE(vcd_path);
            `MERGED_DUMPVARS(dut);
        end

        if (test_name == "size0") image_size = 0;
        else if (test_name == "size1") image_size = 1;
        else if (test_name == "size1023") image_size = 1023;
        else if (test_name == "size1024") image_size = 1024;
        else if (test_name == "reject1025") begin
            image_size = 1025;
            legal_image = 1'b0;
        end else if (test_name == "bad_crc") begin
            image_size = 1;
            legal_image = 1'b0;
            corrupt_crc = 1'b1;
        end else begin
            $display("TEST_FAIL test=uart_download reason=unknown_TEST name=%s", test_name);
            $finish;
        end

        append_packet(0, 0, 0, 1'b1, corrupt_crc);
        packet_count = (image_size / 32) + 1;
        if (legal_image) begin
            for (packet_index = 0; packet_index < packet_count;
                 packet_index = packet_index + 1) begin
                offset = packet_index * 32;
                if ((image_size - offset) >= 32)
                    append_packet(packet_index + 1, offset, 32, 1'b0, 1'b0);
                else if ((image_size - offset) > 0)
                    append_packet(packet_index + 1, offset,
                                  image_size - offset, 1'b0, 1'b0);
                else
                    append_packet(packet_index + 1, offset, 0, 1'b0, 1'b0);
            end
        end

        expected_words = (image_size + 3) / 4;
        expected_responses = legal_image ? (packet_count + 1) : 1;

        repeat (4) @(posedge clk);
        rst <= 1'b1;
        debug_en <= 1'b1;

        while ((response_count < expected_responses) && (cycles < 3000000)) begin
            @(posedge clk);
            cycles = cycles + 1;
        end
        repeat (10) @(posedge clk);

        if (cycles == 3000000) begin
            errors = errors + 1;
            $display("ASSERT_FAIL test=%s item=timeout responses=%0d expected=%0d state=%h",
                     test_name, response_count, expected_responses, dut.state);
        end
        if ($size(dut.rx_data) != 35) begin
            errors = errors + 1;
            $display("ASSERT_FAIL test=%s item=rx_capacity got=%0d expected=35",
                     test_name, $size(dut.rx_data));
        end

        if (legal_image) begin
            for (packet_index = 0; packet_index < expected_responses;
                 packet_index = packet_index + 1) begin
                if (responses[packet_index] !== 8'h06) begin
                    errors = errors + 1;
                    $display("ASSERT_FAIL test=%s item=response index=%0d got=%02x expected=06",
                             test_name, packet_index, responses[packet_index]);
                end
            end
            if (write_count != expected_words) begin
                errors = errors + 1;
                $display("ASSERT_FAIL test=%s item=write_count got=%0d expected=%0d",
                         test_name, write_count, expected_words);
            end
            for (byte_index = 0; byte_index < expected_words;
                 byte_index = byte_index + 1) begin
                offset = byte_index * 4;
                if (mirror[byte_index] !== {
                    ((offset + 3) < image_size) ? image_byte(offset + 3) : 8'h00,
                    ((offset + 2) < image_size) ? image_byte(offset + 2) : 8'h00,
                    ((offset + 1) < image_size) ? image_byte(offset + 1) : 8'h00,
                    (offset < image_size) ? image_byte(offset) : 8'h00}) begin
                    errors = errors + 1;
                    $display("ASSERT_FAIL test=%s item=mirror word=%0d got=%08x",
                             test_name, byte_index, mirror[byte_index]);
                end
            end
            if ((expected_words < 256) &&
                (mirror[expected_words] !== 32'hdead_beef)) begin
                errors = errors + 1;
                $display("ASSERT_FAIL test=%s item=padding_write word=%0d got=%08x",
                         test_name, expected_words, mirror[expected_words]);
            end
        end else begin
            if ((responses[0] !== 8'h15) || (write_count != 0)) begin
                errors = errors + 1;
                $display("ASSERT_FAIL test=%s item=reject response=%02x writes=%0d",
                         test_name, responses[0], write_count);
            end
        end

        if (errors == 0)
            $display("TEST_PASS test=uart_download case=%s size=%0d packets=%0d responses=%0d writes=%0d rx_capacity=35 cycles=%0d",
                     test_name, image_size, legal_image ? packet_count + 1 : 1,
                     response_count, write_count, cycles);
        else
            $display("TEST_FAIL test=uart_download case=%s errors=%0d size=%0d cycles=%0d",
                     test_name, errors, image_size, cycles);
        $finish;
    end

endmodule
