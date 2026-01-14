-- Pipelined reciprocal calculation
--
-- Given a 24 bit unsigned A returns 24 bit unsigned X and 4 bit unsigned S
-- satisfying the equation:
--
--      A * X * 2^S = 2^47 + E      where  |E| <= 1
--
-- In other words, there is at most a one-bit error in the result.  Processing
-- including normalisation of X takes 10 ticks and uses 1 BRAM, 2 DSPs and
-- around 90 LUTs and 80 FFs.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity reciprocal is
    generic (
        PROCESS_DELAY : natural := 10;  -- Used to validate processing delay
        -- Passed through to normalise_unsigned
        NORMALISE_ZERO : boolean := true
    );
    port (
        clk_i : in std_ulogic;

        data_i : in unsigned(23 downto 0);
        shift_o : out unsigned(4 downto 0);
        data_o : out unsigned(23 downto 0);
        zero_o : out std_ulogic
    );
end;

architecture arch of reciprocal is
    signal shift_in : shift_o'SUBTYPE;
    signal data_in : data_i'SUBTYPE;
    signal zero_in : std_ulogic;

    constant CORE_DELAY : natural := PROCESS_DELAY - 1;

begin
    -- Normalise the data in
    normalise : entity work.normalise_unsigned generic map (
        NORMALISE_ZERO => NORMALISE_ZERO
    ) port map (
        clk_i => clk_i,
        data_i => data_i,
        shift_o => shift_in,
        data_o => data_in,
        zero_o => zero_in
    );


    -- Align the normalisation shift and zero flag with core processing delay
    delay_shift : entity work.fixed_delay generic map (
        WIDTH => shift_in'LENGTH,
        DELAY => CORE_DELAY
    ) port map (
        clk_i => clk_i,
        data_i => std_ulogic_vector(shift_in),
        unsigned(data_o) => shift_o
    );

    delay_zero : entity work.fixed_delay generic map (
        DELAY => CORE_DELAY
    ) port map (
        clk_i => clk_i,
        data_i(0) => zero_in,
        data_o(0) => zero_o
    );


    -- Perform reciprocal computation on normalised data
    core : entity work.reciprocal_core generic map (
        PROCESS_DELAY => CORE_DELAY
    ) port map (
        clk_i => clk_i,

        data_i => data_in,
        data_o => data_o
    );
end;
