-- Simple pulse stretching
--
-- Lengthens pulse_i by DELAY extra ticks

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity stretch_pulse is
    generic (
        DELAY : natural := 31;
        REGISTER_OUT : boolean := true
    );
    port (
        clk_i : in std_ulogic;
        pulse_i : in std_ulogic;
        pulse_o : out std_ulogic
    );
end;

architecture arch of stretch_pulse is
    signal counter : natural range 0 to DELAY := 0;
    signal pulse_out : std_ulogic;
    signal pulse_reg : std_ulogic := '0';

begin
    -- Need to be a bit careful about handling zero delay!
    pulse_out <= pulse_i or to_std_ulogic(counter > 0);

    process (clk_i) begin
        if rising_edge(clk_i) then
            if pulse_i then
                counter <= DELAY;
            elsif counter > 0 then
                counter <= counter - 1;
            end if;
            pulse_reg <= pulse_out;
        end if;
    end process;

    gen_out : if REGISTER_OUT generate
        pulse_o <= pulse_reg;
    else generate
        pulse_o <= pulse_out;
    end generate;
end;
