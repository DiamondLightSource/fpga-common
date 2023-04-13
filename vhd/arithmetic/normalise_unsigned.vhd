-- Normalise unsigned integer

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.support.all;

entity normalise_unsigned is
    generic (
        -- Determines the shift calculation for zero.  If this flag is set then
        -- on zero input shift_o is set to data_i'LENGTH, otherwise it is set to
        -- zero (as normalising zero is generally futile).
        NORMALISE_ZERO : boolean := true
    );
    port (
        clk_i : in std_ulogic;

        data_i : in unsigned;
        shift_o : out unsigned;
        data_o : out unsigned;
        zero_o : out std_ulogic
    );
end;

architecture arch of normalise_unsigned is
    function count_zeros(data : unsigned) return natural is
    begin
        for i in 0 to data'LEFT loop
            if data(data'LEFT - i) = '1' then
                return i;
            end if;
        end loop;
        return data'LENGTH;
    end;

    signal top_bits : natural;
    signal shift_out : shift_o'SUBTYPE := (others => '0');
    signal data_out : data_i'SUBTYPE := (others => '0');
    signal zero_out : std_ulogic := '0';

    subtype DATA_OUT_RANGE is natural
        range data_i'LEFT downto data_i'LEFT - data_o'LENGTH + 1;

begin
    top_bits <= count_zeros(data_i) when data_i /= 0 or NORMALISE_ZERO else 0;

    process (clk_i) begin
        if rising_edge(clk_i) then
            shift_out <= to_unsigned(top_bits, shift_o'LENGTH);
            data_out <= shift_left(data_i, top_bits);
            zero_out <= to_std_ulogic(data_i = 0);
        end if;
    end process;

    shift_o <= shift_out;
    data_o <= data_out(DATA_OUT_RANGE);
    zero_o <= zero_out;
end;
