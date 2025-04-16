# Create target project.  This is invoked from Makefile.fpga.run and should be
# invoked on a clean directory just containing the built files.

# All the following variables are read from symbols set by the calling Makefile
#
# Settings needed for creating the new project
set project_name $env(PROJECT_NAME)
set fpga_part $env(FPGA_PART)
set fpga_top $env(FPGA_TOP)
#
# Lists of VHDL files to load
set vhd_files $env(VHD_FILES)
set vhd_file_list $env(VHD_FILE_LIST)
set file_list_defs $env(FILE_LIST_DEFS)
#
set ip_dirs $env(IP_DIRS)
set bd_dir $env(BD_DIR)
set block_designs $env(BLOCK_DESIGNS)
set constr_files $env(CONSTR_FILES)
set constr_tcl $env(CONSTR_TCL)
#
set top_entity $env(TOP_ENTITY)
set tcl_scripts $env(TCL_SCRIPTS)


# Helper function for sourcing script and checking result
proc check_source {script} {
    set status [source $script]
    if { $status ne "" } {
        error "Error $status sourcing $script"
    }
}


# Create the new project
create_project $project_name $project_name -part $fpga_part
set_param project.enableVHDL2008 1
set_property target_language VHDL [current_project]


# Bind all environment variables specified in $file_list_defs to corresponding
# local TCL variables so that they are available for substitution when expanding
# the file list
foreach var $file_list_defs {
    set [string tolower $var] $env($var)
}

# Add VDHL files.  We take two alternative approaches here: if VHD_FILE_LIST has
# been set then files are added from this list, otherwise files are globally
# added from all directories listed in VHD_DIRS
foreach vhd_file $vhd_files {
    add_files $vhd_file
}
foreach file_list $vhd_file_list {
    set infile [open $file_list]
    set lines [split [read $infile] \n]
    close $infile

    # The search skips blank lines and lines starting with #
    set files [lsearch -regexp -inline -all $lines {^[^#]}]

    # All the variables defined in $file_list_defs are available for
    # substitution in this file.  By default this includes $vhd_dir and
    # $common_vhd.
    add_files [subst -nocommands $files]
}
# Set all added files to VHDL 2008
set_property FILE_TYPE "VHDL 2008" [get_files *.vhd]


# Add any IP paths as required, must do this before loading block designs
set_property ip_repo_paths $ip_dirs [current_project]

# Load and prepare any block designs: load the design and add wrappers
foreach bd $block_designs {
    set bd_script $bd_dir/$bd.tcl
    check_source $bd_script
    # Check for any fixup script that might also need to be run
    if [file isfile $bd_script.fixup] { check_source $bd_script.fixup }

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
    check_source $script
}
