-- Read-write clock domain crossing transaction

-- This encapsulates both cross_clocks_read and cross_clocks_write

-- Handshake as follows:
--
--  clk_in_i        /   /   /   /   /   /   /   /   /   /   /   /   /   /   /
--                       ___
--  strobe_i      ______/   \________________________________________________
--                                                                   ___
--  ack_o         __________________________________________________/   \____
--                       _______________________________________________
--  write_data_i  XXXXXXX_______________________________________________XXXXX
--                                                                  _________
--  read_data_o   XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX_________
--
--  clk_out_i        /    /    /    /    /    /    /    /    /    /    /    /
--                                        ____
--  strobe_o      _______________________/    \______________________________
--                                             ____
--  ack_i         XXXXXXXXXXXXXXXXXXXXXXXX____/    XXXXXXXXXXXXXXXXXXXXXXXXXX
--                                        _________
--  write_data_o  XXXXXXXXXXXXXXXXXXXXXXXX_________XXXXXXXXXXXXXXXXXXXXXXXXXX
--                                             ____
--  read_data_i   XXXXXXXXXXXXXXXXXXXXXXXXXXXXX____XXXXXXXXXXXXXXXXXXXXXXXXXX
--
-- Note that read_data_o and write_data_o remain valid until at least the next
-- strobe, but it is safest to treat it as invalid once ack has been processed.

-- The following rule must be present in the constraints file:
--
--  set_max_delay 4 -datapath_only \
--      -from [get_cells -hierarchical -filter { max_delay_from == "TRUE" }]
--
-- Here the actually required delay depends on the clock frequencies.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cross_clocks_write_read is
    port (
        clk_in_i : in std_ulogic;
        -- Strobe and ack for incoming data on clk_in_i clock domain
        strobe_i : in std_ulogic;
        ack_o : out std_ulogic;
        write_data_i : in std_ulogic_vector;
        read_data_o : out std_ulogic_vector;

        clk_out_i : in std_ulogic;
        -- Update strobe and date on clk_out_i clock domain
        strobe_o : out std_ulogic;
        ack_i : in std_ulogic := '1';
        write_data_o : out std_ulogic_vector;
        read_data_i : in std_ulogic_vector
    );
end;

architecture arch of cross_clocks_write_read is
    signal strobe_in : std_ulogic := '0';
    signal write_data : write_data_i'SUBTYPE;

    signal ack_wait : std_ulogic := '0';
    signal read_data : read_data_o'SUBTYPE;
    signal ack_in : std_ulogic := '0';
    signal valid_ack : std_ulogic;

    -- Ensure data in transit is not optimised away so we can mark it
    attribute KEEP : string;
    attribute KEEP of write_data : signal is "TRUE";
    attribute KEEP of read_data : signal is "TRUE";
    -- Ensure data is valid for receiver.  This custom attribute is picked up
    -- by the appropriate matching constraint
    attribute max_delay_from : string;
    attribute max_delay_from of write_data : signal is "TRUE";
    attribute max_delay_from of read_data : signal is "TRUE";

begin
    sync : entity work.cross_clocks port map (
        clk_in_i => clk_in_i,
        strobe_in_i => strobe_in,
        ack_in_o => ack_o,

        clk_out_i => clk_out_i,
        strobe_out_o => strobe_o,
        ack_out_i => ack_in
    );

    -- Writing data, register on clk_in_i for CC transfer.  We delay the data
    -- and strobe together to ensure that the received data has predictable
    -- validity that doesn't depend on the sender's clock frequency.
    process (clk_in_i) begin
        if rising_edge(clk_in_i) then
            strobe_in <= strobe_i;
            if strobe_i then
                write_data <= write_data_i;
            end if;
        end if;
    end process;
    write_data_o <= write_data;

    -- Reading data, register data and manage ack handshake
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
                read_data <= read_data_i;
            end if;
        end if;
    end process;
    read_data_o <= read_data;
end;
