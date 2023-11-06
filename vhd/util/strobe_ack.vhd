-- Strobe acknowledgement with busy control

-- Allows overlapping register requests

--  clk_i       /   /   /   /   /   /   /   /   /   /   /   /   /   /   /   /
--               ___     ___
--  strobe_i  __/   \___/   \
--                   ___
--  busy_i    ______/
--  pending   ______
--  strobe_o  __/   \___
--  ack_o     ______/   \__

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity strobe_ack is
    port (
        clk_i : in std_ulogic;

        -- These two signals are designed to be connected to the external
        -- interface: strobe_i is acknowledged as soon as possible
        strobe_i : in std_ulogic;
        ack_o : out std_ulogic := '0';

        -- Control signals.  ack_o will not be driven until busy_i is set
        busy_i : in std_ulogic;
        strobe_o : out std_ulogic
    );
end;

architecture arch of strobe_ack is
    signal pending : std_ulogic := '0';
    signal ready : std_ulogic;

begin
    ready <= strobe_i or pending;
    strobe_o <= not busy_i and ready;
    process (clk_i) begin
        if rising_edge(clk_i) then
            ack_o <= strobe_o;
            pending <= busy_i and ready;
        end if;
    end process;
end;
