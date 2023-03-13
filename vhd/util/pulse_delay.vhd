-- Simple counter driven pulse delay

-- Only one pulse at a time can be processed.  If a new trigger input is seen
-- before the current pulse has been emitted the trigger is lost and a missed
-- event is reported.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity pulse_delay is
    port (
        clk_i : in std_ulogic;

        delay_i : in unsigned;
        pulse_i : in std_ulogic;

        missed_o : out std_ulogic := '0';
        pulse_o : out std_ulogic := '0'
    );
end;

architecture arch of pulse_delay is
    signal wait_counter : delay_i'SUBTYPE := (others => '0');

begin
    process (clk_i) begin
        if rising_edge(clk_i) then
            if wait_counter > 0 then
                wait_counter <= wait_counter - 1;
            elsif pulse_i then
                wait_counter <= delay_i;
            end if;

            if wait_counter = 1 then
                pulse_o <= '1';
            elsif delay_i = 0 then
                pulse_o <= pulse_i;
            else
                pulse_o <= '0';
            end if;

            missed_o <= pulse_i and to_std_ulogic(wait_counter > 0);
        end if;
    end process;
end;
