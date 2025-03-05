FPGA Support Libraries
----------------------

See also https://github.com/DiamondLightSource/AmcPciDev for kernel driver
support for register and DMA interfacing.

This repository gathers a number of VHDL and Python libraries to help with the
development of FPGA firmware.  The top level directories are structured as
follows:

boards
    Board definitions (pin constraints mostly) for a couple of target boards.

constr
    A generic constraint generation script.  This is needed to support a number
    of constraints configured by custom VHDL attributes:

    =================== =================
    Attribute           Application
    =================== =================
    false_path_to       Used for synchronised bits
    false_path_from     Used for asynchronous resets when required
    max_delay_from      Used for clock domain crossing data
    =================== =================

fpga_lib
    Some generic Python support for interfacing to registers.  Also currently
    includes some board specific files, almost certainly in the wrong place.

tools
    Helper tools used when building FPGA instances.

makefiles
    Makefiles to help with the automated building of FPGA projects and with
    running simulation scripts.

sim
    Simulations for some of the VHDL components.

tcl
    TCL scripts used as part of FPGA project building.

vhd
    Numerous common VHDL libraries:

    support.vhd
        Common support functions and type definitions

    arithmetic
        Miscellaneous arithmetic operations

    axi
        A handful of AXI support definitions and entities

    misc
        Currently just a simple SPI master

    poly_fir
        A poly-phase FIR implementation for high speed downconversion

    slow_poly_fir
        A single DSP poly-phase FIR implementation for slow data

    async_fifo
        Support for asynchronous FIFO

    iodefs
        Xilinx IO definitions

    nco
        An 18-bit cos/sin function generator

    register
        Helper entities for building register interfaces

    stream
        Some slightly half baked ideas here

    util
        Lots of useful and miscellaneous helper entities here


This is still very much a personal work in progress and is subject to drastic
change without any notice.
