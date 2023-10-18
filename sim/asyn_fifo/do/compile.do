# Paths from environment
set vhd_dir $env(VHD_DIR)
set bench_dir $env(BENCH_DIR)

vlib work
vlib msim
vlib msim/xil_defaultlib

vcom -64 -2008 -work xil_defaultlib \
    $vhd_dir/support.vhd \
    $vhd_dir/util/sync_bit.vhd \
    $vhd_dir/async_fifo/async_fifo_address.vhd \
    $vhd_dir/async_fifo/async_fifo.vhd

vcom -64 -2008 -work xil_defaultlib \
    $bench_dir/testbench.vhd


vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

view wave

add wave -group "FIFO Address" fifo/address/*
add wave -group "FIFO" fifo/*
add wave sim:*

run 350ns

# vim: set filetype=tcl:
