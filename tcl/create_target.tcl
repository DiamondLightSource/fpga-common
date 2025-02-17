# Create target project.  This is invoked from Makefile.fpga.run and should be
# invoked on a clean directory just containing the built files.

# All the following variables are read from symbols set by the calling Makefile
#
# Settings needed for creating the new project
set project_name $env(PROJECT_NAME)
set fpga_part $env(FPGA_PART)
set fpga_top $env(FPGA_TOP)
#
# The following symbols identify the 
set common_vhd $env(COMMON_VHD)
set vhd_dir $env(VHD_DIR)
set vhd_files $env(VHD_FILES)
set vhd_file_list $env(VHD_FILE_LIST)
set ip_dir $env(IP_DIR)
#
set bd_dir $env(BD_DIR)
set block_designs $env(BLOCK_DESIGNS)
set constr_files $env(CONSTR_FILES)
set constr_tcl $env(CONSTR_TCL)
#
set top_entity $env(TOP_ENTITY)
set tcl_scripts $env(TCL_SCRIPTS)


# Create the new project
create_project $project_name $project_name -part $fpga_part
set_param project.enableVHDL2008 1
set_property target_language VHDL [current_project]


# Add VDHL files.  We take two alternative approaches here: if VHD_FILE_LIST has
# been set then files are added from this list, otherwise files are globally
# added from all directories listed in VHD_DIRS
add_files built_dir
add_files $vhd_files
foreach file_list $vhd_file_list {
    set infile [open $file_list]
    # The search skips blank lines and lines starting with #
    set files [lsearch -regexp -inline -all [split [read $infile]] {^[^#]}]
    close $infile
    # The following symbols are available for substitution in this file:
    #   vhd_dir     VHD directory in main project
    #   common_vhd  VHD directory of fpga-common
    #   ip_dir      Directory of local IP
    add_files [subst $files]
}
# Set all added files to VHDL 2008
set_property FILE_TYPE "VHDL 2008" [get_files *.vhd]


# Add any IP paths as required, must do this before loading block designs
set_property ip_repo_paths $ip_dir [current_project]

# Load and prepare any block designs: load the design and add wrappers
foreach bd $block_designs {
    set bd_script $bd_dir/$bd.tcl
    source $bd_script
    # Check for any fixup script that might also need to be run
    if [file isfile $bd_script.fixup] { source $bd_script.fixup }

    validate_bd_design
    make_wrapper -files [get_files $bd/$bd.bd] -top
    add_files -norecurse $bd/hdl/${bd}_wrapper.vhd
}


# Add constraints files
read_xdc $constr_files
add_files -fileset constrs_1 -norecurse $constr_tcl


# General script settings

# Ensure TOP is set correctly
set_property top $top_entity [current_fileset]

# Enable VHDL assert statements to be evaluated. A severity level of failure
# stops the synthesis flow and produce an error.
set_property STEPS.SYNTH_DESIGN.ARGS.ASSERT true [get_runs synth_1]

# Fail on sensitivity list errors
set_msg_config -id "Synth 8-614" -new_severity ERROR


# Finally apply any project specific TCL modifications to the environment
foreach script $tcl_scripts {
    source $script
}
