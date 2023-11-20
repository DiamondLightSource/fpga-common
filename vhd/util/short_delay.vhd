-- Programmable short delay design to fit in Distributed RAM.  The programmable
-- delay is 5 bits wide for up to 32 tick delay.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity short_delay is
    generic (
        WIDTH : natural := 1;
        INITIAL : std_ulogic := '0';
        REGISTER_OUTPUT : boolean := true;
        EXTRA_DELAY : integer := -1      -- Validation only
    );
    port (
        clk_i : in std_ulogic;

        delay_i : in unsigned;
        enable_i : in std_ulogic := '1';
        data_i : in std_ulogic_vector(WIDTH-1 downto 0);
        data_o : out std_ulogic_vector(WIDTH-1 downto 0)
    );
end;

architecture arch of short_delay is
    constant MAX_DELAY : natural := 2**delay_i'LENGTH - 1;
    signal delay_line : vector_array(0 to MAX_DELAY)(WIDTH-1 downto 0)
        := (others => (others => INITIAL));
    signal data_out : std_ulogic_vector(WIDTH-1 downto 0)
        := (others => INITIAL);

begin
    assert
        EXTRA_DELAY = -1  or
        (EXTRA_DELAY = 1 and not REGISTER_OUTPUT)  or
        (EXTRA_DELAY = 2 and REGISTER_OUTPUT)
        report "Invalid EXTRA_DELAY " & to_string(EXTRA_DELAY)
        severity failure;

    process (clk_i) begin
        if rising_edge(clk_i) then
            if enable_i then
                delay_line(0) <= data_i;
                delay_line(1 to MAX_DELAY) <= delay_line(0 to MAX_DELAY-1);
                data_out <= delay_line(to_integer(delay_i));
            end if;
        end if;
    end process;

    gen_out : if REGISTER_OUTPUT generate
        data_o <= data_out;
    else generate
        data_o <= delay_line(to_integer(delay_i));
    end generate;
end;
