-- This module implements a delay line in registers.  This is designed to be
-- used to help with timing, as the use of hard registers is forced.

library ieee;
use ieee.std_logic_1164.all;

entity dlyreg is
    generic (
        DELAY : natural := 1;
        WIDTH  : natural := 1;
        INITIAL : std_ulogic := '0'
    );
    port (
        clk_i : in std_ulogic;
        enable_i : in std_ulogic := '1';
        data_i : in std_ulogic_vector(WIDTH-1 downto 0);
        data_o : out std_ulogic_vector(WIDTH-1 downto 0)
    );
end;

architecture arch of dlyreg is
begin
    dlyreg : entity work.fixed_delay_dram generic map (
        WIDTH => WIDTH,
        DELAY => DELAY,
        INITIAL => INITIAL,
        KEEP_REG => "true"
    ) port map (
        clk_i => clk_i,
        enable_i => enable_i,
        data_i => data_i,
        data_o => data_o
    );
end;
