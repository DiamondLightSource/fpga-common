-- Converts stream to sequence of bursts
--
-- This is designed to capture a fast stream without data bubbles

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.axi_defs.all;

entity stream_capture_fast_stream is
    generic (
        ADDRESS_WIDTH : natural;
        LOG_DATA_BYTES : natural;           -- log2 of data byte width
        LOG_BURST_LENGTH : natural;         -- log2 of burst length
        MAX_BURST_COUNT : natural := 2      -- Number of requested bursts
    );
    port (
        clk_i : in std_ulogic;

        -- Data to be written.
        data_valid_i : in std_ulogic := '1';
        data_i : in std_ulogic_vector(8 * 2**LOG_DATA_BYTES - 1 downto 0);

        -- Interface to AXI burst controller
        axi_o : out axi_write_t(
            address(ADDRESS_WIDTH-1 downto LOG_DATA_BYTES),
            data(8 * 2**LOG_DATA_BYTES - 1 downto 0));
        axi_i : in axi_write_ready_t;


        -- Control interface.
        --
        -- During operation this controller is in one of four states, both
        -- controlled and reflected by these two signals:
        --                   _______________________
        -- enable_i ________/                       \_____________________
        --                               _______________________
        -- ready_o  ____________________/                       \_________
        --                  :           :           :           :
        --          IDLE    | STARTING  | RUNNING   | ENDING    | IDLE
        --
        -- data_i and data_valid_i are ignored except during the READY period.
        -- It is a protocol error with unpredictable results to change the state
        -- of enable_i when the controller is not IDLE or RUNNING.
        capture_enable_i : in std_ulogic;
        capture_ready_o : out std_ulogic;

        -- Range of capture addresses.  This is specified in multiples of burst
        -- length as capture is recorded in bursts
        first_address_i : in
            unsigned(ADDRESS_WIDTH-1 downto LOG_BURST_LENGTH+LOG_DATA_BYTES);
        last_address_i : in
            unsigned(ADDRESS_WIDTH-1 downto LOG_BURST_LENGTH+LOG_DATA_BYTES);

        -- This is the address of the currently written data word.
        capture_address_o : out
            unsigned(ADDRESS_WIDTH-1 downto LOG_DATA_BYTES);

        -- Set when data cannot be sent
        data_error_o : out std_ulogic
    );
end;

architecture arch of stream_capture_fast_stream is
    constant LOW_BURST_ADDRESS_BIT : natural
        := LOG_BURST_LENGTH + LOG_DATA_BYTES;

    type state_t is (IDLE, STARTING, RUNNING, ENDING);
    signal state : state_t := IDLE;

    -- Address computation control
    -- Next burst address to send
    signal burst_address :
        unsigned(ADDRESS_WIDTH-1 downto LOW_BURST_ADDRESS_BIT);

    -- Count of unresolved burst addresses sent or being sent
    signal burst_count : natural range 0 to MAX_BURST_COUNT := 0;
    -- Number of data beats remaining to send in this burst
    signal data_counter : unsigned(LOG_BURST_LENGTH-1 downto 0)
        := (others => '0');

    -- Capture address in two parts
    signal capture_address_low :
        unsigned(LOW_BURST_ADDRESS_BIT-1 downto LOG_DATA_BYTES);
    signal capture_address_high :
        unsigned(ADDRESS_WIDTH-1 downto LOW_BURST_ADDRESS_BIT);

    -- Outputs for axi_o.  These are gathered into axi_o at the bottom.
    signal axi_address_valid : std_ulogic := '0';
    signal axi_address : unsigned(ADDRESS_WIDTH-1 downto LOG_DATA_BYTES);
    signal axi_burst_length : unsigned(7 downto 0);
    signal axi_data_valid : std_ulogic := '0';
    signal axi_data_last : std_ulogic := '0';
    signal axi_data : std_ulogic_vector(8 * 2**LOG_DATA_BYTES - 1 downto 0);
    signal axi_data_enable : std_ulogic := '0';

    -- Combinatorial assignments
    signal data_complete_l : boolean;
    signal next_address_valid_l : boolean;
    signal next_address_not_busy_l : boolean;
    signal next_data_not_busy_l : boolean;
    signal next_data_valid_l : boolean;
    signal increment_burst_count_l : boolean;
    signal decrement_burst_count_l : boolean;

