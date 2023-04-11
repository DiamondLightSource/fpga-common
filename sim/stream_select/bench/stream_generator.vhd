-- Simple stream generator for testbench

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.stream_defs.all;

use work.test_defs.all;

entity stream_generator is
    generic (
        BURST_LENGTH : natural;
        BURST_DELAY : natural;
        TAG : natural;
        DATA_GAP : natural := 0
    );
    port (
        clk_i : in std_ulogic;
        stream_o : out data_stream_t
    );
end;

architecture arch of stream_generator is
    constant DATA_WIDTH : natural := stream_o.data'LENGTH - 4;
    constant TAG_VALUE : std_ulogic_vector(2 downto 0)
        := to_std_ulogic_vector_u(TAG, 3);

    signal in_burst : boolean := false;
    signal burst_count : natural range 0 to BURST_LENGTH-1 := BURST_LENGTH-1;
    signal delay_count : natural range 0 to BURST_DELAY := BURST_DELAY;
    signal packet_count : natural := 0;

    signal gap_counter : natural := 0;

    signal valid_out : std_ulogic := '0';
    signal last_out : std_ulogic := '0';
    signal data_out : stream_o.data'SUBTYPE;

begin
    process (clk_i) begin
        if rising_edge(clk_i) then
            if gap_counter > 0 then
                valid_out <= '0';
                last_out <= '0';
                gap_counter <= gap_counter - 1;
            elsif in_burst then
                data_out <= to_std_ulogic_vector(payload_t'(
                    tag => TAG,
                    burst_length => BURST_LENGTH,
                    beat_count => BURST_LENGTH - 1 - burst_count,
                    packet_count => packet_count));
                valid_out <= '1';

                if burst_count = 0 then
                    burst_count <= BURST_LENGTH-1;
                    if BURST_DELAY > 0 then
                        in_burst <= false;
                    end if;
                    last_out <= '1';
                    packet_count <= packet_count + 1;
                else
                    burst_count <= burst_count - 1;
                    last_out <= '0';
                    gap_counter <= DATA_GAP;
                end if;
            else
                valid_out <= '0';
                last_out <= '0';
                if delay_count <= 1 then
                    delay_count <= BURST_DELAY;
                    in_burst <= true;
                else
                    delay_count <= delay_count - 1;
                end if;
            end if;
        end if;
    end process;

    stream_o <= (
        valid => valid_out,
        last => last_out,
        data => data_out
    );
end;
