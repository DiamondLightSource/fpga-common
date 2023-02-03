# Loads a block design from script, creating a new project as necessary.

set bd_name   [lindex $argv 0]
set bd_script [lindex $argv 1]
set fpga_part [lindex $argv 2]

if [file isfile edit_bd/edit_bd.xpr] {
    open_project edit_bd/edit_bd.xpr
} else {
    create_project -force edit_bd edit_bd -part $fpga_part
}

# Make sure the design isn't part of the project and doesn't already exist on
# disk.
if [llength [get_files */$bd_name.bd]] {
    remove_files $bd_name/$bd_name.bd
}
if [file exists $bd_name] {
    # Take one backup of the block design just for safety.
    if [file exists $bd_name.backup] {
        file delete -force $bd_name.backup
    }
    file rename $bd_name $bd_name.backup
}

source $bd_script

# Perform any required fixups for this script
if [file isfile $bd_script.fixup] {
    source $bd_script.fixup
}

validate_bd_design
regenerate_bd_layout
save_bd_design
