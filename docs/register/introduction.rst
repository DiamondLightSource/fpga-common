Introduction
============

Register support is implemented via a number of VHDL entities defined in the
``vhd/register`` directory together with tools to support autogeneration of VHDL
header files and others from a register definitions file.

The following entities are currently defined:

==== ========================== =
Role Entity                     Description
==== ========================== =
ECA  register_bank_cc           Transfer of register with address across clock
                                boundary
S    register_buffer            Buffer for register interface
EC   register_cc                Transfer register bank across clock boundary
E    register_command           Converts register write into strobed bits
\    register_defs              Register definitions
E    register_events            Captures transient events into readable array of
                                bits
EC   register_file_cc           Write only register block across clock boundary
E    register_file_rw           Simple array of registers with readback
E    register_file              Simple array of registers
H    register_mux_strobe        (Helper for register_mux)
S    register_mux               Decodes register address into individual strobes
E    register_read_block        Provides sequential access to an array of
                                register data
E    register_read_sequence     Similar function
E    register_status            Captures status bits and transient events
E    register_write_block       Similar to register_read_block
==== ========================== =

* **E** -- End point
* **A** -- Includes address decode
* **C** -- Cross clocks
* **S** -- Infrastructure

This is designed to be used as follows, where ``register_mux`` is used to
generate an array of strobes.

..  image:: build/figures/axi-mux-overview.png
