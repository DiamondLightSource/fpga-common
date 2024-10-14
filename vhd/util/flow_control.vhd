-- Flow Control helper definitions

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package flow_control is
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


    -- Implements flow control for a skid buffer.  Designed to be invoked thus:
    --
    --  advance_half_skid_buffer(
    --      data_i.valid, ready,            -- Data in valid, consumer ready
    --      data_ready_o,                   -- Ready handshake to provider
    --      skid.valid, load_skid);
    --  if load_skid then skid <= data_i; end if;
    --
    --  if skid.valid then data := skid; else data := data_i; end if;
    --
    procedure advance_half_skid_buffer(
        valid_in : std_ulogic;
        ready_in : std_ulogic;
        signal ready_out : inout std_ulogic;
        signal skid_valid : inout std_ulogic;
        variable load_skid : out std_ulogic);


    -- Helper procedure for state machine advance.  Designed to be called with
    -- the following pattern of operation:
    --
    --      advance_state_machine(
    --          data_i.valid, ready_i,      -- Incoming state
    --          state_end, data_o.valid,    -- Current state
    --          ready_out, load_value)      -- Control
    --      if load_value then
    --          if data_o.valid and not state_end then
    --              data_o <= advance_data(data_o);
    --          else
    --              data_o <= data_i;
    --          end if;
    --      end if;
    --
    -- Note that state_end is automatically qualified by valid_out inside this
    -- procedure, but this test must be added to the conditional state update.
    procedure advance_state_machine(
        valid_in : std_ulogic;                  -- Incoming fresh state valid
        ready_in : std_ulogic;                  -- Consumer of state is ready
        state_end : std_ulogic;                 -- Fresh state must be loaded
        signal valid_out : inout std_ulogic;    -- State machine is valid
        variable ready_out : out std_ulogic;    -- Ready to consume incoming
        variable load_value : out std_ulogic);  -- State must be updated

    -- Advances a state machine directly fed by a ping-pong buffer
    procedure advance_state_machine_and_ping_pong(
        valid_in : std_ulogic;
        ready_in : std_ulogic;
        state_end : std_ulogic;
        signal valid_out : inout std_ulogic;
        signal ready_out : inout std_ulogic;
        variable load_value : out std_ulogic);
end;

package body flow_control is
    -- Implements a subtly optimised variant of the standard "ping-pong" buffer.
    -- The standard buffer alternates between two states: (input ready, output
    -- not valid), and (input not ready, output valid), with a sustained
    -- throughput of one transfer every two ticks, so long as the receiver is
    -- always ready when data is presented.  The implementation below slightly
    -- improves on this by allowing the receiver to be not ready when data is
    -- presented without losing throughput.
    --
    -- This implementation supports three states, all encoded in values of the
    -- signals ready_out, valid_out:
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
                    valid_out <= '1';       --
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
                assert false report "Invalid ping-pong state" severity error;
                ready_out <= '1';
                valid_out <= '0';
        end case;
    end;


    procedure advance_half_skid_buffer(
        valid_in : std_ulogic;
        ready_in : std_ulogic;
        signal ready_out : inout std_ulogic;
        signal skid_valid : inout std_ulogic;
        variable load_skid : out std_ulogic) is
    begin
        load_skid := '0';
        if ready_in then
            skid_valid <= '0';
            ready_out <= '1';
        elsif valid_in and ready_out then
            skid_valid <= '1';
            ready_out <= '0';
            load_skid := '1';
        end if;
        assert skid_valid = not ready_out severity failure;
    end;


    procedure advance_state_machine(
        valid_in : std_ulogic;
        ready_in : std_ulogic;
        state_end : std_ulogic;
        signal valid_out : inout std_ulogic;
        variable ready_out : out std_ulogic;
        variable load_value : out std_ulogic) is
    begin
        if not ready_in and valid_out then
            -- We have valid data and no taker, just stand still
            ready_out := '0';
            load_value := '0';
        elsif valid_out and not state_end then
            -- Advance the state machine, don't fetch fresh data
            ready_out := '0';
            load_value := '1';
        else
            -- End of state machine, load fresh data
            ready_out := '1';
            load_value := '1';
            valid_out <= valid_in;
        end if;
    end;

    procedure advance_state_machine_and_ping_pong(
        valid_in : std_ulogic;
        ready_in : std_ulogic;
        state_end : std_ulogic;
        signal valid_out : inout std_ulogic;
        signal ready_out : inout std_ulogic;
        variable load_value : out std_ulogic)
    is
        variable next_state_ready : std_ulogic;
        variable load_buffer : std_ulogic;
    begin
        advance_state_machine(
            valid_in, ready_in, state_end, valid_out,
            next_state_ready, load_value);
        advance_ping_pong_buffer(
            valid_in, next_state_ready, valid_out, ready_out, load_buffer);
        -- This is a bit tricky: in the case where the state machine has asked
        -- for a new value we need to defer to the ping pong buffer to determine
        -- if the new state can actually be loaded.
        if next_state_ready then
            load_value := load_buffer;
        end if;
    end;
end;
