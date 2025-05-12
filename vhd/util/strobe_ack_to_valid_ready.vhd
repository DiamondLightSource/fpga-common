-- Convert strobe/ack interface to ready/valid handshake

-- Superficially the register strobe/ack handshake is interchangeable with the
-- AXI style ready/valid handshake, with the only difference being that ready
-- must be held once asserted until acknowledged by ready.
--
-- HOWEVER, there is an important extra difference, documented in the notes for
-- register_buffer.vhd; there are two cases for ack: either ack must ALWAYS be
-- asserted, OR ack must only be asserted in (clocked) response to strobe.
--
-- This means that when translating from strobe/ack to ready/valid we need to
-- consider three cases based on the behaviour of the ready input:
--
--  Trivial case:  if ready is always asserted then simply assign
--          ack_o <= ready_i;  or equivalently, ack_o <= '1';
--          valid_o <= strobe_i;
--      This entity can be used in this case and perhaps busy will be optimised
--      away, but it's probably simpler to just set ack_o
--
--  Normal case: ready is only asserted in response to valid.  This is directly
--      supported by this entity without setting the INDEPENDENT_READY generic.
--
--  Independent ready: ready can be asserted at any time.  In this case special
--      processing is required so that we only assert ack_o in response to a
--      processed strobe.  Set INDEPENDENT_READY=true for this case.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity strobe_ack_to_valid_ready is
    generic (
        INDEPENDENT_READY : boolean := false
    );
    port (
        clk_i : in std_ulogic;

        strobe_i : in std_ulogic;
        ack_o : out std_ulogic := '0';

        valid_o : out std_ulogic := '0';
        ready_i : in std_ulogic
    );
end;

architecture arch of strobe_ack_to_valid_ready is
    signal busy : std_ulogic := '0';
    signal ack_out : std_ulogic := '0';

begin
    valid_o <= strobe_i or busy;

    process (clk_i) begin
        if rising_edge(clk_i) then
            ack_out <= ready_i and valid_o;
            if strobe_i and not ready_i then
                busy <= '1';
            elsif ready_i then
                busy <= '0';
            end if;
        end if;
    end process;

    gen_ack : if INDEPENDENT_READY generate
        ack_o <= ack_out;
    else generate
        ack_o <= ready_i;
    end generate;
end;
