// ============================================================
// tinyriscv VCS 仿真文件列表
// 用法: vcs -f filelist.f -full64 -sverilog -timescale=1ns/1ps
// ============================================================

+incdir+./core

// --- 工具库 (utils) ---
./utils/gen_dff.v
./utils/full_handshake_rx.v
./utils/full_handshake_tx.v
./utils/gen_buf.v

// --- 处理器核 (core) ---
./core/defines.v
./core/pc_reg.v
./core/if_id.v
./core/id.v
./core/id_ex.v
./core/ex.v
./core/regs.v
./core/ctrl.v
./core/rib.v
./core/tinyriscv.v

// --- 外设与桥 (perips) ---
./perips/rom_ext.v
./perips/ram_ext.v
./perips/bridge.v
./perips/bridge_fpga.v
./perips/uart.v
./perips/pwm.v
./perips/i2c.v

// --- 调试 (debug) ---
./debug/uart_debug.v

// --- 系统顶层 (soc) ---
./soc/tinyriscv_soc_top.v
./soc/tinyriscv_soc_top_FPGA.v

// --- 测试平台 (Test) ---
./Test/tinyriscv_soc_tb.v
