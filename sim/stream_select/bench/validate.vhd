-- Validates packet using test payload structure

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.support.all;
use work.stream_defs.all;

use work.test_defs.all;

entity validate is
    port (
        clk_i : in std_ulogic;
        stream_i : in data_stream_t;
        select_i : in unsigned
    );
end;

architecture arch of validate is
    signal last_seen : std_ulogic := '1';
    signal current_payload : payload_t;
    signal saved_payload : payload_t;
    signal ref_payload : payload_t;

    signal beat_counter : natural;

    procedure check_match(
        message : string; current : natural; reference : natural) is
    begin
        assert current = reference
            report message & ": " & to_string(current) &
                " /= " & to_string(reference)
            severity failure;
    end;

begin
    current_payload <= to_payload(stream_i.data);
    ref_payload <=
        current_payload when last_seen
        else saved_payload;

    process (clk_i) begin
        if rising_edge(clk_i) then
            if stream_i.valid then
                last_seen <= stream_i.last;

                if last_seen then
                    saved_payload <= current_payload;
                end if;

                if stream_i.last then
                    beat_counter <= 0;
                    check_match("Last",
                        beat_counter, ref_payload.burst_length - 1);
                else
                    beat_counter <= beat_counter + 1;
                end if;

                check_match("Beat",
                    current_payload.beat_count, beat_counter);
                check_match("Packet",
                    current_payload.packet_count, ref_payload.packet_count);
                check_match("Tag", current_payload.tag, ref_payload.tag);
                check_match("Length",
                    current_payload.burst_length, ref_payload.burst_length);
                check_match("Selection",
                    to_integer(select_i), current_payload.tag);
            end if;
        end if;
    end process;
end;
