-- Definitions for stream capture support

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

package stream_defs is
    -- Basic streamed data
    type data_stream_t is record
        valid : std_ulogic;
        last : std_ulogic;
        data : std_ulogic_vector;
    end record;

    -- Array of data streams
    type data_stream_array_t is array (natural range <>) of data_stream_t;

    function left_align(stream : data_stream_t; size : natural)
        return data_stream_t;
end;

package body stream_defs is
    function left_align(stream : data_stream_t; size : natural)
        return data_stream_t
    is
        variable result : data_stream_t(data(size-1 downto 0));
    begin
        result := (
            valid => stream.valid,
            last => stream.last,
            data => left_align(stream.data, size));
        return result;
    end;
end;
