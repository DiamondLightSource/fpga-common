-- Multi-channel polyphase FIR

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity poly_fir is
    generic (
        -- Number of taps in each bank of the filter
        TAP_COUNT : natural;
        -- Decimation implemented by this filter
        DECIMATION : natural;
        -- Specify incoming data width
        DATA_WIDTH : natural;
        -- This determines the number of channels supported by this filter
        WAYS : natural := 1;
        -- Filter gain.  This is the log2 of any extra gain applied to the
        -- result of the filter.  This will almost certainly need to be set to a
        -- negative number to compensate for extra gain on the filter taps.
        --
        -- Gain is defined by treating all of tap_i, data_i, data_o as fixed
        -- point numbers each scaled to the range +-1 (or more precisely a half
        -- open range [-1..+1) where the upper limit is 1-2^-(N-1) for an N bit
        -- signed number).
        FILTER_GAIN : integer := 0;
        -- The memory style for tap memories and for delays between filters can
        -- be forced here if desired
        TAPS_MEM_STYLE : string := "";
        DELAY_MEM_STYLE : string := "";
        -- If this flag is set the output will be saturated on overflow
        SATURATE_OUTPUT : boolean := false
    );
    port (
        clk_i : in std_ulogic;

        -- Tap coefficent writing
        start_write_i : in std_ulogic;      -- Resets write counters
        write_tap_i : in std_ulogic;        -- Write value into tap
        tap_i : in signed;                  -- Value to write into tap

        -- Input data
        last_i : in std_ulogic := '1';      -- Signals last channel of stream
        enable_i : in std_ulogic := '1';    -- Data input strobe
        data_i : in signed(DATA_WIDTH-1 downto 0);

        sync_i : in std_ulogic := '0';      -- Resets output stream

        -- Filtered data
        last_o : out std_ulogic;
        enable_o : out std_ulogic;
        data_o : out signed;
        overflow_o : out std_ulogic
    );
end;

architecture arch of poly_fir is
    signal last_in : std_ulogic := '0';
    signal enable_in : std_ulogic := '0';
    signal data_in : signed(DATA_WIDTH-1 downto 0) := (others => '0');

    subtype TAP_RANGE is natural range tap_i'RANGE;

    signal start_taps : std_ulogic;
    signal taps : signed_array(0 to TAP_COUNT-1)(TAP_RANGE);

    signal fir_out : signed(47 downto 0);

    signal enable_accum : std_ulogic;
    signal start_accum : std_ulogic;

    -- Process delay from data_i to data_o in dot_product
    constant FIR_PROCESS_DELAY : natural := 3;
    -- Delay from data_i to data_o in poly_fir_accum
    constant ACCUM_PROCESS_DELAY : natural := 2 + to_integer(SATURATE_OUTPUT);

begin
    -- Ensure that overflow in each individual filter cannot occur
    assert DATA_WIDTH + tap_i'LENGTH + bits(TAP_COUNT-1) <= fir_out'LENGTH
        report "Filter can overflow, total length: "
            & to_string(DATA_WIDTH + tap_i'LENGTH + bits(TAP_COUNT-1))
            & " > " & to_string(fir_out'LENGTH)
        severity failure;


    -- One stage of pipeline to ease timing pressure on input signals
    process (clk_i) begin
        if rising_edge(clk_i) then
            last_in <= last_i and enable_i;
            enable_in <= enable_i;
            data_in <= data_i;
        end if;
    end process;


    -- Tap storage, written in natural filter sequence, delivered in reversed
    -- polyphase order for natural filter operation.
    taps_bank : entity work.poly_fir_taps generic map (
        TAP_COUNT => TAP_COUNT,
        DECIMATION => DECIMATION,
        MEM_STYLE => TAPS_MEM_STYLE
    ) port map (
        clk_i => clk_i,

        start_write_i => start_write_i,
        write_tap_i => write_tap_i,
        tap_i => tap_i,

        enable_i => enable_in,
        next_i => last_in,
        last_i => start_taps,
        taps_o => taps
    );


    -- Core filter.  This applies the selected taps to all channels
    filter : entity work.poly_fir_core generic map (
        DATA_DELAY => DECIMATION * WAYS,
        PROCESS_DELAY => FIR_PROCESS_DELAY,
        MEM_STYLE => DELAY_MEM_STYLE,
        DATA_WIDTH => DATA_WIDTH
    ) port map (
        clk_i => clk_i,

        enable_i => enable_in,
        data_i => data_in,
        taps_i => taps,

        data_o => fir_out
    );


    -- Accumulate all the partial filters into a single result
    accum : entity work.poly_fir_accum generic map (
        WAYS => WAYS,
        INPUT_BITS => DATA_WIDTH + tap_i'LENGTH,
        INPUT_GAIN => DECIMATION * TAP_COUNT,
        FILTER_GAIN => FILTER_GAIN,
        PROCESS_DELAY => ACCUM_PROCESS_DELAY,
        SATURATE_OUTPUT => SATURATE_OUTPUT
    ) port map (
        clk_i => clk_i,

        start_i => start_accum,
        enable_i => enable_accum,
        data_i => fir_out,

        data_o => data_o,
        overflow_o => overflow_o
    );


    -- Detailed timing control for taps and accumulator, as well as output
    -- enables.
    control : entity work.poly_fir_control generic map (
        TAP_COUNT => TAP_COUNT,
        DECIMATION => DECIMATION,
        WAYS => WAYS,
        FIR_PROCESS_DELAY => FIR_PROCESS_DELAY,
        ACCUM_PROCESS_DELAY => ACCUM_PROCESS_DELAY
    ) port map (
        clk_i => clk_i,

        enable_i => enable_in,
        last_i => last_in,
        sync_i => sync_i,

        start_taps_o => start_taps,
        start_accum_o => start_accum,
        enable_accum_o => enable_accum,

        last_o => last_o,
        enable_o => enable_o
    );
end;
