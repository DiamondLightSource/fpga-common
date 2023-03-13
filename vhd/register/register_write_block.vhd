-- Support for an array of register data written through a streamed interface.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.register_defs.all;

entity register_write_block is
    port (
        clk_i : in std_ulogic;

        -- Register interface (write only)
        write_strobe_i : in std_ulogic;
        write_data_i : in reg_data_t;
        write_ack_o : out std_ulogic;
        -- Write start
        write_start_i : in std_ulogic;

        -- The register array
        registers_o : out reg_data_array_t
    );
end;

architecture arch of register_write_block is
    constant COUNT : natural := registers_o'LENGTH;

    signal register_file : registers_o'SUBTYPE := (others => (others => '0'));
    signal write_ptr : natural range 0 to COUNT-1;

begin
    assert registers_o'LEFT = 0
        report "registers_o must start at 0"
        severity failure;

    process (clk_i) begin
        if rising_edge(clk_i) then
            if write_strobe_i = '1' then
                write_ptr <= write_ptr + 1 when write_ptr < COUNT-1 else 0;
                register_file(write_ptr) <= write_data_i;
            elsif write_start_i = '1' then
                write_ptr <= 0;
            end if;
        end if;
    end process;

    write_ack_o <= '1';
    registers_o <= register_file;
end;
