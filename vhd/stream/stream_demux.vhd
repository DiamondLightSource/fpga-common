-- Demultiplexes start/enable/data sequence into parallel enables and data

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity stream_demux is
    generic (
        WIDTH : natural;
        WAYS : natural
    );
    port (
        clk_i : in std_ulogic;

        enable_i : in std_ulogic;
        last_i : in std_ulogic;
        data_i : in signed(WIDTH-1 downto 0);

        enables_o : out std_ulogic_vector(0 to WAYS-1) := (others => '0');
        data_o : out signed_array(0 to WAYS-1)(WIDTH-1 downto 0)
            := (others => (others => '0'))
    );
end;

architecture arch of stream_demux is
    signal way : natural range 0 to WAYS-1;

begin
    process (clk_i) begin
        if rising_edge(clk_i) then
            if enable_i then
                data_o(way) <= data_i;
                compute_strobe(enables_o, way);
                way <= 0 when last_i else way + 1;
            else
                enables_o <= (others => '0');
            end if;
        end if;
    end process;
end;
