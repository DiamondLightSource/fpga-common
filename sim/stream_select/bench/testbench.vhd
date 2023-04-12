library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.stream_defs.all;

entity testbench is
end testbench;


architecture arch of testbench is
    signal clk : std_ulogic := '0';

    procedure clk_wait(count : in natural := 1) is
    begin
        for i in 1 to count loop
            wait until rising_edge(clk);
        end loop;
    end procedure;

    constant STREAM_COUNT : natural := 4;
    subtype STREAMS_RANGE is natural range 0 to STREAM_COUNT-1;
    subtype SELECT_RANGE is natural range bits(STREAM_COUNT-1)-1 downto 0;
    subtype PAYLOAD_RANGE is natural range 31 downto 0;

    -- Configured behaviours for the four test streams
    constant BURST_LENGTHS : integer_array(STREAMS_RANGE) := ( 8,  6,  3,  1);
    constant BURST_DELAYS  : integer_array(STREAMS_RANGE) := ( 0, 23, 17,  0);
    constant DATA_GAPS     : integer_array(STREAMS_RANGE) := ( 0,  1,  2,  0);

    signal streams_in : data_stream_array_t(STREAMS_RANGE)(data(PAYLOAD_RANGE));

    signal select_in : unsigned(SELECT_RANGE);
    signal select_out : unsigned(SELECT_RANGE);
    signal stream_out : data_stream_t(data(PAYLOAD_RANGE));

begin
    clk <= not clk after 2 ns;


    -- Stream selection, device under test
    sel : entity work.stream_select port map (
        clk_i => clk,

        streams_i => streams_in,
        select_i => select_in,

        select_o => select_out,
        stream_o => stream_out
    );


    -- Generate test streams
    gen_streams : for n in STREAMS_RANGE generate
        gen_stream : entity work.stream_generator generic map (
            BURST_LENGTH => BURST_LENGTHS(n),
            BURST_DELAY => BURST_DELAYS(n),
            TAG => n,
            DATA_GAP => DATA_GAPS(n)
        ) port map (
            clk_i => clk,
            stream_o => streams_in(n)
        );
    end generate;


    -- Test bench
    process begin
        select_in <= "00";
        clk_wait(20);
        select_in <= "01";
        clk_wait(35);
        select_in <= "10";
        clk_wait(35);
        select_in <= "11";
        clk_wait(35);
    end process;


    -- Validate received packets
    validate : entity work.validate port map (
        clk_i => clk,
        stream_i => stream_out,
        select_i => select_out
    );
end;
