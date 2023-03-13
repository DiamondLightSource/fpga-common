-- Support for an array of register data read through a streamed interface.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.register_defs.all;

entity register_read_block is
    port (
        clk_i : in std_ulogic;

        -- Register interface (read only)
        read_strobe_i : in std_ulogic;
        read_data_o : out reg_data_t;
        read_ack_o : out std_ulogic := '0';
        -- Read start
        read_start_i : in std_ulogic;

        -- The register array
        registers_i : in reg_data_array_t
    );
end;

architecture arch of register_read_block is
    constant COUNT : natural := registers_i'LENGTH;
    signal read_ptr : natural range 0 to COUNT-1;

begin
    assert registers_i'LOW = 0
        report "registers_i must start at 0"
        severity failure;

    process (clk_i) begin
        if rising_edge(clk_i) then
            if read_strobe_i = '1' then
                read_ptr <= read_ptr + 1 when read_ptr < COUNT-1 else 0;
                read_data_o <= registers_i(read_ptr);
            elsif read_start_i = '1' then
                read_ptr <= 0;
            end if;
            -- One tick delay from read request to data out
            read_ack_o <= read_strobe_i;
        end if;
    end process;
end;
