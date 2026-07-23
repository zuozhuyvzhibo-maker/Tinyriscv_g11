
module tinyriscv_top_IO(
    input wire clk,
    input wire rst,

    output wire over,         // 测试是否完成信号
    output wire succ,         // 测试是否成功信号

    //output wire halted_ind,  // jtag是否已经halt住CPU信号

    input wire uart_debug_pin, // 串口下载使能引脚

    output wire uart_tx_pin, // UART发送引脚
    input wire uart_rx_pin,  // UART接收引脚
    //inout wire[1:0] gpio,    // GPIO引脚

    //input wire jtag_TCK,     // JTAG TCK引脚
    //input wire jtag_TMS,     // JTAG TMS引脚
    //input wire jtag_TDI,     // JTAG TDI引脚
    //output wire jtag_TDO,    // JTAG TDO引脚

    //input wire spi_miso,     // SPI MISO引脚
    //output wire spi_mosi,    // SPI MOSI引脚
    //output wire spi_ss,      // SPI SS引脚
    //output wire spi_clk      // SPI CLK引脚
);

	wire	clk_core, rst_core, over_core, succ_core, halted_ind_core, uart_debug_pin_core;
	wire	uart_rx_pin_core, uart_tx_pin_core;
	wire	jtag_TCK_core, jtag_TMS_core, jtag_TDI_core, jtag_TDO_core;
	wire	spi_miso_core, spi_mosi_core, spi_ss_core, spi_clk_core;
	wire	[1:0]	gpio_out_core, gpio_in_core;
	wire	[3:0]	gpio_io_ctrl;
	reg		OEN_inout_0, IE_inout_0, DS_inout_0;
	reg		OEN_inout_1, IE_inout_1, DS_inout_1;

// Input Ports	
PDDW0204CDG 	mclk		(.OEN(1'b1),.I(1'b0),.PAD(clk),				.C(clk_core),				.DS(1'b0),.PE(1'b0),.IE(1'b1));
PDDW0204CDG 	mrst		(.OEN(1'b1),.I(1'b0),.PAD(rst),				.C(rst_core),				.DS(1'b0),.PE(1'b0),.IE(1'b1));
PDDW0204CDG 	muart_d		(.OEN(1'b1),.I(1'b0),.PAD(uart_debug_pin),	.C(uart_debug_pin_core),	.DS(1'b0),.PE(1'b0),.IE(1'b1));
PDDW0204CDG 	muart_rx	(.OEN(1'b1),.I(1'b0),.PAD(uart_rx_pin),		.C(uart_rx_pin_core),		.DS(1'b0),.PE(1'b0),.IE(1'b1));
PDDW0204CDG 	mjtag_TCK	(.OEN(1'b1),.I(1'b0),.PAD(jtag_TCK),		.C(jtag_TCK_core),			.DS(1'b0),.PE(1'b0),.IE(1'b1));
PDDW0204CDG 	mjtag_TMS	(.OEN(1'b1),.I(1'b0),.PAD(jtag_TMS),		.C(jtag_TMS_core),			.DS(1'b0),.PE(1'b0),.IE(1'b1));
PDDW0204CDG 	mjtag_TDI	(.OEN(1'b1),.I(1'b0),.PAD(jtag_TDI),		.C(jtag_TDI_core),			.DS(1'b0),.PE(1'b0),.IE(1'b1));
PDDW0204CDG 	mspi_miso	(.OEN(1'b1),.I(1'b0),.PAD(spi_miso),		.C(spi_miso_core),			.DS(1'b0),.PE(1'b0),.IE(1'b1));

// Output Ports	
PDDW0204CDG 	mover		(.OEN(1'b0),.I(over_core),			.PAD(over),			.C(),.DS(1'b1),.PE(1'b0),.IE(1'b0));
PDDW0204CDG 	msucc		(.OEN(1'b0),.I(succ_core),			.PAD(succ),			.C(),.DS(1'b1),.PE(1'b0),.IE(1'b0));
PDDW0204CDG 	mhalt		(.OEN(1'b0),.I(halted_ind_core),	.PAD(halted_ind),	.C(),.DS(1'b1),.PE(1'b0),.IE(1'b0));
PDDW0204CDG 	muart_tx	(.OEN(1'b0),.I(uart_tx_pin_core),	.PAD(uart_tx_pin),	.C(),.DS(1'b1),.PE(1'b0),.IE(1'b0));
PDDW0204CDG 	mjtag_TDO	(.OEN(1'b0),.I(jtag_TDO_core),		.PAD(jtag_TDO),		.C(),.DS(1'b1),.PE(1'b0),.IE(1'b0));
PDDW0204CDG 	mspi_mosi	(.OEN(1'b0),.I(spi_mosi_core),		.PAD(spi_mosi),		.C(),.DS(1'b1),.PE(1'b0),.IE(1'b0));
PDDW0204CDG 	mspi_ss		(.OEN(1'b0),.I(spi_ss_core),		.PAD(spi_ss),		.C(),.DS(1'b1),.PE(1'b0),.IE(1'b0));
PDDW0204CDG 	mspi_clk	(.OEN(1'b0),.I(spi_clk_core),		.PAD(spi_clk),		.C(),.DS(1'b1),.PE(1'b0),.IE(1'b0));

// InOut Ports	
always@ (*) begin
	case(gpio_io_ctrl[1:0])
		2'b00:	begin //高阻
				OEN_inout_0 = 1;
				IE_inout_0  = 0;
				DS_inout_0  = 1;
				end
		2'b01:	begin //输出
				OEN_inout_0 = 0;
				IE_inout_0  = 0;
				DS_inout_0  = 1;
				end
		2'b10:	begin //输入
				OEN_inout_0 = 1;
				IE_inout_0  = 1;
				DS_inout_0  = 0;
				end
		2'b11:	begin //无效(高阻)
				OEN_inout_0 = 1;
				IE_inout_0  = 0;
				DS_inout_0  = 1;
				end
	endcase
	end
PDDW0204CDG 	mgpio0 	(.OEN(OEN_inout_0), .I(gpio_out_core[0 ]), .PAD(gpio[0 ]), .C(gpio_in_core[0 ]),.DS(DS_inout_0),.PE(1'b0),.IE(IE_inout_0));
// InOut Ports	
always@ (*) begin
	case(gpio_io_ctrl[1:0])
		2'b00:	begin //高阻
				OEN_inout_1 = 1;
				IE_inout_1  = 0;
				DS_inout_1  = 1;
				end
		2'b01:	begin //输出
				OEN_inout_1 = 0;
				IE_inout_1  = 0;
				DS_inout_1  = 1;
				end
		2'b10:	begin //输入
				OEN_inout_1 = 1;
				IE_inout_1  = 1;
				DS_inout_1  = 0;
				end
		2'b11:	begin //无效(高阻)
				OEN_inout_1 = 1;
				IE_inout_1  = 0;
				DS_inout_1  = 1;
				end
	endcase
	end
PDDW0204CDG 	mgpio1 	(.OEN(OEN_inout_1), .I(gpio_out_core[1 ]), .PAD(gpio[1 ]), .C(gpio_in_core[1 ]),.DS(DS_inout_1),.PE(1'b0),.IE(IE_inout_1));


tinyriscv_soc_top		tinyriscv(
    .clk(clk_core),
    .rst(rst_core),

    .over(over_core),         // 测试是否完成信号
    .succ(succ_core),         // 测试是否成功信号

    .halted_ind(halted_ind_core),  // jtag是否已经halt住CPU信号

    .uart_debug_pin(uart_debug_pin_core), // 串口下载使能引脚

    .uart_tx_pin(uart_tx_pin_core), // UART发送引脚
    .uart_rx_pin(uart_rx_pin_core),  // UART接收引脚
    .gpio_io_ctrl(gpio_io_ctrl),    // GPIO引脚控制，每2位控制1个IO的模式，0: 高阻，1：输出，2：输入
    .gpio_out(gpio_out_core),    // GPIO引脚输出数据
    .gpio_in(gpio_in_core),    // GPIO引脚输入数据

    .jtag_TCK(jtag_TCK_core),     // JTAG TCK引脚
    .jtag_TMS(jtag_TMS_core),     // JTAG TMS引脚
    .jtag_TDI(jtag_TDI_core),     // JTAG TDI引脚
    .jtag_TDO(jtag_TDO_core),    // JTAG TDO引脚

    .spi_miso(spi_miso_core),     // SPI MISO引脚
    .spi_mosi(spi_mosi_core),    // SPI MOSI引脚
    .spi_ss(spi_ss_core),      // SPI SS引脚
    .spi_clk(spi_clk_core)      // SPI CLK引脚
);

endmodule