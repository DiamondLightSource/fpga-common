-- Handshaking across clock domains

-- Handshake as follows:
--
--  clk_in_i        /   /   /   /   /   /   /   /   /   /   /   /   /   /   /
--                       ___
--  strobe_in_i   ______/   \________________________________________________
--                __________ ________________________________________________
--  strobe_in     __________X________________________________________________
--                __________________________________________ ________________
--  ack_in        __________________________________________X________________
--                                                               ___
--  ack_in_o      ______________________________________________/   \________
--
--  clk_out_i        /    /    /    /    /    /    /    /    /    /    /    /
--                __________________ ________________________________________
--  strobe_out    __________________X________________________________________
--                                        ____
--  strobe_out_o  _______________________/    \______________________________
--                                             ____
--  ack_wait      ____________________________/    \_________________________
--                                             ____
--  ack_out_i     xxxxxxxxxxxxxxxxxxxxxxx_____/    xxxxxxxxxxxxxxxxxxxxxxxxxx
--                _________________________________ _________________________
--  ack_out       _________________________________X_________________________

-- The minimum delays from strobe_in_i to strobe_out_o and from ack_out_i to
-- ack_in_o determine the appropriate max_delay settings for any associated
-- data transported at the same time.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cross_clocks is
    port (
        clk_in_i : in std_ulogic;
        -- clk_out status on clk_in domain.  If this is '0' then all register
        -- transactions will be unconditionally completed to avoid stalls.
        clk_out_ok_i : in std_ulogic := '1';
        -- Strobe and ack for incoming data on clk_in_i clock domain
        strobe_in_i : in std_ulogic;
        ack_in_o : out std_ulogic := '0';

        clk_out_i : in std_ulogic;
        -- Update strobe and date on clk_out_i clock domain
        strobe_out_o : out std_ulogic := '0';
        ack_out_i : in std_ulogic := '1'
    );
end;

architecture arch of cross_clocks is
    -- Signals on in clock domain
    signal strobe_in : std_ulogic := '0';
    signal ack_in : std_ulogic;
    signal last_ack_in : std_ulogic := '0';

    -- Signals on out clock domain
    signal strobe_out : std_ulogic;
    signal last_strobe_out : std_ulogic := '0';
    signal ack_out : std_ulogic := '0';
    signal ack_wait : std_ulogic := '0';

begin
    -- strobe_out(clk_out_i) <= strobe_in(clk_in_i)
    sync_busy : entity work.sync_bit port map (
        clk_i => clk_out_i,
        bit_i => strobe_in,
        bit_o => strobe_out
    );

    -- ack_in(clk_in_i) <= ack_out(clk_out_i)
    sync_ack : entity work.sync_bit port map (
        clk_i => clk_in_i,
        bit_i => ack_out,
        bit_o => ack_in
    );


    -- Sending clock domain: request transfer, wait for ack
    process (clk_in_i) begin
        if rising_edge(clk_in_i) then
            -- Toggle strobe_in state to initiate transaction request.  If
            -- clk_out is stalled don't do this and instead ack immediately.
            if strobe_in_i and clk_out_ok_i then
                strobe_in <= not strobe_in;
            end if;
            -- Pulse acknowledge when ack_in changes state, or hold high when
            -- clk_out is stalled.
            last_ack_in <= ack_in;
            ack_in_o <= (ack_in xor last_ack_in) or not clk_out_ok_i;
        end if;
    end process;

    -- Receiving clock domain: wait for request, send acknowledge.  May need to
    -- wait for incoming ack from outging side, and also need to allow for
    -- persistent ack: only sample ack when strobe is outstanding.
    process (clk_out_i) begin
        if rising_edge(clk_out_i) then
            -- Pulse strobe when strobe_out changes state
            last_strobe_out <= strobe_out;
            strobe_out_o <= strobe_out xor last_strobe_out;

            -- Toggle ack_out when ack, keep track of waiting state
            if strobe_out_o and not ack_out_i then
                ack_wait <= '1';
            elsif ack_out_i then
                ack_wait <= '0';
            end if;
            if (strobe_out_o or ack_wait) and ack_out_i then
                ack_out <= not ack_out;
            end if;
        end if;
    end process;
end;
