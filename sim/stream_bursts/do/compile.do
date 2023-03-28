# Paths from environment
set vhd_dir $env(VHD_DIR)
set bench_dir $env(BENCH_DIR)

vlib work
vlib msim
vlib msim/xil_defaultlib

vcom -64 -2008 -work xil_defaultlib \
    $vhd_dir/support.vhd \
    $vhd_dir/util/simple_fifo.vhd \
    $vhd_dir/util/fifo.vhd \
    $vhd_dir/axi/axi_defs.vhd \
    $vhd_dir/axi/axi_write_validate.vhd \
    $vhd_dir/stream/stream_defs.vhd \
    $vhd_dir/stream/bursts/stream_bursts_fifo.vhd \
    $vhd_dir/stream/bursts/stream_bursts_address.vhd \
    $vhd_dir/stream/bursts/stream_bursts_state.vhd \
    $vhd_dir/stream/bursts/stream_bursts.vhd

vcom -64 -2008 -work xil_defaultlib \
    $bench_dir/axi_write_slave.vhd \
    $bench_dir/testbench.vhd


vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

view wave

add wave -group "FIFO" bursts/fifo/*
add wave -group "Address" bursts/address/*
add wave -group "State" bursts/state/*
add wave -group "Bursts" bursts/*
add wave -group "Validate" axi_slave/validate/*
add wave -group "Slave" axi_slave/*
add wave -group "Bench" sim:*

run 1000 ns

# vim: set filetype=tcl:
