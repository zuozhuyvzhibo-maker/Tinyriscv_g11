/*
ldk_ctrl_dk.v - 澶氬懆鏈熷鐞嗗櫒涓绘帶鍒舵ā鍧楋紙鍩轰簬 hold=淇濇寔 璇箟锛?*/
`include "../core/defines.v"

module ldk_ctrl_dk(
    input wire clk,
    input wire rst,

    // from ldk_id_ex (ID/EX 瀵勫瓨鍣ㄨ緭鍑猴紝鍗?EX 鐪嬪埌鐨勬寚浠ゅ瓧)
    input wire [`InstBus] inst_at_ex_i,

    // from ldk_ex
    input wire jump_flag_i,
    input wire [`InstAddrBus] jump_addr_i,
    input wire ext_mem_req_i,
    input wire ext_mem_we_i,
    input wire mem_no_ack_i,
    input wire hold_flag_ex_i,            // 鍏煎淇濈暀
    input wire ife_use_uart,              // IF鎸囦护鏄惁浣跨敤UART杩涜浼犲洖
    input wire ext_inst_done,                  // sID鎸囦护鎵ц瀹屾瘯鐨勬爣蹇?
    // from ldk_rib / bridge
    input wire hold_flag_rib_i,           // 鍏煎淇濈暀
    input wire if_ack_i,                  // 鍙栨寚瀹屾垚
    input wire mem_ack_i,                 // 璁垮瓨瀹屾垚


    // to pipeline registers
    output reg [`Hold_Flag_Bus] hold_flag_o,

    // to ldk_pc_reg
    output reg jump_flag_o,
    output reg [`InstAddrBus] jump_addr_o,

    // to bridge
    output wire if_req_o,
    output wire mem_req_o,
    output wire mem_we_o,                 // 鍙?FSM 鎺у埗鐨勫啓浣胯兘

    // to ldk_ex (鍐欏洖闂ㄦ帶)
    output wire reg_we_gate_o,

    output wire ext_inst_start_o,

    // for SB/SH 鏁版嵁閫氳矾 (mem_rdata 鏃佽矾鎺у埗)
    output wire mem_rdata_use_latched_o,  // 1=鐢╨atched鍊? 0=鐢ㄦˉ鎺ュ綋鍓嶅€?
    // 璋冭瘯
    output wire [4:0] state_o
);

    // ========================================================================
    // 鐘舵€佸畾涔?    // ========================================================================
    localparam S_IF_REQ      = 4'd0;
    localparam S_IF_WAIT     = 4'd1;
    localparam S_LATCH_ID    = 4'd2;
    localparam S_EX          = 4'd3;
    localparam S_MEM_R_REQ   = 4'd4; 
    localparam S_MEM_R_WAIT  = 4'd5;
    localparam S_MEM_W_REQ   = 4'd6;
    localparam S_MEM_W_WAIT  = 4'd7;
    localparam S_SID_REQ     = 4'd8;
    localparam S_SID_WAIT    = 4'd9;
    localparam S_RT_R_REQ    = 4'd10;
    localparam S_RT_R_WAIT   = 4'd11;
    localparam S_IFE_REQ     = 4'd12;
    localparam S_IFE_WAIT    = 4'd13;
    
    localparam S_DONE        = 4'd14;
    // 鏂板rT鎸囦护锛岃鍙栦紶鎰熷櫒涓殑娓╁害


    reg [4:0] state, next_state;

    // 璺宠浆閿佸瓨
    reg                      jump_pending;
    reg [`InstAddrBus]       jump_addr_latched;

    // ========================================================================
    // 褰撳墠 EX 鎷嶆寚浠ゅ瓧娈佃В鐮?    // ========================================================================
    wire [6:0] opcode = inst_at_ex_i[6:0];
    wire [2:0] funct3 = inst_at_ex_i[14:12];
    wire [6:0] funct7 = inst_at_ex_i[31:25];

    wire is_load_inst   = (opcode == `INST_TYPE_L);
    wire is_store_inst  = (opcode == `INST_TYPE_S);
    wire is_sw_inst     = is_store_inst && (funct3 == `INST_SW);
    wire is_sb_sh_inst  = is_store_inst && ((funct3 == `INST_SB) || (funct3 == `INST_SH));
    wire is_rT_inst     = ( opcode == `INST_EXTEND ) && ( funct3 == `INST_RT ) ;
    wire is_sID_inst    = ( opcode == `INST_EXTEND ) && ( funct3 == `INST_SID ) ;
    wire is_ife_inst    = ( opcode == `INST_EXTEND ) && ( funct3 == `INST_IFE ) ;
    wire is_sid_state   = ( state == S_SID_REQ ) || ( state == S_SID_WAIT ) ;
    wire is_ife_state   = ( state == S_IFE_REQ ) || ( state == S_IFE_WAIT ) ;


    // ========================================================================
    // 鐘舵€佸瘎瀛樺櫒
    // ========================================================================
    always @(posedge clk) begin
        if (rst == `RstEnable) state <= S_IF_REQ;
        else                   state <= next_state;
    end

    // ========================================================================
    // 鐘舵€佽浆绉?    // ========================================================================
    always @(*) begin
        next_state = state;
            case (state)
                S_IF_REQ:     next_state = S_IF_WAIT;
                S_IF_WAIT:    if (if_ack_i == `RIB_ACK) next_state = S_LATCH_ID;
                S_LATCH_ID:   next_state = S_EX;
                S_EX: begin
                    if      (is_load_inst)    next_state = S_MEM_R_REQ;
                    else if (is_sw_inst)      next_state = S_MEM_W_REQ;
                    else if (is_sb_sh_inst)   next_state = S_MEM_R_REQ;  // 鍏堣
                    else if (is_rT_inst)      next_state = S_RT_R_REQ;
                    else if (is_sID_inst)     next_state = S_SID_REQ;
                    else if (is_ife_inst)     next_state = S_IFE_REQ;
                    else                      next_state = S_DONE;
                end
                S_MEM_R_REQ:  begin
                                  if (mem_no_ack_i) begin
                                      next_state = S_DONE;
                                  end 
                                  else begin
                                      next_state = S_MEM_R_WAIT;
                                  end
                              end
                S_MEM_R_WAIT: if (mem_ack_i == `RIB_ACK) begin
                                  if (is_sb_sh_inst) next_state = S_MEM_W_REQ;
                                  else               next_state = S_DONE;
                              end
                S_MEM_W_REQ:  next_state = mem_no_ack_i ? S_DONE : S_MEM_W_WAIT;
                S_MEM_W_WAIT: if (mem_ack_i == `RIB_ACK) next_state = S_DONE;
                S_RT_R_REQ:   next_state = S_RT_R_WAIT;
                S_RT_R_WAIT:  if (ext_inst_done == `EXT_INST_DONE) next_state = S_DONE;
                S_SID_REQ:    next_state = S_SID_WAIT;
                S_SID_WAIT:   if (ext_inst_done == `EXT_INST_DONE) next_state = S_DONE;
                S_IFE_REQ:    if (ife_use_uart) next_state = S_IFE_WAIT; else next_state = S_DONE ;
                S_IFE_WAIT:   if (ext_inst_done == `EXT_INST_DONE) next_state = S_DONE;
                S_DONE:       next_state = S_IF_REQ;
                default:      next_state = S_IF_REQ;
            endcase
        end

    // ========================================================================
    // hold_flag 杈撳嚭
    // ========================================================================
    always @(*) begin
        case (state)
            // 鍙栨寚绛夊緟涓細ack 閭ｄ竴鎷嶅垏 Hold_Pc 璁?IF/ID 閿佸瓨
            S_IF_WAIT:   hold_flag_o = (if_ack_i == `RIB_ACK) ? `Hold_Pc : `Hold_Id;
            S_LATCH_ID:  hold_flag_o = `Hold_If;
            S_DONE:      hold_flag_o = `Hold_None;
            default:     hold_flag_o = `Hold_Id;
        endcase
    end

    // ========================================================================
    // 璺宠浆閿佸瓨
    // ========================================================================
    always @(posedge clk) begin
        if (rst == `RstEnable) begin
            jump_pending      <= 1'b0;
            jump_addr_latched <= `ZeroWord;
        end else if ((state == S_EX) && (jump_flag_i == `JumpEnable)) begin
            jump_pending      <= 1'b1;
            jump_addr_latched <= jump_addr_i;
        end else if (state == S_DONE) begin
            jump_pending      <= 1'b0;
            jump_addr_latched <= `ZeroWord;
        end
    end

    // ========================================================================
    // 璺宠浆杈撳嚭锛堝惈涓柇鍝嶅簲锛?    // ========================================================================
    always @(*) begin
        if ((state == S_DONE) && jump_pending) begin
            jump_flag_o = `JumpEnable;
            jump_addr_o = jump_addr_latched;
        end else begin
            jump_flag_o = `JumpDisable;
            jump_addr_o = `ZeroWord;
        end
    end

    // ========================================================================
    // 鍚勭闂ㄦ帶淇″彿
    // ========================================================================

    // 鍙栨寚璇锋眰
    assign if_req_o = (state == S_IF_REQ) ; // 涓€鍛ㄦ湡鐨勮剦鍐蹭俊鍙?
    // 璁垮瓨璇锋眰 (瑕嗙洊 ldk_ex.v 鐨?mem_req_o)
    assign mem_req_o = (state == S_MEM_R_REQ) || ( state == S_MEM_R_WAIT )
                        || (state == S_MEM_W_REQ) || ( state == S_MEM_W_WAIT ) 
                        || ( state == S_RT_R_REQ ) || ( state == S_RT_R_WAIT )
                        || ( (is_sid_state || is_ife_state) && ext_mem_req_i ) ;

    // 璁垮瓨鍐欎娇鑳?(FSM 鐩存帴鎺у埗锛屼笉渚濊禆 ldk_ex.v 鐨?mem_we_o, 褰撳嚭鐜版嫇灞曟寚浠ゆ椂锛屽皢鎺у埗鏉冧氦缁欒繍绠楀崟鍏僥x)
    assign mem_we_o = (state == S_MEM_W_REQ) 
                        || ( state == S_RT_R_REQ ) 
                        || ( (is_sid_state || is_ife_state) && ext_mem_we_i ) ;

    assign ext_inst_start_o = (( state == S_SID_REQ ) && is_sID_inst)
                           || (( state == S_IFE_REQ ) && is_ife_inst && ife_use_uart) ;

    // SB/SH 鍦ㄥ啓闃舵浣跨敤涔嬪墠閿佸瓨鐨?mem_rdata
    assign mem_rdata_use_latched_o = is_sb_sh_inst
                                  && ((state == S_MEM_W_REQ));

    // 瀵勫瓨鍣ㄥ啓鍥為棬鎺?    //   - 鏅€氭寚浠わ細S_EX 鎷嶅啓鍥?    //   - Load锛?   S_MEM_R_WAIT 鐨?ack 鎷嶅啓鍥?    //   - Store/Branch锛歟x.v 鐨?reg_we 鏈韩灏辨槸 0
    assign reg_we_gate_o = ((state == S_EX) && !is_load_inst && !is_store_inst && !is_sID_inst && !is_rT_inst && !is_ife_inst)
                        || ((state == S_MEM_R_WAIT) && (mem_ack_i == `RIB_ACK) && is_load_inst)
                        || ((state == S_MEM_R_REQ)  && mem_no_ack_i && is_load_inst)
                        || ((state == S_RT_R_WAIT)  && (ext_inst_done == `EXT_INST_DONE) && is_rT_inst)
                        || ((state == S_IFE_REQ)    && !ife_use_uart && is_ife_inst)
                        || ((state == S_IFE_WAIT)   && (ext_inst_done == `EXT_INST_DONE) && is_ife_inst) ;


    assign state_o = state;

    

endmodule
