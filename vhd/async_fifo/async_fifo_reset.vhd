-- Reset support for asynchronous FIFOs

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity async_fifo_reset is
    port (
        -- Asynchronous reset request
        reset_i : in std_ulogic;
        -- Resets on separate clock domains.  Write is held in reset until after
        -- read has cleared
        write_clk_i : in std_ulogic;
        write_reset_o : out std_ulogic;
        read_clk_i : in std_ulogic;
        read_reset_o : out std_ulogic
    );
end;

architecture arch of async_fifo_reset is
begin
    -- Convert reset request into resets synchronous with each clock domain.
    -- Hold write in reset until read is clear.
    sync_write : entity work.sync_bit port map (
        clk_i => write_clk_i,
        bit_i => reset_i or read_reset_o,
        bit_o => write_reset_o
    );

    sync_read : entity work.sync_bit port map (
        clk_i => read_clk_i,
        bit_i => reset_i,
        bit_o => read_reset_o
    );
end;
