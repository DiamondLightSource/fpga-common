-- Simplified version of cross_clocks_write: brings a vector with valid strobe
-- from one domain to another without any handshaking.  Relies on upstream
-- pacing.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cross_clocks_strobe is
    generic (
        -- Should match period of the fastest clock frequency
        MAX_DELAY : real := 4.0
    );
    port (
        clk_in_i : in std_ulogic;
        clk_out_i : in std_ulogic;

        -- Incoming qualified data on clk_in_i domain
        data_i : in std_ulogic_vector;
        strobe_i : in std_ulogic;

        -- Outgoing qualified data on clk_out_i domain
        data_o : out std_ulogic_vector;
        strobe_o : out std_ulogic := '0'
    );
end;

architecture arch of cross_clocks_strobe is
    -- It is safe to say that strobe_o will be quite a while after data_o
    -- becomes valid, but specify a max_delay_from for confidence.  In fact
    -- 2*MAX_DELAY would be just fine...
    attribute max_delay_from : string;
    attribute max_delay_from of data_o : signal is to_string(MAX_DELAY);

begin
    process (clk_in_i) begin
        if rising_edge(clk_in_i) then
            if strobe_i then
                data_o <= data_i;
            end if;
        end if;
    end process;

    sync_strobe : entity work.sync_pulse port map (
        clk_in_i => clk_in_i,
        clk_out_i => clk_out_i,
        pulse_i => strobe_i,
        pulse_o => strobe_o
    );
end;
