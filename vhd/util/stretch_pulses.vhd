-- Stretches pulses and clocks suitable for display on an LED

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.defines.all;

entity stretch_pulses is
    generic (
        STRETCH_HIGH : natural;
        STRETCH_LOW : natural := STRETCH_HIGH
    );
    port (
        clk_i : in std_ulogic;
        signal_i : in std_ulogic;
        enable_i : in std_ulogic := '1';
        signal_o : out std_ulogic := '0'
    );
end;

architecture arch of stretch_pulses is
    signal counter : natural range 0 to STRETCH_HIGH := 0;

begin
    process (clk_i) begin
        if rising_edge(clk_i) then
            if counter > 0 then
                if enable_i then
                    counter <= counter - 1;
                end if;
            elsif signal_i /= signal_o then
                signal_o <= signal_i;
                case signal_i is
                    when '1' => counter <= STRETCH_HIGH;
                    when '0' => counter <= STRETCH_LOW;
                    when others =>
                end case;
            end if;
        end if;
    end process;
end;
