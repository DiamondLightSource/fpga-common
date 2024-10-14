# Paths from environment
set vhd_dir $env(VHD_DIR)
set bench_dir $env(BENCH_DIR)

vlib work
vlib msim
vlib msim/xil_defaultlib

vcom -64 -2008 -work xil_defaultlib \
    $vhd_dir/support.vhd \
    $vhd_dir/util/memory_array_dual.vhd \
    $vhd_dir/util/stretch_pulse.vhd \
    $vhd_dir/util/sync_bit.vhd \
    $vhd_dir/util/in_fifo.vhd

vcom -64 -2008 -work xil_defaultlib \
    $bench_dir/testbench.vhd

vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

view wave

add wave -group "FIFO" /fifo/*
add wave -group "Bench" sim:*

run 4 us

# vim: set filetype=tcl:
