// VCS-only source list. The four legacy SY/WJE full-handshake utility
// modules are intentionally omitted: they are not instantiated by the
// merged tops, and strict VCS rejects their declaration-after-use style.
// No production RTL is changed by this compatibility filelist.
+incdir+rtl/cores/lhr/include
+incdir+rtl/cores/ldk/include
+incdir+rtl/cores/sy/include
+incdir+rtl/cores/wje/include

rtl/common/shared_regs.v
rtl/common/shared_pwm.v
rtl/common/shared_uart_debug.v

rtl/cores/lhr/utils/gen_dff.v
rtl/cores/lhr/core/pc_reg.v
rtl/cores/lhr/core/if_id.v
rtl/cores/lhr/core/id.v
rtl/cores/lhr/core/id_ex.v
rtl/cores/lhr/core/ex.v
rtl/cores/lhr/core/ctrl.v
rtl/cores/lhr/core/rib_ext_bridge.v
rtl/cores/lhr/core/tinyriscv.v
rtl/cores/lhr/perips/ext_mem_bridge.v
rtl/cores/lhr/perips/uart.v
rtl/cores/lhr/perips/i2c.v

rtl/cores/ldk/utils/gen_dff.v
rtl/cores/ldk/utils/gen_buf.v
rtl/cores/ldk/utils/full_handshake_rx.v
rtl/cores/ldk/utils/full_handshake_tx.v
rtl/cores/ldk/core/pc_reg.v
rtl/cores/ldk/core/if_id.v
rtl/cores/ldk/core/id.v
rtl/cores/ldk/core/id_ex.v
rtl/cores/ldk/core/ex.v
rtl/cores/ldk/core/ctrl_dk.v
rtl/cores/ldk/core/rib.v
rtl/cores/ldk/core/tinyriscv.v
rtl/cores/ldk/perips/bridge_master.v
rtl/cores/ldk/perips/uart.v
rtl/cores/ldk/perips/iic_dk.v

rtl/cores/sy/utils/gen_dff.v
rtl/cores/sy/utils/gen_buf.v
rtl/cores/sy/core/pc_reg.v
rtl/cores/sy/core/if_id.v
rtl/cores/sy/core/id.v
rtl/cores/sy/core/id_ex.v
rtl/cores/sy/core/ex.v
rtl/cores/sy/core/ctrl.v
rtl/cores/sy/core/rib.v
rtl/cores/sy/core/tinyriscv.v
rtl/cores/sy/perips/bridge.v
rtl/cores/sy/perips/uart.v
rtl/cores/sy/perips/i2c.v

rtl/cores/wje/utils/gen_dff.v
rtl/cores/wje/utils/gen_buf.v
rtl/cores/wje/core/pc_reg.v
rtl/cores/wje/core/if_id.v
rtl/cores/wje/core/id.v
rtl/cores/wje/core/ex.v
rtl/cores/wje/core/id_ex.v
rtl/cores/wje/core/ctrl.v
rtl/cores/wje/core/rib.v
rtl/cores/wje/core/tinyriscv.v
rtl/cores/wje/perips/bridge.v
rtl/cores/wje/perips/uart.v
rtl/cores/wje/perips/i2c.v

rtl/soc/lhr_core_tile.v
rtl/soc/ldk_core_tile.v
rtl/soc/sy_core_tile.v
rtl/soc/wje_core_tile.v
rtl/soc/tinyriscv_merged_chip_top.v
