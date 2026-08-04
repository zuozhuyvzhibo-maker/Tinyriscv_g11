module sy_pwm(

	input wire clk,
	input wire rst,

    input wire we_i,
    input wire[31:0] addr_i,
    input wire[31:0] data_i,

    output reg[31:0] data_o,
    output reg[3:0] pwm_o

    );

    // 控制寄存器地址
    localparam PRD_REG_BASE = 5'b00000;
    localparam DC_REG_BASE = 5'b10000;

    // four 32-bit period register
    reg [31:0] prd_reg [3:0];

    // four 32-bit duty-cycle register
    reg [31:0] dc_reg [3:0];

    // four cycle counter
    reg [31:0] cyc_cnt [3:0];

    // 4-bit enable register
    reg [3:0] en_reg;

    // 写寄存器
    genvar wrt_cnt;

    generate
        for (wrt_cnt = 0; wrt_cnt < 4; wrt_cnt = wrt_cnt + 1) begin: REG_WRITE
            always @(posedge clk) begin
                if (rst == 1'b0) begin
                    prd_reg[wrt_cnt] <= 32'b0;
                    dc_reg[wrt_cnt] <= 32'b0; // all zero value
                end else if ((we_i == 1'b1) && (addr_i[19:16] == wrt_cnt)) begin
                    if (addr_i[20] == 1'b1) begin // address is 0x601x_xxxx
                        dc_reg[wrt_cnt] <= data_i;
                    end else begin // address is 0x600x_xxxx
                        prd_reg[wrt_cnt] <= data_i;
                    end
                end else begin
                    prd_reg[wrt_cnt] <= prd_reg[wrt_cnt];
                    dc_reg[wrt_cnt] <= dc_reg[wrt_cnt];
                end
            end
        end
    endgenerate

    // 写使能寄存器
    always @(posedge clk) begin
        if (rst == 1'b0) begin
            en_reg <= 4'b0;
        end else if ((we_i == 1'b1) && (addr_i[19:16] == 4'h4)) begin
            en_reg <= data_i[3:0];
        end else begin
            en_reg <= en_reg;
        end
    end

    // 读寄存器
    always @(*) begin
        if (rst == 1'b0) begin
            data_o = 32'b0;
        end else begin
            case (addr_i[20:16])
                PRD_REG_BASE + 5'd0: begin
                    data_o = prd_reg[0];
                end
                PRD_REG_BASE + 5'd1: begin
                    data_o = prd_reg[1];
                end
                PRD_REG_BASE + 5'd2: begin
                    data_o = prd_reg[2];
                end
                PRD_REG_BASE + 5'd3: begin
                    data_o = prd_reg[3];
                end
                PRD_REG_BASE + 5'd4: begin
                    data_o = {28'b0, en_reg[3:0]}; // unsigned extension
                end
                DC_REG_BASE + 5'd0: begin
                    data_o = dc_reg[0];
                end
                DC_REG_BASE + 5'd1: begin
                    data_o = dc_reg[1];
                end
                DC_REG_BASE + 5'd2: begin
                    data_o = dc_reg[2];
                end
                DC_REG_BASE + 5'd3: begin
                    data_o = dc_reg[3];
                end
                default: begin
                    data_o = 32'b0;
                end
            endcase
        end
    end

    // 循环计数器
    genvar cnt_cnt;

    generate
        for (cnt_cnt = 0; cnt_cnt < 4; cnt_cnt = cnt_cnt + 1) begin: COUNTER
            always @(posedge clk) begin
                if (rst == 1'b0) begin
                    cyc_cnt[cnt_cnt] <= 32'b0;
                end else if (cyc_cnt[cnt_cnt] <=prd_reg[cnt_cnt]) begin
                    cyc_cnt[cnt_cnt] <= cyc_cnt[cnt_cnt] + 32'b1;
                end else begin
                    // using 1-to-prd_reg for cycling count can avoid invalid number
                    cyc_cnt[cnt_cnt] <= 32'b1;
                end
            end
        end
    endgenerate

    // PWM信号输出(使用DFF打一拍以在输出级防止毛刺产生)
    genvar pwm_cnt;

    generate
        for (pwm_cnt = 0; pwm_cnt < 4; pwm_cnt = pwm_cnt + 1) begin: PWM_OUTPUT
            always @(posedge clk) begin
                if (rst == 1'b0) begin
                    pwm_o[pwm_cnt] <= 1'b0;
                end else if ((en_reg[pwm_cnt] == 1'b1)&&(prd_reg[pwm_cnt]>=dc_reg[pwm_cnt])) begin
                    if (cyc_cnt[pwm_cnt] <= dc_reg[pwm_cnt]) begin
                        pwm_o[pwm_cnt] <= 1'b1;
                    end else begin
                        pwm_o[pwm_cnt] <= 1'b0;
                    end
                end else begin
                    pwm_o[pwm_cnt] <= 1'b0;                
                end 
            end
        end
    endgenerate

endmodule

