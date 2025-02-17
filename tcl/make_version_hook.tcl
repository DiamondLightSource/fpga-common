# Adds hook for ensuring that make_version.tcl is run when required.
# Add the following lines to FPGA_DEFS when required:
#
#   BUILT += version.vhd
#   BUILT += make_version.tcl
#   TCL_SCRIPTS += $(TCL_DIR)/make_version_hook.tcl

set make_version [add_files built_dir/make_version.tcl -fileset utils_1]
set_property STEPS.SYNTH_DESIGN.TCL.PRE $make_version [get_runs synth_1]
