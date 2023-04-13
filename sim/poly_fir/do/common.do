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
    $vhd_dir/util/dlyreg.vhd \
    $vhd_dir/util/fifo.vhd \
    $vhd_dir/util/simple_fifo.vhd \
    $vhd_dir/arithmetic/dsp48e_mac.vhd \
    $vhd_dir/arithmetic/dot_product.vhd \
    $vhd_dir/poly_fir/poly_fir_taps.vhd \
    $vhd_dir/poly_fir/poly_fir_core.vhd \
    $vhd_dir/poly_fir/poly_fir_accum.vhd \
    $vhd_dir/poly_fir/poly_fir_control.vhd \
    $vhd_dir/poly_fir/poly_fir.vhd \
    $vhd_dir/slow_poly_fir/slow_poly_fir_taps.vhd \
    $vhd_dir/slow_poly_fir/slow_poly_fir_mac.vhd \
    $vhd_dir/slow_poly_fir/slow_poly_fir_accum.vhd \
    $vhd_dir/slow_poly_fir/slow_poly_fir_control.vhd \
    $vhd_dir/slow_poly_fir/slow_poly_fir.vhd \
    $vhd_dir/stream/stream_defs.vhd \
    $vhd_dir/stream/stream_mux.vhd \
    $vhd_dir/stream/stream_demux.vhd

# vim: set filetype=tcl:
