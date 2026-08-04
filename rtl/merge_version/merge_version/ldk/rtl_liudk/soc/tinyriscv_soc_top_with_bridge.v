`include "../core/defines.v"

module ldk_tinyriscv_soc_top_with_bridge(

    input wire clk,
    input wire rst,

    output wire succ,        // 娴嬭瘯鏄惁鎴愬姛淇″彿

    input wire uart_debug_pin, // 涓插彛涓嬭浇浣胯兘寮曡剼

    output wire uart_tx_pin, // UART鍙戦€佸紩鑴?
    input wire uart_rx_pin,  // UART鎺ユ敹寮曡剼

    inout wire io_sda, // IIC鏁版嵁鎬荤嚎
    output io_scl,       // IIC鏃堕挓鎬荤嚎
    output wire [3:0] pwm_o

    );

    wire [`BridgeBus] bmaster_TX_data; // 妗ユ帴妯″潡鐨勪富鎺ュ彛鏁版嵁杈撳嚭鎬荤嚎
    wire [`BridgeBus] bmaster_RX_data; // 妗ユ帴妯″潡鐨勪富鎺ュ彛
    wire [`BridgeBus] bslave_TX_data;  // 妗ユ帴妯″潡鐨勪粠鎺ュ彛鏁版嵁杈撳嚭鎬荤嚎
    wire [`BridgeBus] bslave_RX_data;  // 妗ユ帴妯″潡鐨勪粠鎺ュ彛鏁版嵁杈撳叆鎬荤嚎

    //IIC妯″潡鎬荤嚎
    wire SCL_o ;  
    wire SDA_o ;
    wire SDA_oe_o ;
    wire SDA_i ;

    ldk_tinyriscv_soc_top u_tinyriscv_soc_top (
        .clk(clk),
        .rst(rst),
        
        .succ(succ),
        
        .uart_debug_pin(uart_debug_pin),
        .uart_tx_pin(uart_tx_pin),
        .uart_rx_pin(uart_rx_pin),

        // 妗ユ帴鎺ュ彛杩炴帴
        .bmaster_TX_data(bmaster_TX_data),
        .bmaster_RX_data(bmaster_RX_data),
        // IIC妯″潡鎺ュ彛
        .SCL_o(SCL_o) ,  
        .SDA_o(SDA_o) ,  
        .SDA_oe_o(SDA_oe_o), 
        .SDA_i(SDA_i)  ,
        .pwm_o(pwm_o)

        );

    ldk_bridge_slave_top u_bridge_slave_top (
        .clk(clk),
        .rst(rst),
        .bslave_RX_data(bmaster_TX_data), // 杩炴帴妗ユ帴涓绘帴鍙ｇ殑杈撳嚭
        .bslave_TX_data(bmaster_RX_data)  // 杩炴帴妗ユ帴涓绘帴鍙ｇ殑杈撳叆
    );

    assign io_scl = SCL_o ;
    assign io_sda = SDA_oe_o ? ( SDA_o ? 1'bz : 1'b0 ) : 1'bz ;  // 闇€瑕佹牳瀹炴纭€?
    assign SDA_i = io_sda ;

endmodule
