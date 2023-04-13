-- Demultiplexes start/enable/data sequence into parallel enables and data

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.stream_defs.all;

entity stream_demux is
    generic (
        WIDTH : natural;
        WAYS : natural
    );
    port (
        clk_i : in std_ulogic;

        stream_i : in data_stream_t(data(WIDTH-1 downto 0));

        enables_o : out std_ulogic_vector(0 to WAYS-1) := (others => '0');
        data_o : out vector_array(0 to WAYS-1)(WIDTH-1 downto 0)
            := (others => (others => '0'))
    );
end;

architecture arch of stream_demux is
    signal way : natural range 0 to WAYS-1;

begin
    process (clk_i) begin
        if rising_edge(clk_i) then
            if stream_i.valid then
                data_o(way) <= stream_i.data;
                compute_strobe(enables_o, way);
                way <= 0 when stream_i.last else way + 1;
            else
                enables_o <= (others => '0');
            end if;
        end if;
    end process;
end;
