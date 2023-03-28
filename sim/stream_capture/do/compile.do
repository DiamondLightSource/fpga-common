# Paths from environment
set vhd_dir $env(VHD_DIR)
set bench_dir $env(BENCH_DIR)

vlib work
vlib msim
vlib msim/xil_defaultlib

vcom -64 -2008 -work xil_defaultlib \
    $vhd_dir/support.vhd \
    $vhd_dir/util/edge_detect.vhd \
    $vhd_dir/util/memory_array.vhd \
    $vhd_dir/util/long_delay.vhd \
    $vhd_dir/util/fixed_delay_dram.vhd \
    $vhd_dir/util/fixed_delay.vhd \
    $vhd_dir/util/dlyreg.vhd \
    $vhd_dir/util/fifo.vhd \
    $vhd_dir/util/simple_fifo.vhd \
    $vhd_dir/axi/axi_defs.vhd \
    $vhd_dir/axi/axi_write_validate.vhd \
    $vhd_dir/axi/axi_write_master_wrapper.vhd \
    $vhd_dir/axi/axi_write_mux.vhd \
    $vhd_dir/stream/stream_defs.vhd \
    $vhd_dir/stream/stream_mux.vhd \
    $vhd_dir/stream/bursts/stream_bursts_fifo.vhd \
    $vhd_dir/stream/bursts/stream_bursts_address.vhd \
    $vhd_dir/stream/bursts/stream_bursts_state.vhd \
    $vhd_dir/stream/bursts/stream_bursts.vhd \
    $vhd_dir/stream/capture/stream_capture_defs.vhd \
    $vhd_dir/stream/capture/stream_capture_control.vhd \
    $vhd_dir/stream/capture/stream_capture_fast_stream.vhd \
    $vhd_dir/stream/capture/stream_capture_bursts.vhd \
    $vhd_dir/stream/capture/stream_capture_fifo.vhd


vcom -64 -2008 -work xil_defaultlib \
    $bench_dir/stream_generator.vhd \
    $bench_dir/axi_write_slave.vhd \
    $bench_dir/testbench.vhd

vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

view wave

add wave -group "AXI Slave" sim:/axi_slave/*
add wave -group "Capture Control" sim:/capture_bursts/control/*
add wave -group "Capture Stream" sim:/capture_bursts/stream/*
add wave -group "Capture Bursts" sim:/capture_bursts/*
add wave -group "Capture FIFO" sim:/capture_fifo/*
add wave -group "Bench" sim:*


run 5 us

# vim: set filetype=tcl:
