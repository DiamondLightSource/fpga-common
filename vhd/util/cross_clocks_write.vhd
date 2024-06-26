-- Pass data across clock domains

-- Handshake as follows:
--
--  clk_in_i    /   /   /   /   /   /   /   /   /   /   /   /   /   /   /
--                   ___
--  strobe_i  ______/   \________________________________________________
--                                                               ___
--  ack_o     __________________________________________________/   \____
--                   _______________________________________________
--  data_i    XXXXXXX_______________________________________________XXXXX
--
--  clk_out_i    /    /    /    /    /    /    /    /    /    /    /    /
--                                    ____
--  strobe_o  _______________________/    \______________________________
--                                    ___________________________________
--  data_o    XXXXXXXXXXXXXXXXXXXXXXXX___________________________________

-- The following rule must be present in the constraints file:
--  set_max_delay 4 -datapath_only \
--      -from [get_cells -hierarchical -filter { max_delay_from == "TRUE" }]
-- Here the actually required delay depends on the clock frequencies.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cross_clocks_write is
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
        data_i : in std_ulogic_vector;

        clk_out_i : in std_ulogic;
        -- Update strobe and date on clk_out_i clock domain
        strobe_o : out std_ulogic;
        ack_i : in std_ulogic := '1';
        data_o : out std_ulogic_vector
    );
end;

architecture arch of cross_clocks_write is
    signal strobe_in : std_ulogic := '0';
    signal data_in : data_i'SUBTYPE;

    attribute KEEP : string;
    attribute KEEP of data_in : signal is "TRUE";
    -- Ensure data_in is valid for receiver
    attribute max_delay_from : string;
    attribute max_delay_from of data_in : signal is to_string(MAX_DELAY);

begin
    sync : entity work.cross_clocks port map (
        clk_in_i => clk_in_i,
        clk_out_ok_i => clk_out_ok_i,
        strobe_in_i => strobe_in,
        ack_in_o => ack_o,

        clk_out_i => clk_out_i,
        strobe_out_o => strobe_o,
        ack_out_i => ack_i
    );

    process (clk_in_i) begin
        if rising_edge(clk_in_i) then
            strobe_in <= strobe_i;
            if strobe_i then
                data_in <= data_i;
            end if;
        end if;
    end process;
    data_o <= data_in;
end;
