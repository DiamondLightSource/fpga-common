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
--                       _______________________________________________
--  data_in   XXXXXXXXXXX_______________________________________________X
--                       ___________________
--  busy_in   __________/                   \____________________________
--                                       ___________________
--  ack_in    __________________________/                   \____________
--
--  clk_out_i    /    /    /    /    /    /    /    /    /    /    /    /
--                               ___________________
--  busy_out  __________________/                   \____________________
--                                    ____
--  strobe_o  _______________________/    \______________________________
--                                    ___________________________________
--  data_o    XXXXXXXXXXXXXXXXXXXXXXXX___________________________________
--
-- A max delay constraint is applied from data_in (called
-- max_delay_register_from_cc below) to data_o (also max_delay_register_to_cc).


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cross_clocks is
    generic (
        WIDTH : natural
    );
    port (
        clk_in_i : in std_ulogic;

        -- Strobe and ack for incoming data on clk_in_i clock domain
        strobe_i : in std_ulogic;
        ack_o : out std_ulogic := '0';
        data_i : in std_ulogic_vector(WIDTH-1 downto 0);

        clk_out_i : in std_ulogic;

        -- Update strobe and date on clk_out_i clock domain
        strobe_o : out std_ulogic := '0';
        data_o : out std_ulogic_vector(WIDTH-1 downto 0) := (others => '0')
    );
end;

architecture arch of cross_clocks is
    signal busy_in : std_ulogic := '0';
    signal busy_out : std_ulogic;
    signal ack_in : std_ulogic;
    signal strobe_out : std_ulogic;

    -- These two register names will be recognised in clocks.xdc and will
    -- trigger a conservative set_max_delay setting on the path between these
    -- registers.
    signal max_delay_register_from_cc : std_ulogic_vector(WIDTH-1 downto 0);
    signal max_delay_register_to_cc : std_ulogic_vector(WIDTH-1 downto 0);
    attribute KEEP : string;
    attribute KEEP of max_delay_register_from_cc : signal is "TRUE";
    attribute KEEP of max_delay_register_to_cc : signal is "TRUE";

begin
    -- Transfer busy_in state across the clock domain boundary and back again.
    -- The transfer is:
    --   strobe_i =>                clk_in
    --      busy_in <= '1' =>       clk_in
    --      busy_out <= '1' =>      clk_out     register data, send strobe_o
    --      ack_in <= '1' =>        clk_in
    --      busy_in <= '0' =>       clk_in
    --      busy_out <= '0' =>      clk_out
    --      ack_in <= '0'           clk_in      send ack_o
    sync_in2out : entity work.sync_bit port map (
        clk_i => clk_out_i,
        bit_i => busy_in,
        bit_o => busy_out
    );

    sync_out2in : entity work.sync_bit port map (
        clk_i => clk_in_i,
        bit_i => busy_out,
        bit_o => ack_in
    );


    -- Use falling edge of ack_in to trigger ack_o: we're ready for another go!
    ack : entity work.edge_detect generic map (
        REGISTER_EDGE => true,
        INITIAL_STATE => '1'
    ) port map (
        clk_i => clk_in_i,
        data_i(0) => not ack_in,
        edge_o(0) => ack_o
    );

    process (clk_in_i) begin
        if rising_edge(clk_in_i) then
            if strobe_i then
                busy_in <= '1';
                max_delay_register_from_cc <= data_i;
            elsif ack_in then
                busy_in <= '0';
            end if;
        end if;
    end process;


    -- Use rising edge of busy_out to trigger data transfer
    strobe : entity work.edge_detect generic map (
        REGISTER_EDGE => false
    ) port map (
        clk_i => clk_out_i,
        data_i(0) => busy_out,
        edge_o(0) => strobe_out
    );

    process (clk_out_i) begin
        if rising_edge(clk_out_i) then
            strobe_o <= strobe_out;
            if strobe_out then
                max_delay_register_to_cc <= max_delay_register_from_cc;
            end if;
        end if;
    end process;
    data_o <= max_delay_register_to_cc;
end;
