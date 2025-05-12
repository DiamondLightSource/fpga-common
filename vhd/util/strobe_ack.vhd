-- Strobe acknowledgement with busy control

-- Allows overlapping register requests: the busy_i signal is used to block
-- acknowledgement until ready.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity strobe_ack is
    generic (
        -- The busy_i signal can be stretched by this number of ticks to take
        -- account of extra external delays
        STRETCH_BUSY : natural := 0;
        -- By default ack_o is generated one tick after strobe_o
        ACK_DELAY : natural := 1
    );
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
    signal busy : std_ulogic;
    signal pending : std_ulogic := '0';
    signal ready : std_ulogic;

begin
    stretch : entity work.stretch_pulse generic map (
        DELAY => STRETCH_BUSY,
        REGISTER_OUT => false
    ) port map (
        clk_i => clk_i,
        pulse_i => busy_i,
        pulse_o => busy
    );

    ready <= strobe_i or pending;
    strobe_o <= not busy and ready;
    process (clk_i) begin
        if rising_edge(clk_i) then
            pending <= busy and ready;
        end if;
    end process;

    delay : entity work.fixed_delay generic map (
        DELAY => ACK_DELAY
    ) port map (
        clk_i => clk_i,
        data_i(0) => strobe_o,
        data_o(0) => ack_o
    );
end;
