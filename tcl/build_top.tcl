set src_dir [lindex $argv 0]
set project [lindex $argv 1]
set fpga_part [lindex $argv 2]
set bd_list [lindex $argv 3]
set hierarchy rebuilt
# set hierarchy none

# We put the timing check here so that at the point of call we don't have the
# error message visible to us.
proc check_timing {timingreport} {
    if {! [string match -nocase {*timing constraints are met*} $timingreport]} {
        send_msg_id showstopper-0 error "Timing constraints weren't met."
        return -code error
    }
}

create_project $project $project -part $fpga_part

set_param project.enableVHDL2008 1
set_property target_language VHDL [current_project]
# set_msg_config -severity "CRITICAL WARNING" -new_severity ERROR

# Ensure undriven pins are treated as errors
#set_msg_config -id "Synth 8-3295" -new_severity ERROR
#set_msg_config -id "Synth 8-3848" -new_severity ERROR
# Similarly catch sensitivity list errors
set_msg_config -id "Synth 8-614" -new_severity ERROR


# Am not sure this is a good idea, in particular it causes timing errors to not
# generate a checkpoint, which is exceptionally unhelpful.
#
# # Elevate critical warnings
# set_msg_config -severity "CRITICAL WARNING" -new_severity ERROR

# Suppress phoney ethenet AVB CW from the Tri-Mode Ethernet IP
set_msg_config -id {Vivado 12-1790} -suppress



# Add our files and set them to VHDL 2008.  This needs to be done before reading
# any externally generated files, particularly the interconnect.
add_files built
add_files $src_dir/vhd
set_property FILE_TYPE "VHDL 2008" [get_files *.vhd]


# Ensure we've read the block designs and generated the associated files.
foreach bd $bd_list {
    read_bd $bd/$bd.bd
    make_wrapper -files [get_files $bd/$bd.bd] -top
    add_files -norecurse $bd/hdl/${bd}_wrapper.vhd
}

set_property top top [current_fileset]

# Load the constraints
read_xdc built/top_pins.xdc
# set files [glob -nocomplain $src_dir/constr/*.xdc]
# if [llength $files] { read_xdc $files }
read_xdc [glob -nocomplain $src_dir/constr/*.xdc]

foreach name {post_synth pblocks} {
    set xdc [get_files -quiet $name.xdc]
    if [llength $xdc] {
        set_property used_in_synthesis false $xdc
    }
}


# Configure Vivado build options

# For the moment let's go with default build options
# set_property strategy Flow_PerfOptimized_high [get_runs synth_1]

# Hmm.  Not sure what this one does.
set_property STEPS.SYNTH_DESIGN.ARGS.ASSERT true [get_runs synth_1]

# Allowing the hierarchy to be flattened and rebuilt should allow for more
# optimisation options, but it doesn't seem to help a lot and it does make
# understanding the resulting system a *lot* harder!  For now, leave the
# hierarchy untouched.
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY none [get_runs synth_1]


# # Add script for rebuilding version file to synthesis step
# set_property STEPS.SYNTH_DESIGN.TCL.PRE \
#     $src_dir/tcl/make_version.tcl [get_runs synth_1]


# This setting is recommended by Xilinx to help achieve timing closure for the
# AXI bridge, see https://support.xilinx.com/s/article/55711
# set_property STEPS.OPT_DESIGN.ARGS.DIRECTIVE ExploreSequentialArea \
#     [get_runs impl_1]

# Achieving timing closure is painful.  The advice from Xilinx for the PCIe-AXI
# bridge seems to keep changing, but this setting appears to work for now,
# recommended here: https://support.xilinx.com/s/article/72057
set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs impl_1]

launch_runs impl_1 -to_step write_bitstream -jobs 6
wait_on_run impl_1
