# Special functions for working with generated paths

# This has to be included as a .tcl script instead of a .xdc because of the use
# of foreach.

# Set false path to all registers marked with this custom attribute.  This is
# generally only used with util/sync_bit.vhd
foreach cell [get_cells -hierarchical -filter { false_path_to == "TRUE" }] {
    set_false_path -to $cell
}

# Similarly for from attributes, needed for some reset registers.
foreach cell [get_cells -hierarchical -filter { false_path_from == "TRUE" }] {
    set_false_path -from $cell
}

# Max delay constraint.  Each cell with max_delay_from must specify the maximum
# allowed delay in ns
foreach cell [get_cells -hierarchical -filter { max_delay_from != "" }] {
    set_max_delay [get_property max_delay_from $cell] \
        -datapath_only -from $cell
}


# vim: set filetype=tcl:
