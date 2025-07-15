# Paths from environment
set vhd_dir $env(VHD_DIR)
set bench_dir $env(BENCH_DIR)
set common_sim $env(COMMON_SIM)

vlib work
vlib msim
vlib msim/xil_defaultlib

vcom -64 -2008 -work xil_defaultlib \
    $vhd_dir/support.vhd \
    $vhd_dir/util/sync_bit.vhd \
    $vhd_dir/register/register_defs.vhd \
    $vhd_dir/misc/uart_rx.vhd \
    $vhd_dir/misc/uart_tx.vhd \
    $vhd_dir/misc/uart.vhd

vcom -64 -2008 -work xil_defaultlib \
    $common_sim/sim_support.vhd \
    $bench_dir/testbench.vhd


vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

view wave

add wave -group "UART TX" uart/tx/*
add wave -group "UART RX" uart/rx/*
add wave -group "UART" uart/*
add wave -group "Bench" sim:*

run 2.5 us

# vim: set filetype=tcl:
