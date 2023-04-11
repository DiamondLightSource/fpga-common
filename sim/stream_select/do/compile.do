# Paths from environment
set vhd_dir $env(VHD_DIR)
set common_vhd $env(COMMON_VHD)
set bench_dir $env(BENCH_DIR)

vlib work
vlib msim
vlib msim/xil_defaultlib

vcom -64 -2008 -work xil_defaultlib \
    $common_vhd/support.vhd \
    $common_vhd/stream/stream_defs.vhd \
    $common_vhd/stream/stream_select.vhd

vcom -64 -2008 -work xil_defaultlib \
    $bench_dir/test_defs.vhd \
    $bench_dir/stream_generator.vhd \
    $bench_dir/validate.vhd \
    $bench_dir/testbench.vhd


vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

view wave

add wave -group "Select" sel/*
add wave -group "Validate" validate/*
add wave -group "Bench" sim:*

quietly set NumericStdNoWarnings 1

run 1 us

# vim: set filetype=tcl:
