set script_dir [file normalize [file dirname [info script]]]
set root_dir [file normalize [file join $script_dir ".."]]

set use_vio 0
if {[info exists ::env(TINYRISCV_MERGED_USE_VIO)] &&
    ($::env(TINYRISCV_MERGED_USE_VIO) eq "1")} {
    set use_vio 1
}

if {$use_vio} {
    set control_mode "vio"
    set top_name "tinyriscv_merged_fpga_vio_top"
    set filelist_path [file join $root_dir "filelist_vio.f"]
    set xdc_path [file join $script_dir "constrs" "ax7035_vio.xdc"]
} else {
    set control_mode "keys"
    set top_name "tinyriscv_merged_fpga_key_top"
    set filelist_path [file join $root_dir "filelist_fpga.f"]
    set xdc_path [file join $script_dir "constrs" "ax7035_keys.xdc"]
}

set report_dir [file normalize [file join $root_dir "verification" "vivado_$control_mode"]]
file mkdir $report_dir

if {[info exists ::env(TINYRISCV_MERGED_PROJ_DIR)]} {
    set proj_dir [file normalize $::env(TINYRISCV_MERGED_PROJ_DIR)]
} elseif {($tcl_platform(platform) eq "windows") && [file isdirectory "C:/fpga"]} {
    # Vivado 2019.1 can fail to remove .Xil worker directories in a long,
    # OneDrive-synchronized project path. Keep generated projects short and
    # copy all durable reports and bitstreams back into the repository.
    set proj_dir [file normalize [file join "C:/fpga" "tinyriscv_merged_g11_$control_mode"]]
} elseif {[info exists ::env(TEMP)]} {
    set proj_dir [file normalize [file join $::env(TEMP) "tinyriscv_merged_g11_$control_mode"]]
} else {
    set proj_dir [file normalize [file join $root_dir "build" "vivado_$control_mode"]]
}

set proj_name "tinyriscv_merged_ax7035_$control_mode"
if {[info exists ::env(TINYRISCV_MERGED_PROJ_NAME)]} {
    set proj_name $::env(TINYRISCV_MERGED_PROJ_NAME)
}

proc collect_filelist {filelist_path sources_name incdirs_name} {
    upvar 1 $sources_name sources
    upvar 1 $incdirs_name incdirs

    set filelist_path [file normalize $filelist_path]
    set base_dir [file dirname $filelist_path]
    set handle [open $filelist_path r]
    while {[gets $handle raw_line] >= 0} {
        set line [string trim $raw_line]
        if {($line eq "") || ([string index $line 0] eq "#")} {
            continue
        }

        if {[regexp {^-f[ \t]+(.+)$} $line match nested_filelist]} {
            collect_filelist [file join $base_dir $nested_filelist] sources incdirs
        } elseif {[regexp {^\+incdir\+(.+)$} $line match include_dir]} {
            set include_path [file normalize [file join $base_dir $include_dir]]
            if {[lsearch -exact $incdirs $include_path] < 0} {
                lappend incdirs $include_path
            }
        } else {
            set source_path [file normalize [file join $base_dir $line]]
            if {![file exists $source_path]} {
                close $handle
                error "Source listed in $filelist_path does not exist: $source_path"
            }
            if {[lsearch -exact $sources $source_path] < 0} {
                lappend sources $source_path
            }
        }
    }
    close $handle
}

set sources [list]
set incdirs [list]
collect_filelist $filelist_path sources incdirs

create_project $proj_name $proj_dir -part xc7a35tfgg484-2 -force
add_files -fileset sources_1 $sources
set_property include_dirs $incdirs [get_filesets sources_1]
set_property top $top_name [get_filesets sources_1]
add_files -fileset constrs_1 $xdc_path

if {$use_vio} {
    create_ip -name vio -vendor xilinx.com -library ip \
        -module_name merged_chip_sel_vio
    set_property -dict [list \
        CONFIG.C_NUM_PROBE_IN {2} \
        CONFIG.C_NUM_PROBE_OUT {2} \
        CONFIG.C_PROBE_IN0_WIDTH {1} \
        CONFIG.C_PROBE_IN1_WIDTH {4} \
        CONFIG.C_PROBE_OUT0_WIDTH {2} \
        CONFIG.C_PROBE_OUT1_WIDTH {1} \
        CONFIG.C_PROBE_OUT0_INIT_VAL {0x0} \
        CONFIG.C_PROBE_OUT1_INIT_VAL {0x0}] \
        [get_ips merged_chip_sel_vio]
    generate_target all [get_ips merged_chip_sel_vio]
}

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

