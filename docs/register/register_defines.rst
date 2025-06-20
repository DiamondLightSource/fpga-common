Register Definitions File
=========================

The register definition file is processed to automatically generate the
following:

* VHDL definitions for register and bit-field range and index values
* Dynamic Python bindings for register access (useful for development and
  initialisation scripts)
* C structures for register access
* Documentation

The definition file defines one or more groups of registers with a hierarachical
structure that is reflected in the VHDL definitions and the Python bindings.
Each top level entry in the file is one of the following:

* A named group.  This is flagged by the first character of the line being an
  ``!`` character followed by the name of the group.  All of the registers
  within this group are defined on lines indented below.
* A shared named group.  This is flagged by a line starting with ``:!``.  A
  shared group name can then appear in multiple places in any other register
  group defined afterwards.
* A shared named register.  This is flagged by a line starting with ``:`` and no
  ``!``.  A shared register name can appear in multiple places in register
  groups.
* A constant, of the form ``name = value``.

A simple example register file is show below.

::

    # Top level register definition
    !TOP
        # A read only version definition with four 8 bit fields
        VERSION     R
            .PATCH          8
            .MINOR          8
            .MAJOR          8
            # This field is set to 255 to indicate that this register space is
            # NOT for use by MBF software.
            .FIRMWARE       8
        # System status register with a pair of single bit fields
        STATUS      R
            # Reference ADC clock input locked
            .ADC_PLL_OK
            # Ethernet link ready
            .ETH_READY

Syntax of definitions
---------------------

The syntax of the file is formally defined as follows (this appears at the top
of the file amc/parse/register_defs.py).

Register Definition Syntax::

    register_defs = { register_def_entry }*
    register_def_entry = group_def | shared_def | constant_def

    constant_def = name "=" value

    shared_def = shared_reg_def | shared_group_def

    group_def = "!"["!"]name { group_entry }*
    group_entry =
        group_def | reg_def | reg_pair | reg_array | shared_name | reg_overlay

    reg_def = name rw { field_def | field_skip }*
    field_def = "."name [ width ] [ "@"offset ] [ rw ]
    field_skip = "-" [ width ]

    reg_pair = "*RW" { reg_def }2
    reg_array = name count rw

    reg_overlay = "*OVERLAY" name rw { reg_def }
    reg_union = "*UNION" { group_entry }

    shared_reg_def = ":"reg_def
    shared_group_def = ":"group_def

    shared_name = ":"saved_name [ new_name ]

    rw = "R" | "W" | "RW" | "WP"

In the above ``name`` and ``new_name`` are any valid VHDL identifier,
``saved_name`` is a previously defined ``shared_reg_def`` or
``shared_group_def`` name, and ``count``, ``offset``, ``width``, ``value`` are
all integers.  Values enclosed in ``{ }`` braces are indented on lines below the
definition preceding.  Each of the marks has special meaning as described below.
Each of the entries above has the following meaning:

register_defs, register_def_entry
    The content of the register definitions file is a sequence of
    register_def_entry definitions.  These must all start in the first column of
    the text file.  A register_def_entry is a group_def which defines a register
    group to be exported from this file, or a shared_def which can be used
    elsewhere in the file, or a constant_def which defines a single constant
    value.

shared_def, shared_reg_def, shared_group_def
    Shared definitions are added to an internal dictionary during parsing of the
    definitions file and can be inserted into a group definition using the :
    prefix.

shared_name
    A shared name inserts a previously defined shared definition into a register
    group definition.

group_def, group_entry
    A group definition defines a group of registers and is a name preceded by !
    and followed by an indented list of further definitions, either subgroups or
    individual registers.  If the prefix is doubled up as !! then the name of
    the group will be elided in part of the group hierarchy.

reg_def, rw
    A single register definition consists of a register name together with a
    read/write access marker and followed by a series of field definitions.  The
    read/write marker is used by the Python bindings to manage access:

    ==== =
    Code Meaning
    ==== =
    R    Read-only register, writes are ignored.
    W    Write-only register, reads will (probably) return zero.  Python
         bindings will cache written values.
    RW   Read/write register, written value is expected to be read back.  Python
         bindings will not cache written values.
    WP   Write-only register, written value is acted on and immediately reset to
         zero.  Python bindings will treat as saved as zero.
    ==== =

field_def, field_skip
    A field definition starts with . and specifies a name, an optional field
    width, an optional starting offset, and an optional read/write code.  (To be
    honest, I suspect the field rw code may be pointless.)  Fields are packed
    together into a single 32-bit register.  If the field width is omitted the
    field is treated as a single bit.

    A field_skip consists of - followed by an optional number and causes the
    specified number of bits to be skipped in the field.

reg_pair
    A register pair consists of separate read and write registers with
    completely different functions overlaid onto the same address.

reg_array
    A register array names a group of registers with no field structure.

reg_overlay reg_union
    Not yet described
