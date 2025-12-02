proc parse_named_arguments {arg_list} {
    set arg_dict {}
    foreach arg_pair $arg_list {
        if {[regexp {([^=]+)=(.+)} $arg_pair -> key value]} {
            dict set arg_dict $key $value
        }
    }
    return $arg_dict
}

proc ::build {} {
    create_project -part xc7z020clg484-1 -in_memory
    read_verilog -sv [glob *.sv]
    read_xdc [glob *.xdc]
    synth_design -top [lindex [find_top] 0] \
        -directive RuntimeOptimized \
        -debug_log -verbose
}

proc ::lint {} {
    create_project -part xc7z020clg484-1 -in_memory
    read_verilog -sv [glob *.sv]

    synth_design -top [lindex [find_top] 0] -lint -file lint.txt -verbose
}

proc run {argv} {
    set arg_dict [::parse_named_arguments $argv]
    switch [dict get $arg_dict TASK] {
        "all" {
            ::build
            ::program
            ::load_inputs
            ::read_password
        }
        "lint" {
            ::lint
        }
        "build" {
            ::build
        }
        "run" {
            ::load_inputs
            ::read_password
        }
        default {
            ::build
        }
    }
}

if {[catch {::run $argv}]} {
    # Fix Vivado exit delay by manually closing the project prior to quitting
    puts "TCL: caught exception in [file normalize [info script]]"
    puts $::errorInfo
    close_project
}
