# Merge Version Summary

## Top Level

- Added `tinyriscv_merge_top.v`.
- `chip_sel == 3'd0`: selects LHR core.
- `chip_sel == 3'd1`: selects LDK core.
- `chip_sel == 3'd2`: selects WJE core.
- `chip_sel == 3'd3`: selects SY core.
- Other `chip_sel` values keep all cores in reset and drive safe default outputs.

## Important Fixes

- Prefixed the four source trees with `lhr_`, `ldk_`, `wje_`, and `sy_` module names to avoid duplicate module definitions.
- Added missing LDK `rom.v` and `ram.v` into `merge_version/ldk/rtl_liudk/perips`.
- Added `merge_filelist.f` for the merged build.
- Made LDK/WJE core files include their local `../core/defines.v`, avoiding macro leakage from another core's `defines.v`.
- Exposed all four PWM channels from LHR and LDK wrappers.
- Isolated IIC SDA/SCL per core in the merged top. Only the selected core is connected to the board-level IIC bus, preventing unselected reset-state IIC outputs from causing `X` contention.
- Added the SY core to the merged top as `chip_sel == 3'd3`; its UART, PWM, IIC, `succ`, and `over` signals are selected through the same top-level mux path.
- Expanded SY FPGA PWM output from 3 bits to 4 bits so all four PWM channels can be verified at the merged top level.
- Fixed LDK `ctrl_dk.v` rT state transition so rT enters `S_RT_R_REQ/S_RT_R_WAIT`.
- Cleaned LDK `S_MEM_R_WAIT` transition formatting so the state block is explicit.

## Verification

- Added `tb/tinyriscv_merge_validation_tb.v`.
- Added `run_merge_regression.ps1`.
- The regression covers:
  - 20 basic RV32I tests: `inst_add`, `inst_andi`, `inst_auipc`, `inst_beq`, `inst_bge`, `inst_bgeu`, `inst_blt`, `inst_bltu`, `inst_bne`, `inst_jal`, `inst_jalr`, `inst_lui`, `inst_ori`, `inst_simple`, `inst_slli`, `inst_slti`, `inst_sltiu`, `inst_srai`, `inst_srli`, `inst_xori`.
  - Extension/peripheral tests: `sID_inst`, `IF_inst`, `Temp`, `PWM_inst`.
  - All tests are run with `chip_sel = 0`, `1`, `2`, and `3`.
  - `chip_sel == 3` uses SY's own extension/peripheral programs under `sy/Test`.
  - The SY rT test initializes the SY IIC temperature read register to `0x32` in the TB. This avoids simulation-only `X` propagation from SY's unreset `in_reg` before the autonomous IIC reader has completed its first transaction.

Result:

```text
ALL TESTS PASSED
```

Summary log:

- `verification/merge_regression_summary.txt`

## Note

This merge keeps each reduced core structurally independent and uses `chip_sel` to select one active core at a time while sharing the top-level pins and verification path. It does not physically refactor the four cores to use one single instantiated register file inside all cores. If the final resource-sharing requirement is interpreted as "only one synthesized regs instance for all cores", that needs a deeper core-interface refactor.
