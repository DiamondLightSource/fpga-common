-- Synchronises a pulse between two clock domains via a bit synchroniser.
--
--  clk_in_i    /   /   /   /   /   /   /   /   /   /   /   /
--                   ___         ___                 ___
--  pulse_i     ____/   \_______/   \_______________/   \____
--                       ___________                     ____
--  signal_in   ________/           \___________________/
--
--  clk_out_i   /    /    /    /    /    /    /    /    /
--                              ______________
--  signal_out  _______________/              \______________
--                              ____           ____
--  pulse_o     _______________/    \_________/    \_________
--
--
-- Note that if input pulses are too close together (this depends on the ratio
-- between the input and output clock) then a pulse can be lost.  Note that the
-- ready_o signal is a very pessimistic judge of when it is safe to send.

library ieee;
use ieee.std_logic_1164.all;

use work.support.all;

entity sync_pulse is
    port (
        clk_in_i : in std_ulogic;
        clk_out_i : in std_ulogic;
        pulse_i : in std_ulogic;    -- On clk_in_i
        pulse_o : out std_ulogic    -- On clk_out_i
    );
end;

architecture arch of sync_pulse is
    signal signal_in : std_ulogic := '0';
    signal signal_out : std_ulogic;
    signal last_signal_out : std_ulogic := '0';

begin
    -- Convert incoming pulse to an edge
    process (clk_in_i) begin
        if rising_edge(clk_in_i) then
            if pulse_i = '1' then
                signal_in <= not signal_in;
            end if;
        end if;
    end process;

    -- Synchronise edge with outgoing clock
    sync_in : entity work.sync_bit port map (
        clk_i => clk_out_i,
        bit_i => signal_in,
        bit_o => signal_out
    );

    -- Generate pulse from edge
    process (clk_out_i) begin
        if rising_edge(clk_out_i) then
            last_signal_out <= signal_out;
        end if;
    end process;
    pulse_o <= to_std_ulogic(signal_out /= last_signal_out);
end;
