-- Definitions for stream capture support

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package stream_defs is
    -- Basic streamed data
    type data_stream_t is record
        valid : std_ulogic;
        last : std_ulogic;
        data : std_ulogic_vector;
    end record;

    -- Array of data streams
    type data_stream_array_t is array (natural range <>) of data_stream_t;
end;
