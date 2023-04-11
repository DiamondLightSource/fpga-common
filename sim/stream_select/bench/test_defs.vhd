-- A structure for the packet payload

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

package test_defs is
    -- Payload contains information about packet used for validation
    type payload_t is record
        tag : natural;
        burst_length : natural;
        beat_count : natural;
        packet_count : natural;
    end record;

    function to_payload(data : std_ulogic_vector) return payload_t;
    function to_std_ulogic_vector(data : payload_t) return std_ulogic_vector;
end;

package body test_defs is
    function to_payload(data : std_ulogic_vector) return payload_t is
    begin
        return (
            tag => to_integer(unsigned(data(3 downto 0))),
            burst_length => to_integer(unsigned(data(11 downto 4))),
            beat_count => to_integer(unsigned(data(19 downto 12))),
            packet_count => to_integer(unsigned(data(31 downto 20))));
    end;

    function to_std_ulogic_vector(data : payload_t) return std_ulogic_vector is
    begin
        return
            to_std_ulogic_vector_u(data.packet_count, 12) &
            to_std_ulogic_vector_u(data.beat_count, 8) &
            to_std_ulogic_vector_u(data.burst_length, 8) &
            to_std_ulogic_vector_u(data.tag, 4);
    end;
end;
