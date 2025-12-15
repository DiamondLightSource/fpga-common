# Paths from environment
set vhd_dir $env(VHD_DIR)
set bench_dir $env(BENCH_DIR)

vlib work
vlib msim
vlib msim/xil_defaultlib

vcom -64 -2008 -work xil_defaultlib \
    $vhd_dir/support.vhd \
    $vhd_dir/arithmetic/cordic_pl.vhd


vcom -64 -2008 -work xil_defaultlib \
    $bench_dir/testbench.vhd

vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

view wave

add wave -group "Cordic" sim:cordic/*
add wave -group "Bench" sim:*

add wave -noupdate -format Analog-Step -height 84 -max 1.5 -min -1.5 \
    -radix decimal /testbench/mag_error
add wave -noupdate -format Analog-Step -height 84 -max 3.5 -min -3.5 \
    -radix decimal /testbench/angle_error

quietly set NumericStdNoWarnings 1

run 1 us;

# vim: set filetype=tcl:
