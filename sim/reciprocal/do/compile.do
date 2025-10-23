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
    $vhd_dir/arithmetic/rounded_product.vhd \
    $vhd_dir/arithmetic/normalise_unsigned.vhd \
    $vhd_dir/arithmetic/reciprocal_lookup.vhd \
    $vhd_dir/arithmetic/reciprocal.vhd

vcom -64 -2008 -work xil_defaultlib \
    $bench_dir/testbench.vhd

vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

view wave

add wave -group "First Mul" reciprocal/first_product/*
add wave -group "Reciprocal" reciprocal/*
add wave -group "Bench" sim:*

run 200 ns;

# vim: set filetype=tcl:
