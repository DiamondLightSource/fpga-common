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

# Special false path constraint handling for asynchronous DRAM: apply the
# attribute false_path_dram_to="TRUE" to the destination register when reading
# from an asynchronously written distributed memory.
#     The false path setting is documented in UG903 as a special exception for
# asynchronous dual-ports distributed RAM.
set cells [get_cells -hier -filter { false_path_dram_to == "TRUE" }]
if [llength $cells] {
    # Walk our way to any RAMD driving this cell:
    #   cell => cell.D => net => ramd.O => ramd
    # and set the false path from the result if present
    set d_pins [get_pins -of $cells -filter {REF_PIN_NAME == D}]
    set nets [get_nets -of $d_pins -segments]
    set o_pins [get_pins -of $nets -filter {
        DIRECTION == OUT  &&  REF_NAME =~ RAMD*  && REF_PIN_NAME == O}]
    set cells [get_cell -of $o_pins]
    # If anything found set the required false path
    if [llength $cells] { set_false_path -from $cells }
}

# vim: set filetype=tcl:
