-- Pass data across clock domains

-- Handshake as follows:
--
--  clk_in_i    /   /   /   /   /   /   /   /   /   /   /   /   /   /   /
--                   ___
--  strobe_i  ______/   \________________________________________________
--                                                               ___
--  ack_o     __________________________________________________/   \____
--                                                              _________
--  data_o    XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX_________
--
--  clk_out_i    /    /    /    /    /    /    /    /    /    /    /    /
--                                    ____
--  strobe_o  _______________________/    \______________________________
--                                         ____
--  ack_i     XXXXXXXXXXXXXXXXXXXXXXXX____/    XXXXXXXXXXXXXXXXXXXXXXXXXX
--                                         ____
--  data_i    XXXXXXXXXXXXXXXXXXXXXXXXXXXXX____XXXXXXXXXXXXXXXXXXXXXXXXXX
--
-- Note that data_o remains valid until at least the next strobe_i, but it is
-- safest to treat it as strobed by ack_o.

-- The following rule must be present in the constraints file:
--
--  set_max_delay 4 -datapath_only \
--      -from [get_cells -hierarchical -filter { max_delay_from == "TRUE" }]
--
-- Here the actually required delay depends on the clock frequencies.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cross_clocks_read is
    generic (
        -- Should match period of the fastest clock frequency
        MAX_DELAY : real := 4.0
    );
    port (
        clk_in_i : in std_ulogic;
        -- clk_out status on clk_in domain.  If this is '0' then all register
        -- transactions will be unconditionally completed to avoid stalls.
        clk_out_ok_i : in std_ulogic := '1';
        -- Strobe and ack for incoming data on clk_in_i clock domain
        strobe_i : in std_ulogic;
        ack_o : out std_ulogic;
        data_o : out std_ulogic_vector;

        clk_out_i : in std_ulogic;
        -- Update strobe and date on clk_out_i clock domain
        strobe_o : out std_ulogic;
        ack_i : in std_ulogic := '1';
        data_i : in std_ulogic_vector
    );
end;

architecture arch of cross_clocks_read is
    signal ack_wait : std_ulogic := '0';
    signal data_in : data_i'SUBTYPE := (others => '0');
    signal ack_in : std_ulogic := '0';
    signal valid_ack : std_ulogic;

    attribute KEEP : string;
    attribute KEEP of data_in : signal is "TRUE";
    -- Ensure data_in is valid for receiver
    attribute max_delay_from : string;
    attribute max_delay_from of data_in : signal is to_string(MAX_DELAY);

begin
    sync : entity work.cross_clocks port map (
        clk_in_i => clk_in_i,
        clk_out_ok_i => clk_out_ok_i,
        strobe_in_i => strobe_i,
        ack_in_o => ack_o,

        clk_out_i => clk_out_i,
        strobe_out_o => strobe_o,
        ack_out_i => ack_in
    );

    valid_ack <= (strobe_o or ack_wait) and ack_i;
    process (clk_out_i) begin
        if rising_edge(clk_out_i) then
            if strobe_o and not ack_i then
                ack_wait <= '1';
            elsif ack_i then
                ack_wait <= '0';
            end if;

            ack_in <= valid_ack;
            if valid_ack then
                data_in <= data_i;
            end if;
        end if;
    end process;
    data_o <= data_in;
end;
