# Used when launching Vivado to add save_bd() function to environment

# Call this function to save the block design
proc save_bd {} {
    global argv
    validate_bd_design
    write_bd_tcl -bd_folder . -force "[lindex $argv 0]/[current_bd_design].tcl"
    save_bd_design
}

open_project [lindex $argv 1]
start_gui
