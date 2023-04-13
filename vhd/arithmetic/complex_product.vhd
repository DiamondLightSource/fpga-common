-- Direct complex product
--
-- Uses four multipliers for computation of
--      (a + bi) * (c + di) = (a * c - b * d) + (a * d + b * c)i

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity complex_product is
    generic (
        -- Bits to silently discard from the top
        DISCARD_TOP : natural := 0;
        PROCESS_DELAY : natural := 0;
        -- If set the output is saturated on overflow and the process delay is
        -- one tick longer
        SATURATE_OUTPUT : boolean := false
    );
    port (
        clk_i : in std_ulogic;

        -- Complex numbers in
        a_real_i : in signed;       -- Real part
        a_imag_i : in signed;       -- Imaginary part

        b_real_i : in signed;       -- Real part
        b_imag_i : in signed;       -- Imaginary part

        -- Complex product out, PROCESS_DELAY ticks from input
        overflow_o : out std_ulogic;
        ab_real_o : out signed;
        ab_imag_o : out signed
    );
end;

architecture arch of complex_product is
    signal real_overflow : std_ulogic;
    signal imag_overflow : std_ulogic;

begin
    real_part : entity work.half_complex_product generic map (
        DISCARD_TOP => DISCARD_TOP,
        PROCESS_DELAY => PROCESS_DELAY,
        DO_SUBTRACT => true,
        SATURATE_OUTPUT => SATURATE_OUTPUT
    ) port map (
        clk_i => clk_i,
        a_i => a_real_i,
        b_i => b_real_i,
        c_i => a_imag_i,
        d_i => b_imag_i,
        overflow_o => real_overflow,
        result_o => ab_real_o
    );

    imag_part : entity work.half_complex_product generic map (
        DISCARD_TOP => DISCARD_TOP,
        PROCESS_DELAY => PROCESS_DELAY,
        DO_SUBTRACT => false,
        SATURATE_OUTPUT => SATURATE_OUTPUT
    ) port map (
        clk_i => clk_i,
        a_i => a_real_i,
        b_i => b_imag_i,
        c_i => a_imag_i,
        d_i => b_real_i,
        overflow_o => imag_overflow,
        result_o => ab_imag_o
    );

    overflow_o <= real_overflow or imag_overflow;
end;
