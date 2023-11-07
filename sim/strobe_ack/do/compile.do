# Paths from environment
set vhd_dir $env(VHD_DIR)
set bench_dir $env(BENCH_DIR)

vlib work
vlib msim
vlib msim/xil_defaultlib

vcom -64 -2008 -work xil_defaultlib \
    $vhd_dir/support.vhd \
    $vhd_dir/util/memory_array.vhd \
    $vhd_dir/util/long_delay.vhd \
    $vhd_dir/util/fixed_delay_dram.vhd \
    $vhd_dir/util/fixed_delay.vhd \
    $vhd_dir/util/stretch_pulse.vhd \
    $vhd_dir/util/strobe_ack.vhd \

vcom -64 -2008 -work xil_defaultlib \
    $bench_dir/testbench.vhd


vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

view wave

add wave -group "Strobe/Ack" strobe_ack/*
add wave -group "Stretch 2" stretch_2/*
add wave -group "Stretch 10" stretch_10/*
add wave -group "Bench" sim:*

run 350ns

# vim: set filetype=tcl:
