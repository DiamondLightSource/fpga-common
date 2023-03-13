-- Converts write to a register into an array of strobed bits

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.register_defs.all;

entity register_command is
    port (
        clk_i : in std_ulogic;

        -- Control register interface
        write_strobe_i : in std_ulogic;
        write_data_i : in reg_data_t;
        write_ack_o : out std_ulogic := '0';

        -- Output strobed bits
        strobed_bits_o : out reg_data_t
    );
end;

architecture arch of register_command is
    signal strobed_bits : reg_data_t := (others => '0');

begin
    process (clk_i) begin
        if rising_edge(clk_i) then
            if write_strobe_i = '1' then
                strobed_bits <= write_data_i;
            else
                strobed_bits <= (others => '0');
            end if;
            -- Delay the ack so that it's synchronous with our delayed strobe.
            -- This will avoid problems if the next register write depends on
            -- side effects of the strobe.
            write_ack_o <= write_strobe_i;
        end if;
    end process;

    -- Registers to ease timing for distribution of strobes
    delay_strobe : entity work.dlyreg generic map (
        WIDTH => strobed_bits_o'LENGTH
    ) port map (
        clk_i => clk_i,
        data_i => strobed_bits,
        data_o => strobed_bits_o
    );
end;
