set script_dir [file normalize [file dirname [info script]]]
set root_dir [file normalize [file join $script_dir ".."]]

set control_mode "keys"
if {[info exists ::env(TINYRISCV_MERGED_USE_VIO)] &&
    ($::env(TINYRISCV_MERGED_USE_VIO) eq "1")} {
    set control_mode "vio"
}

if {[info exists ::env(TINYRISCV_MERGED_BIT_FILE)]} {
    set bit_file [file normalize $::env(TINYRISCV_MERGED_BIT_FILE)]
} elseif {$control_mode eq "vio"} {
    set bit_file [file normalize [file join $root_dir "verification" \
        "vivado_vio" "tinyriscv_merged_fpga_vio_top.bit"]]
} else {
    set bit_file [file normalize [file join $root_dir "verification" \
        "vivado_keys" "tinyriscv_merged_fpga_key_top.bit"]]
}

if {![file exists $bit_file]} {
    error "Bitstream does not exist: $bit_file"
}

set hw_context_open 0
set hw_server_connected 0
set hw_target_open 0

proc cleanup_hw_context {} {
    global hw_context_open hw_server_connected hw_target_open

    if {$hw_target_open} {
        catch {close_hw_target}
        set hw_target_open 0
    }
    if {$hw_server_connected} {
        catch {disconnect_hw_server}
        set hw_server_connected 0
    }
    if {$hw_context_open} {
        catch {close_hw}
        set hw_context_open 0
    }
}

# Vivado 2019.1 batch mode autoloads the Lab Tools commands through open_hw.
# open_hw_manager/close_hw_manager are not registered in this batch context.
if {[catch {open_hw} open_error]} {
    error "Could not initialize the Vivado hardware context: $open_error"
}
set hw_context_open 1

if {[catch {connect_hw_server -url localhost:3121} server_error]} {
    cleanup_hw_context
    error "Could not connect to hw_server: $server_error"
}
set hw_server_connected 1

set targets [get_hw_targets -quiet]
if {[llength $targets] == 0} {
    cleanup_hw_context
    error "No JTAG target was found. Check board power, JTAG, and cable drivers."
}

set target [lindex $targets 0]
current_hw_target $target
if {[catch {open_hw_target} target_error]} {
    cleanup_hw_context
    error "Could not open JTAG target $target: $target_error"
}
set hw_target_open 1

set devices [get_hw_devices -quiet]
if {[llength $devices] == 0} {
    cleanup_hw_context
    error "No FPGA device was found. Check board power, JTAG, and cable drivers."
}

set device [lindex $devices 0]
current_hw_device $device
set_property PROGRAM.FILE $bit_file $device

if {$control_mode eq "vio"} {
    set probes_file [file rootname $bit_file]
    append probes_file ".ltx"
    if {![file exists $probes_file]} {
        cleanup_hw_context
        error "VIO probes file does not exist: $probes_file"
    }
    set_property PROBES.FILE $probes_file $device
    set_property FULL_PROBES.FILE $probes_file $device
}

if {[catch {program_hw_devices $device} program_error]} {
    cleanup_hw_context
    error "FPGA programming failed for $device: $program_error"
}
refresh_hw_device $device
puts "MERGED_PROGRAM_SUCCESS mode=$control_mode target=$target device=$device bitstream=$bit_file"
cleanup_hw_context
exit 0
