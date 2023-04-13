-- Multiply and accumulate

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity slow_poly_fir_mac is
    generic (
        TOP_RESULT_BIT : natural;
        PROCESS_DELAY : natural;
        ACCUM_DELAY : natural
    );
    port (
        clk_i : in std_ulogic;

        -- One tick ahead of accumulator
        data_i : in signed;
        tap_i : in signed;

        accum_i : in signed;
        overflow_i : in std_ulogic;

        accum_o : out signed;
        overflow_o : out std_ulogic
    );
end;

architecture arch of slow_poly_fir_mac is
    constant DATA_WIDTH : natural := data_i'LENGTH;
    constant TAP_WIDTH : natural := tap_i'LENGTH;

    signal overflow_in : std_ulogic;
    signal overflow : std_ulogic;

begin
    mac : entity work.dsp48e_mac generic map (
        TOP_RESULT_BIT => TOP_RESULT_BIT,
        PROCESS_DELAY => PROCESS_DELAY,
        ACCUM_DELAY => ACCUM_DELAY
    ) port map (
        clk_i => clk_i,

        a_i => data_i,
        b_i => tap_i,

        c_i => accum_i,

        p_o => accum_o,
        pc_o => open,
        ovf_o => overflow
    );

    -- Delay overflow in to match computed output overflow
    delay : entity work.fixed_delay generic map (
        DELAY => ACCUM_DELAY
    ) port map (
        clk_i => clk_i,
        data_i(0) => overflow_i,
        data_o(0) => overflow_in
    );

    overflow_o <= overflow or overflow_in;
end;
