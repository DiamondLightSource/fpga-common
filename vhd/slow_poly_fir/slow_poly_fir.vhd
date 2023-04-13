-- Multi-channel polyphase FIR for slow streams

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity slow_poly_fir is
    generic (
        -- Number of taps in each bank of the filter
        -- This is a confusing name, as it is more accurately the overlap count
        -- and the true number of taps is the product OVERLAPS*DECIMATION
        OVERLAPS : natural;
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
        -- The memory style for tap memories can be forced here if desired
        TAPS_MEM_STYLE : string := ""
    );
    port (
        clk_i : in std_ulogic;

        -- Tap coefficent writing
        start_write_i : in std_ulogic;      -- Resets write counters
        write_tap_i : in std_ulogic;        -- Write value into tap
        tap_i : in signed;                  -- Value to write into tap

        -- Input data
        enable_i : in std_ulogic := '1';    -- Data input strobe
        last_i : in std_ulogic := '1';      -- Signals last channel of stream
        data_i : in signed(DATA_WIDTH-1 downto 0);

        sync_i : in std_ulogic := '0';      -- Resets output stream

        -- Filtered data
        last_o : out std_ulogic;
        enable_o : out std_ulogic;
        data_o : out signed;
        overflow_o : out std_ulogic
    );
end;

architecture arch of slow_poly_fir is
    -- Input FIFO
    signal data_fifo_in : std_ulogic_vector(DATA_WIDTH downto 0);
    signal data_fifo_out : std_ulogic_vector(DATA_WIDTH downto 0);
    signal fifo_write_ready : std_ulogic;
    signal data_valid : std_ulogic;
    signal data_ready : std_ulogic;
    signal data_in : signed(DATA_WIDTH-1 downto 0);
    signal last_in : std_ulogic;

    -- Taps interfacing
    constant TAPS_READ_DELAY : natural := 1;
    constant TAPS_COUNT : natural := OVERLAPS * DECIMATION;
    constant TAP_ADDRESS_WIDTH : natural := bits(TAPS_COUNT-1);
    constant TAP_WIDTH : natural := tap_i'LENGTH;
    signal tap_address : unsigned(TAP_ADDRESS_WIDTH-1 downto 0);
    signal current_tap : signed(TAP_WIDTH-1 downto 0);

    -- Accumulator
    constant ACCUM_COUNT : natural := OVERLAPS * WAYS;
    constant ACCUM_ADDRESS_WIDTH : natural := bits(ACCUM_COUNT-1);
    signal accum_address : unsigned(ACCUM_ADDRESS_WIDTH-1 downto 0);
    signal accum_end : std_ulogic;

begin
    gen_fifo : if WAYS > 3 generate
        -- Data will arrive in a burst of updates.  This needs to be buffered
        data_fifo : entity work.fifo generic map (
            FIFO_BITS => bits(WAYS - 1),
            DATA_WIDTH => DATA_WIDTH + 1
        ) port map (
            clk_i => clk_i,

            write_ready_o => fifo_write_ready,
            write_valid_i => enable_i,
            write_data_i => data_fifo_in,

            read_valid_o => data_valid,
            read_ready_i => data_ready,
            read_data_o => data_fifo_out
        );
    else generate
        -- For single channel use a simple FIFO to keep the data valid
        data_fifo : entity work.simple_fifo generic map (
            FIFO_DEPTH => WAYS,
            DATA_WIDTH => DATA_WIDTH + 1
        ) port map (
            clk_i => clk_i,

            write_ready_o => fifo_write_ready,
            write_valid_i => enable_i,
            write_data_i => data_fifo_in,

            read_valid_o => data_valid,
            read_ready_i => data_ready,
            read_data_o => data_fifo_out
        );
    end generate;
    data_fifo_in(DATA_WIDTH-1 downto 0) <= std_ulogic_vector(data_i);
    data_fifo_in(DATA_WIDTH) <= last_i;
    data_in <= signed(data_fifo_out(DATA_WIDTH-1 downto 0));
    last_in <= data_fifo_out(DATA_WIDTH);

    -- Only meaningful for simulation: check that fifo never overflows
    -- Note that we can't compare these values directly with the desired value,
    -- as during the very first tick of simulation both these signals will be
    -- set to 'U', triggering failure!  This test was originally written as
    --      assert fifo_write_ready or not enable_i
    assert fifo_write_ready /= '0' or enable_i /= '1'
        report "FIFO overflow"
        severity failure;


    -- Taps
    taps : entity work.slow_poly_fir_taps generic map (
        READ_DELAY => TAPS_READ_DELAY,
        MEM_STYLE => TAPS_MEM_STYLE
    ) port map (
        clk_i => clk_i,

        start_write_i => start_write_i,
        write_tap_i => write_tap_i,
        tap_i => tap_i,

        tap_address_i => tap_address,
        tap_o => current_tap
    );


    -- Accumulator and output
    accum : entity work.slow_poly_fir_accum generic map (
        FILTER_GAIN => FILTER_GAIN
    ) port map (
        clk_i => clk_i,

        -- Incoming data from FIFO
        valid_i => data_valid,
        last_i => last_in,
        data_i => data_in,

        -- Generated output data from filter
        enable_o => enable_o,
        last_o => last_o,
        data_o => data_o,
        overflow_o => overflow_o,

        -- Current tap, one tick later than all other inputs
        tap_i => current_tap,

        -- Accumulator control
        accum_address_i => accum_address,
        accum_end_i => accum_end
    );


    -- Control
    control : entity work.slow_poly_fir_control generic map (
        DECIMATION => DECIMATION,
        OVERLAPS => OVERLAPS,
        WAYS => WAYS
    ) port map (
        clk_i => clk_i,

        -- FIFO handshake
        valid_i => data_valid,
        last_i => last_in,
        ready_o => data_ready,

        sync_i => sync_i,

        -- Taps control
        tap_address_o => tap_address,

        -- Accumulator control
        accum_address_o => accum_address,
        accum_end_o => accum_end
    );
end;
