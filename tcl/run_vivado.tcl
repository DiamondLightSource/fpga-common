# Used when launching Vivado to add save_bd() function to environment

set project $env(_PROJECT)
set bd_dir $env(BD_DIR)

# Call this function to save the block design
proc save_bd {} {
    global bd_dir
    validate_bd_design
    write_bd_tcl -keep_paths_as_is -bd_folder . -force \
        "$bd_dir/[current_bd_design].tcl"
    save_bd_design
}

open_project $project
start_gui
