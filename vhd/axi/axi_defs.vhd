-- AXI supporting definitions

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

package axi_defs is
    -- These are the fields required send data to an AXI write master interface.
    -- Separate address_ready and data_ready signals must be returned.
    type axi_write_t is record
        address_valid : std_ulogic;
        -- This is the word address, so should be range ADDRESS_WIDTH-1 downto
        -- LOG_DATA_BYTES (width in bytes).
        address : unsigned;
        burst_length : unsigned(7 downto 0);

        data_valid : std_ulogic;
        data_last : std_ulogic;
        -- Data range is 8*2**LOG_DATA_BYTES-1 downto 0
        data : std_ulogic_vector;
        -- If data_enable is '0' then the byte strobes for this write will be
        -- disabled.  Used to pad a burst when necessary.
        data_enable : std_ulogic;
    end record;

    type axi_write_array_t is array(natural range <>) of axi_write_t;

    -- This wraps the ready handshake signals associated with axi_write_t
    type axi_write_ready_t is record
        address_ready : std_ulogic;
        data_ready : std_ulogic;
        write_complete : std_ulogic;
    end record;

    type axi_write_ready_array_t is
        array(natural range <>) of axi_write_ready_t;
end;
