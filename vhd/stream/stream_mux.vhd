-- Multiplexer for gathering multiple data streams into a single time
-- multiplexed stream.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.stream_defs.all;

entity stream_mux is
    generic (
        WIDTH : natural;
        WAYS : natural
    );
    port (
        clk_i : in std_ulogic;

        -- Input data, can be present every tick or as strobed
        enables_i : in std_ulogic_vector(0 to WAYS-1);
        data_i : in vector_array(0 to WAYS-1)(WIDTH-1 downto 0);

        stream_o : out data_stream_t(data(WIDTH-1 downto 0))
    );
end;

architecture arch of stream_mux is
    signal way : natural range 0 to WAYS-1 := 0;
    signal enables_in : enables_i'SUBTYPE := (others => '0');
    signal data_in : data_i'SUBTYPE;
    signal stream_out : stream_o'SUBTYPE := (
        valid => '0', last => '0', data => (others => '0'));

begin
    process (clk_i) begin
        if rising_edge(clk_i) then
            for i in 0 to WAYS-1 loop
                if enables_i(i) then
                    data_in(i) <= data_i(i);
                    enables_in(i) <= '1';
                elsif way = i then
                    enables_in(i) <= '0';
                end if;
            end loop;

            if enables_in(way) then
                stream_out <= (
                    valid => '1',
                    last => to_std_ulogic(way = WAYS-1),
                    data => data_in(way));
                way <= 0 when way = WAYS-1 else way + 1;
            else
                stream_out <= (
                    valid => '0', last => '0',
                    data => (others => '0'));
            end if;
        end if;
    end process;

    stream_o <= stream_out;
end;
