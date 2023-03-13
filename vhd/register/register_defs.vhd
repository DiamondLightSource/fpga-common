-- Register specific definitions

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

package register_defs is
    -- Register data is in blocks of 32-bits
    constant REG_DATA_WIDTH : natural := 32;
    subtype REG_DATA_RANGE is natural range REG_DATA_WIDTH-1 downto 0;
    subtype reg_data_t is std_ulogic_vector(REG_DATA_RANGE);
    type reg_data_array_t is array(natural range <>) of reg_data_t;

    -- Miscellaneous helper type for register support
    type register_write_t is record
        strobe : std_ulogic;
        address : unsigned;
        data : reg_data_t;
    end record;
end;
