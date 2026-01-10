package require Vivado

namespace eval ::textio {
    proc load {file} {
        set lines [list]
        set fhandle [open $file]
        while {[gets $fhandle line]>=0} {
            lappend lines $line
        }
        close $fhandle
        return $lines
    }
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
    create_project -part [dict get $arg_dict PART] -in_memory
    read_verilog -sv [lsearch -all -inline -not [glob ../*.sv] *_tb.sv]
    read_xdc [glob ../*.xdc]

    set directive RuntimeOptimized; # speed-run the build process
    synth_design -top [lindex [find_top] 0] \
        -directive $directive \
        -flatten_hierarchy none \
        -debug_log -verbose
    opt_design \
        -directive $directive \
        -debug_log -verbose
    place_design \
        -directive $directive \
        -timing_summary \
        -debug_log -verbose
    phys_opt_design \
        -verbose
    route_design \
        -directive $directive \
        -tns_cleanup \
        -debug_log -verbose
    phys_opt_design \
        -verbose
    write_checkpoint -force project.dcp

    # least crowded firmware
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

    set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
    set_property BITSTREAM.CONFIG.USR_ACCESS TIMESTAMP [current_design]
    set_property BITSTREAM.CONFIG.USERID [dict get $arg_dict GIT_COMMIT] [current_design]
    write_bitstream -force -logic_location_file -file fpga.bit
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
    # cycle target connection
    open_hw_manager -quiet
    connect_hw_server -quiet
    open_hw_target -quiet
    close_hw_target -quiet
    open_hw_target -jtag_mode on -quiet

    # set FPGA PL TAP IR to USER4
    set zynq7_ir_length 10; # must match FPGA device family / SLR count
    set zynq7_ir_user4 0x3e3; # same thing
    run_state_hw_jtag RESET; # this clears instruction register
    run_state_hw_jtag IDLE
    scan_ir_hw_jtag $zynq7_ir_length -tdi $zynq7_ir_user4

    # upload file contents
    set zynq7_dr_length_byte 9; # zynq7: extra bit for ARM DAP bypass reg
    set new_line 0x00a; # `\n`
    set input_file [dict get $arg_dict INPUT_FILE]
    set lines [::textio::load ../$input_file]
    puts -nonewline "Uploading bytes... "
    set bytes_uploaded 0
    foreach line $lines {
        set len [string length $line]
        for {set i 0} {$i<$len} {incr i} {
            scan [string index $line $i] %c char
            set hex_char [format "%02x" $char]
            scan_dr_hw_jtag $zynq7_dr_length_byte -tdi $hex_char
            run_state_hw_jtag IDLE; # run through state `UPDATE`
            incr bytes_uploaded
        }
        scan_dr_hw_jtag $zynq7_dr_length_byte -tdi $new_line
        run_state_hw_jtag IDLE; # run through state `UPDATE`
        incr bytes_uploaded
        run_state_hw_jtag DRPAUSE
        run_state_hw_jtag IDLE
    }
    puts "done. ($bytes_uploaded bytes)"

    # cycle tck for purging data stuck between register stages
    for {set i 0} {$i<50} {incr i} {
        run_state_hw_jtag -state IDLE IDLE;
    }

}

proc ::read_password {} {
    run_state_hw_jtag IDLE
    set password 0x[scan_dr_hw_jtag 16 -tdi 0]
    puts "Password readback: [format %d $password] ($password)"
}

proc run {argv} {
    set arg_dict [::parse_named_arguments $argv]
    switch [dict get $arg_dict TASK] {
        "all" {
            ::build $arg_dict
            ::program
            ::load_inputs  $arg_dict
            ::read_password
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
            ::read_password
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
