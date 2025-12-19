-- Implements delays for normalisation shift and zero flag as part of reciprocal
-- calculation

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity reciprocal_delays is
    generic (
        PROCESS_DELAY : natural
    );
    port (
        clk_i : in std_ulogic;

        shift_i : in unsigned(4 downto 0);
        zero_i : in std_ulogic := '0';
        shift_o : out unsigned(4 downto 0);
        zero_o : out std_ulogic
    );
end;

architecture arch of reciprocal_delays is
begin
    delay_shift : entity work.fixed_delay generic map (
        WIDTH => shift_i'LENGTH,
        DELAY => PROCESS_DELAY
    ) port map (
        clk_i => clk_i,
        data_i => std_ulogic_vector(shift_i),
        unsigned(data_o) => shift_o
    );

    delay_zero : entity work.fixed_delay generic map (
        DELAY => PROCESS_DELAY
    ) port map (
        clk_i => clk_i,
        data_i(0) => zero_i,
        data_o(0) => zero_o
    );
end;
