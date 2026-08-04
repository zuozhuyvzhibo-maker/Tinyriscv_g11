// Formal VCS/Verdi source list. Keep production RTL unchanged while using
// a VCS-only list that omits four uninstantiated legacy utility files whose
// declaration-after-use syntax is rejected by strict VCS.
+incdir+tb
-f filelist_vcs_rtl.f

rtl/cores/ldk/fpga/bridge_slave.v
rtl/fpga/shared_fpga_memory.v
rtl/fpga/lhr_fpga_bridge_adapter.v
rtl/fpga/ldk_fpga_bridge_adapter.v
rtl/fpga/sy_fpga_bridge_adapter.v
rtl/fpga/wje_fpga_bridge_adapter.v
rtl/fpga/merged_fpga_bridge_bank.v
rtl/fpga/tinyriscv_merged_fpga_top.v
rtl/fpga/merged_board_control.v
rtl/fpga/tinyriscv_merged_fpga_key_top.v

tb/merged_core_smoke_tb.v
tb/merged_rv32i_directed_tb.v
tb/merged_extensions_tb.v
tb/merged_pwm_tb.v
tb/merged_uart_tb.v
tb/merged_bridge_protocol_tb.v
tb/shared_uart_debug_tb.v
tb/merged_switch_clear_tb.v
tb/merged_all_isa_selfcheck_tb.v
tb/merged_ldk_rt_repeat_tb.v
