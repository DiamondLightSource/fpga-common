-- FIFO helper definitions

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package fifo_defs is
    -- Helper procedure for implementing a simple "ping-pong" buffer.  This
    -- procedure must be called unconditionally in a clocked process and can
    -- be followed by conditionally loading the buffer.  This can safely be used
    -- for structured values with an integrated .valid field, as shown in the
    -- example below:
    --
    --      advance_ping_pong_buffer(
    --          data_i.valid, ready_i,      -- Incoming state
    --          data_o.valid, ready_o,      -- Outgoing state
    --          load_value);
    --      if load_value then data_o <= data_i; end if;
    --
    procedure advance_ping_pong_buffer(
        valid_in : std_ulogic;
        ready_in : std_ulogic;
        signal valid_out : inout std_ulogic;
        signal ready_out : inout std_ulogic;
        variable load_value : out std_ulogic);
end;

package body fifo_defs is
    -- Implements a subtly optimised variant of the standard "ping-pong" buffer.
    -- The standard buffer alternates between two states: (input ready, output
    -- not valid), and (input not ready, output valid), with a sustained
    -- throughput of one transfer every two ticks, so long as the receiver is
    -- always ready when data is presented.  The implementation below slightly
    -- improves on this by allowing the receiver to be not ready when data is
    -- presented without losing throughput.
    --
    -- This implementation supports three states, all encoded in values of the
    -- signals ready_out, valid out:
    --
    --      IDLE:   ready_out and not valid_out
    --      ACTIVE: not ready_out and valid_out
    --      DELAY:  ready_out and valid_out
    --
    -- with the following transitions (the transition ACTIVE=>DELAY is novel in
    -- this design):
    --
    --      IDLE =>
    --          if valid_in: state <= ACTIVE; load_value := true
    --      ACTIVE =>
    --          if ready_in and not valid_in: state <= IDLE
    --          if ready_in and valid_in: state <= DELAY; load_value := true
    --      DELAY =>
    --          if ready_in: state <= IDLE
    --          if not ready_in: state <= ACTIVE
    procedure advance_ping_pong_buffer(
        valid_in : std_ulogic;
        ready_in : std_ulogic;
        signal valid_out : inout std_ulogic;
        signal ready_out : inout std_ulogic;
        variable load_value : out std_ulogic) is
    begin
        load_value := '0';
        case std_ulogic_vector'(ready_out & valid_out) is
            when "10" =>    -- IDLE: accepting and nothing to send
                if valid_in then
                    ready_out <= '0';       -- state <= ACTIVE
                    valid_out <= '1';      --
                    load_value := '1';
                end if;
            when "01" =>    -- ACTIVE: sending and not accepting
                if ready_in then
                    if valid_in then
                        ready_out <= '1';   -- state <= DELAY
                        load_value := '1';
                    else
                        ready_out <= '1';   -- state <= IDLE
                        valid_out <= '0';
                    end if;
                end if;
            when "11" =>    -- DELAY: delayed acceptance of received value
                if ready_in then
                    valid_out <= '0';       -- state <= IDLE
                else
                    ready_out <= '0';       -- state <= ACTIVE
                end if;
            when others =>
                -- This is an invalid state, but going straight to IDLE is not
                -- a bad idea in this case.
                ready_out <= '1';
                valid_out <= '0';
        end case;
    end;
end;
