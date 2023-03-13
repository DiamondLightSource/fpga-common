-- Register support block supporting external writes and sequential reads.
--
-- Designed to be used to support returning multiple values from a single
-- register.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.register_defs.all;

entity register_read_sequence is
    port (
        clk_i : in std_ulogic;

        -- Write interface
        write_i : in register_write_t;

        -- Register read interface
        -- Register interface (read only)
        read_strobe_i : in std_ulogic;
        read_data_o : out reg_data_t;
        read_ack_o : out std_ulogic := '0';

        -- Read start, called to reset interface
        read_start_i : in std_ulogic
    );
end;

architecture arch of register_read_sequence is
    constant ADDR_BITS : natural := write_i.address'LENGTH;
    signal data : vector_array(0 to 2**ADDR_BITS-1)(REG_DATA_RANGE);
    signal read_address : unsigned(ADDR_BITS-1 downto 0);

begin
    process (clk_i) begin
        if rising_edge(clk_i) then
            if write_i.strobe then
                data(to_integer(write_i.address)) <= write_i.data;
            end if;

            if read_start_i then
                read_address <= (others => '0');
            elsif read_strobe_i then
                read_address <= read_address + 1;
                read_data_o <= data(to_integer(read_address));
            end if;
            read_ack_o <= read_strobe_i;
        end if;
    end process;
end;
