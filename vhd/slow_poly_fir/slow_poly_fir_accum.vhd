-- Accumulator for slow polyphase FIR

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity slow_poly_fir_accum is
    generic (
        FILTER_GAIN : integer           -- Desired gain factor (negative)
    );

    port (
        clk_i : in std_ulogic;

        -- Incoming data from FIFO
        valid_i : in std_ulogic;        -- Valid data in
        last_i : in std_ulogic;         -- Last sample in burst
        data_i : in signed;             -- Data to filter

        -- Generated output data from filter
        enable_o : out std_ulogic := '0'; -- Valid data out
        last_o : out std_ulogic := '0'; -- Last sample in burst
        data_o : out signed;            -- Filtered and decimated data
        overflow_o : out std_ulogic;    -- Overflow in this sample

        -- Current tap, one tick later than all other inputs
        tap_i : in signed;

        -- Accumulator control
        accum_address_i : in unsigned;  -- Current accumulator to update
        accum_end_i : in std_ulogic     -- Last update for this round of filter
    );
end;

architecture arch of slow_poly_fir_accum is
    -- We're using hard-wired resources for the accumulator, so fix this here
    constant ACCUM_WIDTH : natural := 48;

    -- Accumulator data and control
    constant ADDR_WIDTH : natural := accum_address_i'LENGTH;
    signal write_enable : std_ulogic := '0';
    signal write_address : unsigned(ADDR_WIDTH-1 downto 0);
    signal accum_write_data : std_ulogic_vector(ACCUM_WIDTH downto 0);
    signal read_address : unsigned(ADDR_WIDTH-1 downto 0);
    signal accum_read_data : std_ulogic_vector(ACCUM_WIDTH downto 0);
    signal write_data : signed(ACCUM_WIDTH-1 downto 0);
    signal write_overflow : std_ulogic;
    signal read_data : signed(ACCUM_WIDTH-1 downto 0);
    signal read_overflow : std_ulogic;

    -- Multiply accumulator core
    signal data_in : data_i'SUBTYPE;
    signal accum_data : signed(ACCUM_WIDTH-1 downto 0);
    signal accum_overflow : std_ulogic;

    -- Control delay line
    signal delay_data_in : std_ulogic_vector(ADDR_WIDTH+2 downto 0);
    signal delay_data_out : std_ulogic_vector(ADDR_WIDTH+2 downto 0);
    signal valid_in : std_ulogic;
    signal last_in : std_ulogic;
    signal accum_end_in : std_ulogic;

    -- Computation of scaling and output range
    constant TOP_RESULT_BIT : natural :=
        data_i'LENGTH + tap_i'LENGTH - 2 - FILTER_GAIN;
    subtype OUTPUT_RANGE is natural
        range TOP_RESULT_BIT downto TOP_RESULT_BIT - data_o'LENGTH + 1;
    constant ROUNDING_BIT : signed(ACCUM_WIDTH-1 downto 0) := (
        OUTPUT_RANGE'RIGHT-1 => '1',
        others => '0');

    -- Delay alignment
    constant MAC_PROCESS_DELAY : natural := 3;  -- From data in to data out
    constant MAC_ACCUM_DELAY : natural := 2;    -- From accum in to data out
    constant ACCUM_READ_DELAY : natural := 1;   -- read address delay

    constant ACCUM_UPDATE_DELAY : natural :=
        MAC_PROCESS_DELAY + ACCUM_READ_DELAY;

begin
    accum : entity work.memory_array generic map (
        ADDR_BITS => accum_address_i'LENGTH,
        DATA_BITS => ACCUM_WIDTH + 1,
        READ_DELAY => ACCUM_READ_DELAY
    ) port map (
        clk_i => clk_i,

        write_strobe_i => write_enable,
        write_addr_i => write_address,
        write_data_i => accum_write_data,

        read_addr_i => read_address,
        read_data_o => accum_read_data
    );
    accum_write_data(ACCUM_WIDTH-1 downto 0) <= std_ulogic_vector(write_data);
    accum_write_data(ACCUM_WIDTH) <= write_overflow;
    read_data <= signed(accum_read_data(ACCUM_WIDTH-1 downto 0));
    read_overflow <= accum_read_data(ACCUM_WIDTH);


    mac : entity work.slow_poly_fir_mac generic map (
        TOP_RESULT_BIT => OUTPUT_RANGE'LEFT,
        PROCESS_DELAY => MAC_PROCESS_DELAY,
        ACCUM_DELAY => MAC_ACCUM_DELAY
    ) port map (
        clk_i => clk_i,

        data_i => data_in,
        tap_i => tap_i,

        accum_i => read_data,
        overflow_i => read_overflow,

        accum_o => accum_data,
        overflow_o => accum_overflow
    );


    -- Delay address and data enable for write-back to accumulator
    delay : entity work.fixed_delay generic map (
        WIDTH => ADDR_WIDTH + 3,
        DELAY => ACCUM_UPDATE_DELAY
    ) port map (
        clk_i => clk_i,
        data_i => delay_data_in,
        data_o => delay_data_out
    );
    delay_data_in(ADDR_WIDTH-1 downto 0) <= std_ulogic_vector(read_address);
    delay_data_in(ADDR_WIDTH) <= valid_i;
    delay_data_in(ADDR_WIDTH + 1) <= last_i;
    delay_data_in(ADDR_WIDTH + 2) <= accum_end_i and valid_i;
    write_address <= unsigned(delay_data_out(ADDR_WIDTH-1 downto 0));
    valid_in <= delay_data_out(ADDR_WIDTH);
    last_in <= delay_data_out(ADDR_WIDTH + 1);
    accum_end_in <= delay_data_out(ADDR_WIDTH + 2);


    process (clk_i) begin
        if rising_edge(clk_i) then
            -- One tick delay on data to align with delay on tap lookup
            data_in <= data_i;
            -- One tick delay on address in to account for delay skew between
            -- data and tap, and accumulator
            read_address <= accum_address_i;
            write_enable <= valid_in;

            -- Register data and overflow for output and writing to accumulator
            if accum_end_in then
                write_data <= ROUNDING_BIT;
                write_overflow <= '0';
            else
                write_data <= accum_data;
                write_overflow <= accum_overflow;
            end if;

            -- Outputs
            if valid_in and accum_end_in then
                data_o <= accum_data(OUTPUT_RANGE);
                overflow_o <= accum_overflow;
                enable_o <= '1';
                last_o <= last_in;
            else
                enable_o <= '0';
                last_o <= '0';
            end if;
        end if;
    end process;
end;
