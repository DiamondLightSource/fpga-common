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
    $vhd_dir/nco/nco_defs.vhd \
    $vhd_dir/nco/nco_cos_sin_table.vhd \
    $vhd_dir/nco/nco_phase.vhd \
    $vhd_dir/nco/nco_cos_sin_prepare.vhd \
    $vhd_dir/nco/nco_cos_sin_refine.vhd \
    $vhd_dir/nco/nco_cos_sin_octant.vhd \
    $vhd_dir/nco/nco_cos_sin.vhd \
    $vhd_dir/nco/nco_core.vhd

vcom -64 -2008 -work xil_defaultlib \
    $bench_dir/sim_nco.vhd \
    $bench_dir/testbench.vhd


vsim -t 1ps -voptargs=+acc -lib xil_defaultlib testbench

view wave

add wave -group "Phase" sim:/nco/nco_phase/*
add wave -group "Prepare" sim:/nco/cos_sin/prepare/*
add wave -group "Refine" sim:/nco/cos_sin/refine/*
add wave -group "Fixup" sim:/nco/cos_sin/fixup_octant/*
add wave -group "NCO" sim:/nco/*
add wave -group "Sim NCO" sim:/sim_nco/*
add wave sim:*

add wave -noupdate \
    -childformat { \
        {/difference.cos -radix decimal} \
        {/difference.sin -radix decimal}} \
    -expand -subitemconfig { \
        /testbench/difference.cos \
            {-format Analog-Step \
                -height 84 -max 2.0 -min -2.0 -radix decimal} \
        /testbench/difference.sin \
            {-format Analog-Step \
                -height 84 -max 2.0 -min -2.0 -radix decimal}} \
    /difference

add wave -analog-step -min -2.0 -max 2.0 -height 80 /magnitude_error

quietly set NumericStdNoWarnings 1

run 2us

# vim: set filetype=tcl:
