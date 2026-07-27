set script_dir [file normalize [file dirname [info script]]]
set root_dir [file normalize [file join $script_dir ".."]]
set report_dir [file normalize [file join $root_dir "verification" "vivado"]]
file mkdir $report_dir

if {[info exists ::env(TINYRISCV_BRIDGE_FINAL_PROJ_DIR)]} {
    set proj_dir [file normalize $::env(TINYRISCV_BRIDGE_FINAL_PROJ_DIR)]
} else {
    set proj_dir [file normalize [file join $script_dir "vivado_bridge_final_ax7035"]]
}

if {[info exists ::env(TINYRISCV_BRIDGE_FINAL_PROJ_NAME)]} {
    set proj_name $::env(TINYRISCV_BRIDGE_FINAL_PROJ_NAME)
} else {
    set proj_name "tinyriscv_bridge_final_ax7035"
}

create_project $proj_name $proj_dir -part xc7a35tfgg484-2 -force

set srcs [list \
    "$root_dir/fpga/tinyriscv_soc_top_bridge_fpga.v" \
    "$root_dir/fpga/bridge_fpga.v" \
    "$root_dir/fpga/fpga_uart_debug.v" \
    "$root_dir/rtl/core/ctrl.v" \
    "$root_dir/rtl/core/defines.v" \
    "$root_dir/rtl/core/ex.v" \
    "$root_dir/rtl/core/id.v" \
    "$root_dir/rtl/core/id_ex.v" \
    "$root_dir/rtl/core/if_id.v" \
    "$root_dir/rtl/core/pc_reg.v" \
    "$root_dir/rtl/core/regs.v" \
    "$root_dir/rtl/core/rib_ext_bridge.v" \
    "$root_dir/rtl/core/tinyriscv.v" \
    "$root_dir/rtl/utils/gen_dff.v" \
    "$root_dir/rtl/perips/uart.v" \
    "$root_dir/rtl/perips/pwm.v" \
    "$root_dir/rtl/perips/i2c.v" \
    "$root_dir/rtl/perips/ext_mem_bridge.v" \
    "$root_dir/rtl/soc/tinyriscv_chip_top_bridge.v" \
]

add_files -fileset sources_1 $srcs
set_property include_dirs [list "$root_dir/fpga" "$root_dir/rtl/core"] [get_filesets sources_1]
set_property top tinyriscv_soc_top_bridge_fpga [get_filesets sources_1]

add_files -fileset constrs_1 "$root_dir/fpga/constrs/tinyriscv.xdc"

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "Created Vivado project:"
puts "  $proj_dir/$proj_name.xpr"
puts "Top:"
puts "  tinyriscv_soc_top_bridge_fpga"
puts "Part:"
puts "  xc7a35tfgg484-2"

launch_runs synth_1 -jobs 4
wait_on_run synth_1

set synth_status [get_property STATUS [get_runs synth_1]]
puts "Synthesis status: $synth_status"
if {[string first "synth_design Complete" $synth_status] < 0} {
    puts "ERROR: synthesis did not complete successfully"
    exit 1
}

open_run synth_1
report_utilization -file [file join $report_dir "synth_utilization.rpt"]
report_timing_summary -file [file join $report_dir "synth_timing_summary.rpt"]
close_design

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

set impl_status [get_property STATUS [get_runs impl_1]]
puts "Implementation status: $impl_status"
if {[string first "write_bitstream Complete" $impl_status] < 0} {
    puts "ERROR: bitstream generation did not complete successfully"
    exit 1
}

open_run impl_1
report_utilization -file [file join $report_dir "impl_utilization.rpt"]
report_timing_summary -delay_type min_max -report_unconstrained \
    -file [file join $report_dir "impl_timing_summary.rpt"]
report_drc -file [file join $report_dir "impl_drc.rpt"]
report_power -file [file join $report_dir "impl_power.rpt"]

set bit_file [file join [get_property DIRECTORY [get_runs impl_1]] \
    "tinyriscv_soc_top_bridge_fpga.bit"]
if {[file exists $bit_file]} {
    file copy -force $bit_file [file join $report_dir "tinyriscv_soc_top_bridge_fpga.bit"]
}

set summary_file [open [file join $report_dir "build_summary.txt"] "w"]
puts $summary_file "Top: tinyriscv_soc_top_bridge_fpga"
puts $summary_file "Part: xc7a35tfgg484-2"
puts $summary_file "Synthesis: $synth_status"
puts $summary_file "Implementation: $impl_status"
foreach property_name {STATS.WNS STATS.TNS STATS.WHS STATS.THS} {
    if {[lsearch -exact [list_property [get_runs impl_1]] $property_name] >= 0} {
        puts $summary_file "$property_name: [get_property $property_name [get_runs impl_1]]"
    }
}
close $summary_file
close_design

exit 0
