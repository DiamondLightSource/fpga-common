# Paths from environment
set vhd_dir $env(VHD_DIR)
set common_vhd $env(COMMON_VHD)
set bench_dir $env(BENCH_DIR)

vlib work
vlib msim
vlib msim/xil_defaultlib

vcom -64 -2008 -work xil_defaultlib \
    $common_vhd/support.vhd \
    $common_vhd/util/fifo.vhd \
    $common_vhd/util/simple_fifo.vhd \
    $common_vhd/axi/axi_defs.vhd \
    $common_vhd/axi/axi_write_validate.vhd \
    $common_vhd/axi/axi_write_mux.vhd

vcom -64 -2008 -work xil_defaultlib \
    $bench_dir/burst_generator.vhd \
    $bench_dir/axi_write_slave.vhd \
    $bench_dir/testbench.vhd


vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

view wave

add wave -group "MUX" stream_mux/*
add wave -group "Slave" slave/*
add wave -group "Check AXI" -group "Slave" validate/* validate/check/*
foreach c [range 0 to 2] {
    add wave -group "Check AXI" -group "Burst($c)" \
        bursts($c)/validate/* bursts($c)/validate/check/* }
add wave -group "Bench" sim:*

quietly set NumericStdNoWarnings 1

run 1 us

# vim: set filetype=tcl:
