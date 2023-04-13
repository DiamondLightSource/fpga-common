do common.do

vcom -64 -2008 -work xil_defaultlib \
    $bench_dir/config_slow.vhd \
    $bench_dir/testbench.vhd

vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

view wave

add wave -group "Mux" sim:stream_mux/*
add wave -group "Data FIFO" sim:sel/poly_fir/gen_fifo/data_fifo/*
add wave -group "Taps" sim:sel/poly_fir/taps/*
add wave -group "Accum" sim:sel/poly_fir/accum/*
add wave -group "Control" sim:sel/poly_fir/control/*
add wave -group "FIR" sim:sel/poly_fir/*
add wave -group "Bench" sim:*

add wave -noupdate -format Analog-Step -height 84 -max 16777215 -min 0 \
    -radix decimal /testbench/test_data_in(0)
add wave -noupdate -format Analog-Step -height 84 -max 2147483647 -min 0 \
    -radix decimal /testbench/test_data_out(0)

quietly set NumericStdNoWarnings 1
quietly set StdArithNoWarnings 1

run 16 us

# vim: set filetype=tcl:
