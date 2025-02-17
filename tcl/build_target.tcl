# Run build to completion

set project $env(_PROJECT)
set jobs_count $env(JOBS_COUNT)


open_project $project

# Run the implementation
launch_runs impl_1 -to_step write_bitstream -jobs $jobs_count
wait_on_run impl_1

# Finally once the build has completed check that timing constraints were met.
# See https://xillybus.com/tutorials/vivado-timing-constraints-error for a
# description of this trick, also used in PandA.
#
# Unfortunately we need to open the implemented design first.
open_run impl_1
set minireport \
    [report_timing_summary -no_header -no_detailed_paths -return_string]
if {! [string match -nocase {*timing constraints are met*} $minireport]} {
    send_msg_id "CRITICAL WARNING" "Timing constraints weren't met."
    return -code error
}
