-- Select one from an array of streams

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.stream_defs.all;

entity stream_select is
    port (
        clk_i : in std_ulogic;

        streams_i : in data_stream_array_t;
        select_i : in unsigned;

        select_o : out unsigned;
        stream_o : out data_stream_t
    );
end;

architecture arch of stream_select is
    constant STREAM_COUNT : natural := streams_i'LENGTH;
    subtype SELECT_RANGE is natural range 0 to STREAM_COUNT - 1;
    subtype DATA_RANGE is natural range stream_o.data'RANGE;

    signal streams_in : streams_i'SUBTYPE
        := (others => (valid => '0', last => '0', data => (others => '0')));
    signal selected_in : data_stream_t(data(DATA_RANGE))
        := (valid => '0', last => '0', data => (others => '0'));
    signal stream_out : data_stream_t(data(DATA_RANGE))
        := (valid => '0', last => '0', data => (others => '0'));

    -- Try stream_o'SUBTYPE instead of data_stream_t(data(DATA_RANGE)) with the
    -- latest Questa Sim and Vivado
    --     signal stream_out : stream_o'SUBTYPE

    signal last_seen_in : std_ulogic_vector(SELECT_RANGE) := (others => '1');
    signal selected_last_seen : std_ulogic := '1';

    signal select_in : SELECT_RANGE := 0;
    signal selection : SELECT_RANGE := 0;

    -- Synchronsation of selection change with packet boundaries to ensure we
    -- don't generate broken packets
    type state_t is (ACTIVE, SKIP, SWITCHING);
    signal state : state_t := ACTIVE;
    signal next_state : state_t;

    signal switch_state : boolean;
    signal valid_selection : boolean;

begin
    switch_state <=
        state = ACTIVE and
        select_in /= selection and selected_last_seen = '1';
    valid_selection <= next_state = ACTIVE and not switch_state;

    process (all) begin
        next_state <= state;
        case state is
            when ACTIVE =>
                -- Switch on edge of incoming packet
                if switch_state then
                    next_state <= SKIP;
                end if;
            when SKIP =>
                -- Wait for selection to change
                next_state <= SWITCHING;
            when SWITCHING =>
                -- Wait for new edge of packet
                if selected_last_seen then
                    next_state <= ACTIVE;
                end if;
        end case;
    end process;

    process (clk_i) begin
        if rising_edge(clk_i) then
            streams_in <= streams_i;
            select_in <= to_integer(select_i);

            for n in SELECT_RANGE loop
                if streams_in(n).valid then
                    last_seen_in(n) <= streams_in(n).last;
                end if;
            end loop;

            selected_in <= streams_in(selection);
            selected_last_seen <= last_seen_in(selection);

            state <= next_state;
            if switch_state then
                selection <= select_in;
            end if;

            stream_out <= (
                valid => selected_in.valid and to_std_ulogic(valid_selection),
                last => selected_in.last,
                data => selected_in.data);
            select_o <= to_unsigned(selection, select_o'LENGTH);
        end if;
    end process;
    stream_o <= stream_out;
end;
