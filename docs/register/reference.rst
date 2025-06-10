Register Interface Reference
============================

Originally in https://confluence.diamond.ac.uk/x/eJnSBw

Core Protocol
-------------

The register interface is designed to be easy to implement for end points.  Read
and write paths are treated independently and can be implemented separately.
Indeed, it is possible in principle for register read and write transactions to
occur simultaneously.

Three types of register interface are described here:

* Simple end points.  These correspond to a single register end point, and a
  single strobe and ack pair of signals is used to control the register

* Grouped strobed registers.  Individual register end points are often gathered
  together into a group of registers with a separate strobe/ack pair for each
  register.

* Addressed registers.  Normally only at the highest level of organisation, a
  single end point or group of registers can include an address field.


Interfaces
----------

The file ``register_defs.vhd`` contains the following definitions::

    constant REG_DATA_WIDTH : natural := 32;
    subtype REG_DATA_RANGE is natural range REG_DATA_WIDTH-1 downto 0;
    subtype reg_data_t is std_ulogic_vector(REG_DATA_RANGE);
    type reg_data_array_t is array(natural range <>) of reg_data_t;

Register end points can be classified into two types: simple end points which
take a single register address, and grouped end points which implement a range
of addresses.

Single End Point
~~~~~~~~~~~~~~~~

=============== === =================== ========================================
Signal Name     Dir Datatype            Description
=============== === =================== ========================================
write_strobe_i  in  std_ulogic          Strobe to initiate write.
write_data_i    in  reg_data_t          Data to be written, valid from
                                        write_strobe_i until write_ack_o seen.
write_ack_o     out std_ulogic          Acknowledges completion of write.
=============== === =================== ========================================

=============== === =================== ========================================
Signal Name     Dir Datatype            Description
=============== === =================== ========================================
read_strobe_i   in  std_ulogic          Strobe to initiate read.
read_data_i     in  reg_data_t          Data to be read, valid when
                                        read_ack_o seen (one tick only).
read_ack_o      out std_ulogic          Acknowledges completion of read.
=============== === =================== ========================================

Grouped End Point
~~~~~~~~~~~~~~~~~

=============== === =================== ========================================
Signal Name     Dir Datatype            Description
=============== === =================== ========================================
write_strobe_i  in  std_ulogic_vector   Strobe to initiate write.
write_data_i    in  reg_data_array_t    Data to be written, valid from
                                        write_strobe_i until write_ack_o seen.
write_ack_o     out std_ulogic_vector   Acknowledges completion of write.
=============== === =================== ========================================

=============== === =================== ========================================
Signal Name     Dir Datatype            Description
=============== === =================== ========================================
read_strobe_i   in  std_ulogic_vector   Strobe to initiate read.
read_data_i     in  reg_data_array_t    Data to be read, valid when
                                        read_ack_o seen (one tick only).
read_ack_o      out std_ulogic_vector   Acknowledges completion of read.
=============== === =================== ========================================



Handshaking
~~~~~~~~~~~

All register transactions are initiated with a strobe signal and completed with
an ack signal.  This can be a single clock transaction or multiple clocks, as
illustrated below.

Simple Always Ready Exchange
............................

In this mode of operation the ``ack`` signal must be always high, and register
transactions complete immediately.  In this exchange the data returned from
reading must be independent of the read action.

..  list-table::
    :header-rows: 1

    * - Register Write
      - Register Read

    * -
        ..  wavedrom::

            { signal: [
              {name: 'write_strobe', wave: '010'},
              {name: 'write_ack', wave: '1..'},
              {name: 'write_data', wave: 'x=x'},
            ],
            config: {skin: 'normal'}}

      -
        ..  wavedrom::

            { signal: [
              {name: 'read_strobe', wave: '010'},
              {name: 'read_ack', wave: '1..'},
              {name: 'read_data', wave: 'x=x'},
            ],
            config: {skin: 'normal'}}

Delayed Completion Exchange
...........................

..  list-table::
    :header-rows: 1

    * - Register Write
      - Register Read

    * -
        ..  wavedrom::

            { signal: [
              {name: 'write_strobe', wave: '010..'},
              {name: 'write_ack', wave: '0..10'},
              {name: 'write_data', wave: 'x=..x'},
            ],
            config: {skin: 'normal'}}

      -
        ..  wavedrom::

            { signal: [
              {name: 'read_strobe', wave: '010..'},
              {name: 'read_ack', wave: '0..10'},
              {name: 'read_data', wave: 'x..=x'},
            ],
            config: {skin: 'normal'}}

