# clock constraints

    create_clock -name TCK -period 20 [get_pins */TCK]
    create_clock -name CFGCLK -period 15 [get_pins */CFGCLK]

# declare timing exceptions

    set_max_delay -from [get_clocks TCK] -to [get_clocks CFGCLK] -datapath_only [get_property PERIOD [get_clocks CFGCLK]]
    set_max_delay -from [get_clocks CFGCLK] -to [get_clocks TCK] -datapath_only [get_property PERIOD [get_clocks TCK]]