begin
    -- Ensure bursts cannot cross 4KB boundary
    assert LOG_BURST_LENGTH + LOG_DATA_BYTES <= 12
        report "Burst length too long: " &
            to_string(LOG_BURST_LENGTH + LOG_DATA_BYTES)
        severity failure;

    axi_address <= burst_address & to_unsigned(0, LOG_BURST_LENGTH);
    axi_burst_length <= to_unsigned(2**LOG_BURST_LENGTH-1, 8);

    capture_ready_o <= to_std_ulogic(state = RUNNING or state = ENDING);
    capture_address_o <= capture_address_high & capture_address_low;


    -- Each burst is complete when the last data for the burst is ready and has
    -- been taken.
    data_complete_l <=
        axi_data_valid = '1' and axi_data_last = '1' and
        axi_i.data_ready = '1';

    -- Compute behaviour for address and counter advance.  This will be
    -- registered into axi_address_valid and maintained until ready_i.
    with state select
        next_address_valid_l <=
            -- On transition to STARTING generate an address
            capture_enable_i = '1'          when IDLE,
            -- During normal operation keep the burst queue filled
            burst_count < MAX_BURST_COUNT   when STARTING | RUNNING,
            -- No address generation on runout
            false   when ENDING;

    -- Outputs are ready for a new value when idle or previous value taken
    next_address_not_busy_l <=
        axi_address_valid = '0' or axi_i.address_ready = '1';
    next_data_not_busy_l <=
        axi_data_valid = '0' or axi_i.data_ready = '1';

    -- Send data as required during normal operation, send continuously until
    -- done while ending.
    with state select
        next_data_valid_l <=
            data_valid_i = '1' and capture_enable_i = '1'   when RUNNING,
            true    when ENDING,
            false   when IDLE | STARTING;

    -- Compute increment and decrements
    increment_burst_count_l <= next_address_not_busy_l and next_address_valid_l;
    decrement_burst_count_l <= data_complete_l;


    process (clk_i) begin
        if rising_edge(clk_i) then
            -- State control
            case state is
                when IDLE =>
                    if capture_enable_i then
                        state <= STARTING;
                    end if;
                when STARTING =>
                    -- In this application we can safely expect wdready_i to go
                    -- high before sending data; this is required for bubble
                    -- free data transfer.
                    if axi_i.data_ready then
                        state <= RUNNING;
                    end if;
                when RUNNING =>
                    if not capture_enable_i then
                        state <= ENDING;
                    end if;
                when ENDING =>
                    -- If we're about to send the last padding value then we
                    -- can go idle.
                    if burst_count = 1 and data_counter = 1 then
                        state <= IDLE;
                    end if;
            end case;

            -- Update address out when possible
            if next_address_not_busy_l then
                if next_address_valid_l then
                    if state = IDLE or burst_address = last_address_i then
                        burst_address <= first_address_i;
                    else
                        burst_address <= burst_address + 1;
                    end if;
                end if;
                axi_address_valid <= to_std_ulogic(next_address_valid_l);
            end if;

            -- Update data out when possible
            if next_data_not_busy_l then
                axi_data_valid <= to_std_ulogic(next_data_valid_l);
                axi_data_enable <= to_std_ulogic(state = RUNNING);
                axi_data <= data_i;
                axi_data_last <=
                    to_std_ulogic(data_counter = 1 and next_data_valid_l);
            end if;


            -- Keep count of number of bursts transmitted or being transmitted
            -- to AXI slave and not yet completed.
            if increment_burst_count_l and not decrement_burst_count_l then
                burst_count <= burst_count + 1;
            elsif not increment_burst_count_l and decrement_burst_count_l then
                burst_count <= burst_count - 1;
            end if;

            -- Count off data words presented for transmission
            if next_data_not_busy_l and next_data_valid_l then
                data_counter <= data_counter - 1;
            end if;


            -- Detect data output overrun if incoming data and data not taken
            if state = RUNNING then
                data_error_o <=
                    data_valid_i and axi_data_valid and not axi_i.data_ready;
            else
                data_error_o <= '0';
            end if;

            -- Keep the capture address in step with the captured data
            if state = IDLE and capture_enable_i = '1' then
                capture_address_low <= (others => '0');
                capture_address_high <= first_address_i;
            elsif state = RUNNING and next_data_valid_l then
                capture_address_low <= capture_address_low + 1;
                if capture_address_low + 1 = 0 then
                    if capture_address_high = last_address_i then
                        capture_address_high <= first_address_i;
                    else
                        capture_address_high <= capture_address_high + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;


    -- We need to assign axi_o in a single process, so we do it here.
    axi_o <= (
        address_valid => axi_address_valid,
        address => axi_address,
        burst_length => axi_burst_length,
        data_valid => axi_data_valid,
        data_last => axi_data_last,
        data => axi_data,
        data_enable => axi_data_enable
    );
end;
