# Paths from environment
set vhd_dir $env(VHD_DIR)
set common_vhd $env(COMMON_VHD)
set bench_dir $env(BENCH_DIR)

vlib work
vlib msim
vlib msim/xil_defaultlib

vcom -64 -2008 -work xil_defaultlib \
    $common_vhd/support.vhd \
    $common_vhd/misc/spi_master.vhd

vcom -64 -2008 -work xil_defaultlib \
    $bench_dir/sim_spi_slave.vhd \
    $bench_dir/testbench.vhd


vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

view wave

add wave -group "SPI Slave" spi_slave/*
add wave -group "SPI Master" spi_master/*
add wave -group "Bench" sim:*

quietly set NumericStdNoWarnings 1

run 12 us

# vim: set filetype=tcl:
