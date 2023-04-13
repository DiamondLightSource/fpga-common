do common.do

vcom -64 -2008 -work xil_defaultlib \
    $bench_dir/config_fast.vhd \
    $bench_dir/testbench.vhd

vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

view wave

add wave -group "Taps" sim:/testbench/sel/poly_fir/taps_bank/*
add wave -group "Dot Product" sim:/testbench/sel/poly_fir/filter/dot_product/*
add wave -group "Filter" sim:/testbench/sel/poly_fir/filter/*
add wave -group "Accum" sim:/testbench/sel/poly_fir/accum/*
add wave -group "Control" sim:/testbench/sel/poly_fir/control/*
add wave -group "FIR" sim:/testbench/sel/poly_fir/*
add wave -group "Bench" sim:*

add wave -noupdate -format Analog-Step -height 84 -max 16777215 -min 0 \
    -radix decimal /testbench/test_data_in(0)
add wave -noupdate -format Analog-Step -height 84 -max 2147483647 -min 0 \
    -radix decimal /testbench/test_data_out(0)

run 6 us

# vim: set filetype=tcl:
