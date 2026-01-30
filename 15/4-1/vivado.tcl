package require Vivado

proc load_blocks {file block_size {swap_bytes True}} {

    # Copy File Contents

        set fhandle [open $file rb]
        set data [read $fhandle]
        close $fhandle

    # Add Padding Bytes for Alignment

        set file_len [string length $data]
        set delta_len [expr {$block_size - ($file_len % $block_size)}]
        set padding_len [expr {$delta_len % $block_size}]
        append data [string repeat \x00 $padding_len]

    # Loop over Chunks

        set blocks [list]
        for {set i 0} {$i < [string length $data]} {incr i $block_size} {
            set chunk [string range $data $i [expr {$i + $block_size - 1}]]
            binary scan $chunk H* hex

            if {$swap_bytes} {
                set hex [join [lreverse [regexp -all -inline .. $hex]] ""]
            }
            lappend blocks $hex
        }

    return $blocks
}

proc load_contents {file} {

    # Copy File Contents

        set fhandle [open $file rb]
        set data [read $fhandle]
        close $fhandle
        set file_len [string length $data]
        if {$file_len == 0} {
            return -code error "File $file is empty."
        }
        binary scan $data H* hex_contents

    # Reverse the byte order for Vivado

        set byte_list [regexp -all -inline .. $hex_contents]
        set reversed_hex [join [lreverse $byte_list] ""]

    return $reversed_hex
}

proc ::parse_named_arguments {arg_list} {
    set arg_dict {}
    foreach arg_pair $arg_list {
        if {[regexp {([^=]+)=(.+)} $arg_pair -> key value]} {
            dict set arg_dict $key $value
        }
    }
    return $arg_dict
}

proc ::build {arg_dict} {

    # Setup

        create_project -part [dict get $arg_dict PART] -in_memory
        # Constructs yielding the following message have unexpected behavior
        set_msg_config -id "Synth 8-87" -new_severity ERROR
        read_verilog -sv [lsearch -all -inline -not [glob ../*.sv] *_tb.sv]
        read_xdc [glob ../*.xdc]

    # Generate ILA Core

        # save_project_as -force test_[lindex [find_top] 0]
        # set ila_path [create_ip -name ila -vendor xilinx.com -module_name bscan_ila]
        # set_property -dict [list \
        #     CONFIG.C_DATA_DEPTH 131072 \
        #     CONFIG.C_NUM_OF_PROBES 1 \
        #     CONFIG.C_PROBE0_WIDTH 11 \
        #     CONFIG.C_INPUT_PIPE_STAGES 1 \
        #     CONFIG.C_EN_STRG_QUAL False \
        # ] [get_ips bscan_ila]
        # generate_target {instantiation_template} [get_files $ila_path]
        # generate_target -force synthesis [get_files $ila_path]
        # config_ip_cache -export [get_ips -all bscan_ila]
        # export_ip_user_files -of_objects [get_files $ila_path] -no_script -sync -force -quiet
        # create_ip_run [get_files -of_objects [get_fileset sources_1] $ila_path]
        # launch_runs bscan_ila_synth_1
        # wait_on_run bscan_ila_synth_1

    # Synthesize Design

        synth_design -top [lindex [find_top] 0] \
            -directive PerformanceOptimized \
            -flatten_hierarchy none \
            -debug_log -verbose
        opt_design \
            -directive ExploreWithRemap \
            -debug_log -verbose
        place_design \
            -directive ExtraTimingOpt \
            -timing_summary \
            -debug_log -verbose
        phys_opt_design \
            -directive AggressiveExplore \
            -verbose
        route_design \
            -directive AggressiveExplore \
            -tns_cleanup \
            -debug_log -verbose
        phys_opt_design \
            -directive AggressiveExplore \
            -verbose
        write_checkpoint -force project.dcp

    # Generate Reports

        report_clock_networks -endpoints_only -file clock_networks.txt
        report_clock_utilization -file clock_utilization.txt
        report_control_sets -hierarchical -file control_sets.txt
        report_datasheet -show_all_corners -file datasheet.txt
        report_design_analysis -file design_analysis.txt -quiet
        report_disable_timing -user_disabled -file disable_timing.txt
        report_drc -no_waivers -file drc.txt
        report_exceptions -file exceptions.txt
        ::xilinx::designutils::report_failfast -detailed_reports synth -file failfast.txt
        report_high_fanout_nets -timing -load_types -max_nets 99 -file high_fanout_nets.txt
        report_methodology -no_waivers -file methodology.txt
        report_power -file power.txt
        report_qor_assessment -file qor_assessment.txt -full_assessment_details -quiet
        report_qor_suggestions -file qor_suggestions.txt -report_all_suggestions -quiet
        report_ram_utilization -file ram_utilization.txt
        report_timing_summary -slack_lesser_than 20 -max_paths 1 -file timing_summary.txt; # lol
        report_utilization -file utilization.txt
        catch {report_utilization -hierarchical -hierarchical_min_primitive_count 0 -file utilization_hierarchical.txt}

    # Generate Bitstream and Probe Files

        set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
        set_property BITSTREAM.CONFIG.USR_ACCESS TIMESTAMP [current_design]
        set_property BITSTREAM.CONFIG.USERID [dict get $arg_dict GIT_COMMIT] [current_design]
        write_bitstream -force -logic_location_file -file fpga.bit
        write_debug_probes -force [string map {bit ltx} [glob *.bit]] -verbose

}

proc ::lint {arg_dict} {
    create_project -part [dict get $arg_dict PART] -in_memory
    read_verilog -sv [lsearch -all -inline -not [glob ../*.sv] *_tb.sv]
    synth_design -top [lindex [find_top] 0] \
        -lint -file lint.txt -debug_log -verbose
}

proc ::program {} {
    open_hw_manager -quiet
    connect_hw_server -quiet
    open_hw_target -quiet
    set_property PROGRAM.FILE [glob *.bit] [current_hw_device]
    program_hw_devices [current_hw_device]
    refresh_hw_device -quiet
}

proc ::load_inputs {arg_dict} {

    set input_file [dict get $arg_dict INPUT_FILE]

    # Cycle Target Connection to JTAG Mode

        set flags -quiet
        open_hw_manager $flags
        connect_hw_server $flags
        open_hw_target $flags
        close_hw_target $flags
        open_hw_target -jtag_mode on $flags

    # Set FPGA PL TAP IR to USER4

        set zynq7_ir_length 10; # must match FPGA device family / SLR count
        set zynq7_ir_user4 0x3e3; # same thing
        run_state_hw_jtag RESET; # this clears instruction register
        run_state_hw_jtag IDLE
        scan_ir_hw_jtag $zynq7_ir_length -tdi $zynq7_ir_user4

    # Load Contents

        set hex_stream [::load_contents ../$input_file]
        set total_bytes [expr {[string length $hex_stream] / 2}]
        set upstream_bypass_bits 1; # ARM DAP bypass
        set total_dr_length [expr {($total_bytes * 8) + $upstream_bypass_bits}]
        scan_dr_hw_jtag $total_dr_length -tdi $hex_stream
        set bytes_uploaded $total_bytes

    puts "done. ($total_bytes bytes)"
}

proc ::read_result {} {
    set result_width 128
    set result 0x0
    puts -nonewline "Waiting for non-zero result... "
    while {$result == 0} {
        set result 0x[scan_dr_hw_jtag $result_width -tdi 0]
    }
    puts "done."
    puts "Result readback: [format %d $result] ($result)"
    close_hw_target -quiet
}

proc run {argv} {
    set arg_dict [::parse_named_arguments $argv]
    switch [dict get $arg_dict TASK] {
        "all" {
            ::build $arg_dict
            ::program
            ::load_inputs  $arg_dict
            ::read_result
        }
        "build" {
            ::build $arg_dict
        }
        "program" {
            ::program
        }
        "run" {
            ::program
            ::load_inputs  $arg_dict
            ::read_result
        }
        "lint" {
            ::lint  $arg_dict
        }
        default {
            ::build $arg_dict
        }
    }
}

if {[catch {::run $argv}]} {
    # Fix long Vivado exit delay by manually closing the project prior to quitting
    puts "### Exception in [file normalize [info script]] ###"
    puts $::errorInfo
    close_project -quiet
}