set_property strategy Flow_PerfOptimized_high [get_runs synth_1]
set_property strategy Performance_Explore [get_runs impl_1]

puts "MERGED_BUILD control=$control_mode top=$top_name"
puts "MERGED_BUILD project=$proj_dir/$proj_name.xpr"
puts "MERGED_BUILD source_count=[llength $sources]"

launch_runs synth_1 -jobs 4
wait_on_run synth_1
set synth_status [get_property STATUS [get_runs synth_1]]
puts "MERGED_BUILD synthesis=$synth_status"
if {[string first "synth_design Complete" $synth_status] < 0} {
    puts "MERGED_BUILD_ERROR synthesis did not complete"
    exit 1
}

open_run synth_1
report_utilization -file [file join $report_dir "synth_utilization.rpt"]
report_utilization -hierarchical -hierarchical_depth 5 \
    -file [file join $report_dir "synth_utilization_hierarchical.rpt"]
report_timing_summary -report_unconstrained \
    -file [file join $report_dir "synth_timing_summary.rpt"]

set hierarchy_file [open [file join $report_dir "four_core_hierarchy_check.txt"] w]
set hierarchy_ok 1
foreach tile_name {u_lhr_tile u_ldk_tile u_sy_tile u_wje_tile} {
    set tile_cells [get_cells -hierarchical -quiet -filter "NAME =~ *$tile_name*"]
    set tile_count [llength $tile_cells]
    puts $hierarchy_file "$tile_name cells=$tile_count"
    if {$tile_count == 0} {
        set hierarchy_ok 0
    }
}
puts $hierarchy_file "all_four_tiles_present=$hierarchy_ok"
close $hierarchy_file
close_design

if {!$hierarchy_ok} {
    puts "MERGED_BUILD_ERROR one or more core tile hierarchies were optimized away"
    exit 1
}

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
set impl_status [get_property STATUS [get_runs impl_1]]
puts "MERGED_BUILD implementation=$impl_status"
if {[string first "write_bitstream Complete" $impl_status] < 0} {
    puts "MERGED_BUILD_ERROR implementation or bitstream generation failed"
    exit 1
}

open_run impl_1
report_utilization -file [file join $report_dir "impl_utilization.rpt"]
report_utilization -hierarchical -hierarchical_depth 5 \
    -file [file join $report_dir "impl_utilization_hierarchical.rpt"]
report_timing_summary -delay_type min_max -report_unconstrained \
    -file [file join $report_dir "impl_timing_summary.rpt"]
if {$use_vio} {
    # The Xilinx Debug Hub adds set_bus_skew constraints.  Keep their result
    # beside the normal timing report so Timing 38-436 can be audited instead
    # of being dismissed from the console log alone.
    report_bus_skew -file [file join $report_dir "impl_bus_skew.rpt"]
}
report_drc -file [file join $report_dir "impl_drc.rpt"]
report_route_status -file [file join $report_dir "impl_route_status.rpt"]
report_power -file [file join $report_dir "impl_power.rpt"]

set debug_probes_file ""
if {$use_vio} {
    set debug_probes_file [file join $report_dir "$top_name.ltx"]
    write_debug_probes -force $debug_probes_file
}

set bit_file [file join [get_property DIRECTORY [get_runs impl_1]] "$top_name.bit"]
set copied_bit_file [file join $report_dir "$top_name.bit"]
if {![file exists $bit_file]} {
    puts "MERGED_BUILD_ERROR expected bitstream not found: $bit_file"
    close_design
    exit 1
}
file copy -force $bit_file $copied_bit_file

set summary_file [open [file join $report_dir "build_summary.txt"] w]
puts $summary_file "Control mode: $control_mode"
puts $summary_file "Top: $top_name"
puts $summary_file "Part: xc7a35tfgg484-2"
puts $summary_file "Source count: [llength $sources]"
puts $summary_file "Four core tile hierarchy present: $hierarchy_ok"
puts $summary_file "Synthesis: $synth_status"
puts $summary_file "Implementation: $impl_status"
puts $summary_file "Bitstream: $copied_bit_file"
if {$use_vio} {
    puts $summary_file "Debug probes: $debug_probes_file"
}
foreach property_name {STATS.WNS STATS.TNS STATS.WHS STATS.THS} {
    if {[lsearch -exact [list_property [get_runs impl_1]] $property_name] >= 0} {
        puts $summary_file "$property_name: [get_property $property_name [get_runs impl_1]]"
    }
}
close $summary_file
close_design

puts "MERGED_BUILD_SUCCESS bitstream=$copied_bit_file"
exit 0
