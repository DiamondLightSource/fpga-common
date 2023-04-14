# Paths from environment
set vhd_dir $env(VHD_DIR)
set bench_dir $env(BENCH_DIR)
set common_sim $env(COMMON_SIM)

vlib work
vlib msim
vlib msim/xil_defaultlib

vcom -64 -2008 -work xil_defaultlib \
    $vhd_dir/support.vhd \
    $vhd_dir/util/fixed_delay_dram.vhd \
    $vhd_dir/util/dlyreg.vhd \
    $vhd_dir/util/sync_bit.vhd \
    $vhd_dir/util/edge_detect.vhd \
    $vhd_dir/util/cross_clocks.vhd \
    $vhd_dir/register/register_defs.vhd \
    $vhd_dir/register/register_mux_strobe.vhd \
    $vhd_dir/register/register_buffer.vhd \
    $vhd_dir/register/register_mux.vhd \
    $vhd_dir/register/register_events.vhd \
    $vhd_dir/register/register_command.vhd \
    $vhd_dir/register/register_file.vhd \
    $vhd_dir/register/register_file_rw.vhd \
    $vhd_dir/register/register_write_block.vhd \
    $vhd_dir/register/register_read_block.vhd \
    $vhd_dir/register/register_file_cc.vhd \
    $vhd_dir/register/register_read_sequence.vhd


vcom -64 -2008 -work xil_defaultlib \
    built/register_defines.vhd \
    $bench_dir/test_counter.vhd \
    $bench_dir/test_registers.vhd \
    $common_sim/sim_support.vhd \
    $bench_dir/testbench.vhd


vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

view wave

# add wave -group "Gather" gather/*
add wave -group "Mux" register_mux/*
add wave -group "Regs" test_registers/*
add wave -group "Events" test_registers/events/*
add wave -group "Counter" test_registers/counter/*
add wave -group "Bench" sim:*

quietly set NumericStdNoWarnings 1

run 1.1 us

# vim: set filetype=tcl:
