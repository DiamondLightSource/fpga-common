-- Multiplex capture of streams to AXI

-- Multiplexes AXI bursts from an array of AXI write channels to a single write
-- channel.  Channels are selected for writing in priority order (with the
-- channel at index 0 taking highest priority), and the choice of which channel
-- to send next is made based on the address_valid flags.
--
-- Therefore, to use this efficiently, it is important that the entire data
-- burst is available to send by the time the address is presented.  This is
-- designed to work with capture_bursts which ensures this by buffering each
-- burst before generating the address.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.axi_defs.all;

entity axi_write_mux is
    generic (
        ADDRESS_WIDTH : natural;
        LOG_DATA_BYTES : natural;           -- log2 of data byte width
        MUX_CHANNEL_COUNT : natural;        -- Number of mux channels
        MAX_BURST_COUNT : natural := 2;     -- Number of requested bursts
        LOG_COMPLETION_COUNT : natural := 4 -- Number of outstanding completions
    );
    port (
        clk_i : in std_ulogic;

        -- Data to be written.  Presented as separate address, burst length, and
        -- data streams for each of the multiplexed channels
        mux_i : in axi_write_array_t(0 to MUX_CHANNEL_COUNT-1) (
            address(ADDRESS_WIDTH-1 downto LOG_DATA_BYTES),
            data(8 * 2**LOG_DATA_BYTES-1 downto 0));
        mux_o : out axi_write_ready_array_t(0 to MUX_CHANNEL_COUNT-1);

        -- Interface to AXI burst controller
        axi_o : out axi_write_t(
            address(ADDRESS_WIDTH-1 downto LOG_DATA_BYTES),
            data(8 * 2**LOG_DATA_BYTES - 1 downto 0));
        axi_i : in axi_write_ready_t;

        -- Write completion error from slave: unexpected write completion or
        -- missing write completion events.  Should never happen
        unexpected_completion_o : out std_ulogic := '0';
        missing_completion_o : out std_ulogic := '0'
    );
end;

architecture arch of axi_write_mux is
    constant DATA_WIDTH : natural := 8 * 2**LOG_DATA_BYTES;
    subtype DATA_SELECT_RANGE is
        natural range bits(MUX_CHANNEL_COUNT-1) downto 0;

    -- Decoded choice of next available input source
    signal mux_select_in_valid : std_ulogic := '0';
    signal mux_select_in : unsigned(DATA_SELECT_RANGE) := (others => '0');
    signal fifo_mux_select : unsigned(DATA_SELECT_RANGE);

    signal current_addr_mux : axi_o'SUBTYPE;
    signal ack_address_in : std_ulogic := '0';
    signal ack_address_delay : std_ulogic := '0';

    -- Selected channel is recorded in FIFO
    signal select_fifo_valid_in : std_ulogic := '0';
    signal select_fifo_ready_in : std_ulogic;

    -- Data completion for BRESP is also in FIFO, managed at same time as the
    -- selection FIFO
    signal completion_fifo_valid_in : std_ulogic := '0';
    signal completion_fifo_ready_in : std_ulogic;
    signal completion_fifo_valid_out : std_ulogic;
    signal completion_select : unsigned(DATA_SELECT_RANGE);

    -- Selected data channel to transmit
    signal select_fifo_valid_out : std_ulogic;
    signal data_select_out : unsigned(DATA_SELECT_RANGE);
    signal data_select : unsigned(DATA_SELECT_RANGE) := (others => '0');
    signal data_buffer_ready_early : std_ulogic;
    signal data_buffer_ready : std_ulogic;

    type data_state_t is (DATA_IDLE, DATA_START, DATA_RUNNING);
    signal data_state : data_state_t := DATA_IDLE;

    -- Intermediate buffers for data buffer input and output.
    signal current_data_mux : axi_o'SUBTYPE;
    signal buffer_data_in : std_ulogic_vector(DATA_WIDTH+1 downto 0);
    signal buffer_data_out : std_ulogic_vector(DATA_WIDTH+1 downto 0);


    -- -------------------------------------------------------------------------
    -- Output gathering: outputs are more easily managed as separate variables,
    -- and this avoids unpleasant surprises when assigning different fields of a
    -- structure from different processes.

    -- Outputs for mux_o.  Easier to manage as bit arrays
    signal mux_address_ready : std_ulogic_vector(0 to MUX_CHANNEL_COUNT-1)
        := (others => '0');
    signal mux_data_ready : std_ulogic_vector(0 to MUX_CHANNEL_COUNT-1)
        := (others => '0');
    signal mux_write_complete : std_ulogic_vector(0 to MUX_CHANNEL_COUNT-1)
        := (others => '0');

    -- Outputs for axi_o.  These are gathered into axi_o at the bottom.
    signal axi_address_valid : std_ulogic := '0';
    signal axi_address : unsigned(ADDRESS_WIDTH-1 downto LOG_DATA_BYTES);
    signal axi_burst_length : unsigned(7 downto 0);
    signal axi_data_valid : std_ulogic;
    signal axi_data_last : std_ulogic;
    signal axi_data : std_ulogic_vector(8 * 2**LOG_DATA_BYTES - 1 downto 0);
    signal axi_data_enable : std_ulogic;

begin
    -- Aliases for the selected views of the appropriate selected incoming
    -- address and data sources.
    current_addr_mux <= mux_i(to_integer(mux_select_in));
    current_data_mux <= mux_i(to_integer(data_select));


    -- FIFO for multiplexer inputs: records which mux inputs have had their
    -- corresponding burst parameters set and need to process data.  Only the
    -- selection needs to be recorded.
    select_fifo : entity work.simple_fifo generic map (
        FIFO_DEPTH => MAX_BURST_COUNT,
        DATA_WIDTH => mux_select_in'LENGTH
    ) port map (
        clk_i => clk_i,

        write_valid_i => select_fifo_valid_in,
        write_ready_o => select_fifo_ready_in,
        write_data_i => std_ulogic_vector(fifo_mux_select),

        read_valid_o => select_fifo_valid_out,
        read_ready_i => to_std_ulogic(data_state = DATA_IDLE),
        unsigned(read_data_o) => data_select_out
    );

    -- FIFO for write completion responses, keeps track of which channel is
    -- expecting the next write complete response
    completion_fifo : entity work.fifo generic map (
        FIFO_BITS => LOG_COMPLETION_COUNT,
        DATA_WIDTH => mux_select_in'LENGTH
    ) port map (
        clk_i => clk_i,

        write_valid_i => completion_fifo_valid_in,
        write_ready_o => completion_fifo_ready_in,
        write_data_i => std_ulogic_vector(fifo_mux_select),

        read_valid_o => completion_fifo_valid_out,
        read_ready_i => axi_i.write_complete,
        unsigned(read_data_o) => completion_select
    );


    -- Data output buffer.  We need to use a two stage buffer to ensure bubble
    -- free operation and yet allow for slave flow control
    data_buffer : entity work.simple_fifo generic map (
        FIFO_DEPTH => 2,
        DATA_WIDTH => DATA_WIDTH + 2
    ) port map (
        clk_i => clk_i,

        write_valid_i =>
            current_data_mux.data_valid and
            to_std_ulogic(data_state = DATA_RUNNING),
        write_ready_early_o => data_buffer_ready_early,
        write_ready_o => data_buffer_ready,
        write_data_i => buffer_data_in,

        read_valid_o => axi_data_valid,
        read_ready_i => axi_i.data_ready,
        read_data_o => buffer_data_out
    );
    -- Because of brain damage in the definition of VHDL we have to do these
    -- associations *outside* the entity assignment above.  Just because.
    -- It's in the standard, apparently.  Allegedly this would work if
    -- DATA_WIDTH was a project wide constant!  I am lost for words...
    buffer_data_in(DATA_WIDTH-1 downto 0) <= current_data_mux.data;
    buffer_data_in(DATA_WIDTH) <= current_data_mux.data_last;
    buffer_data_in(DATA_WIDTH+1) <= current_data_mux.data_enable;
    axi_data <= buffer_data_out(DATA_WIDTH-1 downto 0);
    axi_data_last <= buffer_data_out(DATA_WIDTH);
    axi_data_enable <= buffer_data_out(DATA_WIDTH+1);


    -- Address output and input source selection
    process (clk_i)
        -- Computes index of next available input ready signal
        procedure find_next_ready(
            signal found : out std_ulogic;
            signal data_select : out unsigned;
            mux : axi_write_array_t) is
        begin
            for i in 0 to MUX_CHANNEL_COUNT-1 loop
                if mux(i).address_valid then
                    found <= '1';
                    data_select <= to_unsigned(i, data_select'LENGTH);
                    return;
                end if;
            end loop;
            found <= '0';
        end;

        variable select_fifo_ready : std_ulogic;
        variable axi_address_ready : std_ulogic;
        variable taking_address : std_ulogic;

    begin
        if rising_edge(clk_i) then
            -- Select FIFO is ready if it's not blocked with untaken data
            select_fifo_ready :=
                not select_fifo_valid_in or select_fifo_ready_in;
            -- Similarly, the AXI output is ready if not blocked
            axi_address_ready := not axi_address_valid or axi_i.address_ready;
            -- We are ready to take a new address if the following conditions
            -- all hold:
            taking_address :=
                -- Ensure that any previous address has been fully acknowledged.
                not ack_address_in and not ack_address_delay and
                -- Select and completion FIFOs can take data
                select_fifo_ready and
                -- Ensure any previous output address has been taken
                axi_address_ready and
                -- We have an incoming address to process
                mux_select_in_valid;

            -- We register the selected mux address to avoid overly complex
            -- combinatorial paths.  Unfortunately this adds a extra delay to
            -- detecting the next valid input.
            find_next_ready(mux_select_in_valid, mux_select_in, mux_i);

            if taking_address then
                axi_address_valid <= '1';
                axi_address <= current_addr_mux.address;
                axi_burst_length <= current_addr_mux.burst_length;
                select_fifo_valid_in <= '1';
                completion_fifo_valid_in <= '1';
                fifo_mux_select <= mux_select_in;
            else
                if axi_i.address_ready then
                    axi_address_valid <= '0';
                end if;
                if select_fifo_ready_in then
                    select_fifo_valid_in <= '0';
                end if;
                completion_fifo_valid_in <= '0';
            end if;

            compute_strobe(
                mux_address_ready, to_integer(mux_select_in), taking_address);
            compute_strobe(
                mux_write_complete, to_integer(completion_select),
                axi_i.write_complete and completion_fifo_valid_out);

            -- Check for the unexpected completion protocol errors
            --
            -- Completion received when none expected
            unexpected_completion_o <=
                axi_i.write_complete and not completion_fifo_valid_out;
            -- If more than 16 outstanding completions we'll lose track of
            -- further completions
            missing_completion_o <=
               completion_fifo_valid_in and not completion_fifo_ready_in;

            ack_address_in <= taking_address;
            ack_address_delay <= ack_address_in;
        end if;
    end process;


    -- Data capture
    process (clk_i)
        variable last_processed : std_ulogic;

    begin
        if rising_edge(clk_i) then
            -- When last is accepted by the skip buffer we need to stop taking
            -- data from this source.
            last_processed := current_data_mux.data_last and data_buffer_ready;

            -- Data capture state control
            case data_state is
                when DATA_IDLE =>
                    if select_fifo_valid_out then
                        data_select <= data_select_out;
                        data_state <= DATA_START;
                    end if;
                when DATA_START =>
                    data_state <= DATA_RUNNING;
                when DATA_RUNNING =>
                    -- Need to wait for final data write to complete
                    if last_processed then
                        data_state <= DATA_IDLE;
                    end if;
            end case;

            -- Wire ready to selected source.  This uses the early version of
            -- the data buffer ready flag, and we need to ensure we go false as
            -- soon as last has been processed by the data FIFO.
            compute_strobe(
                mux_data_ready, to_integer(data_select),
                -- While we're running (and during the first startup tick) we
                -- ensure that the skip buffer's ready signal is registered to
                -- the appropriate source.  We stop taking data as soon as last
                -- has been registered into the skip buffer.
                to_std_ulogic(
                    data_state = DATA_START or data_state = DATA_RUNNING) and
                data_buffer_ready_early and not last_processed);
        end if;
    end process;


    validate : entity work.axi_write_validate port map (
        clk_i => clk_i,
        axi_i => axi_o,
        axi_ready_i => axi_i
    );


    -- Assign mux_o array
    gen_mux_o : for i in 0 to MUX_CHANNEL_COUNT-1 generate
        mux_o(i) <= (
            address_ready => mux_address_ready(i),
            data_ready => mux_data_ready(i),
            write_complete => mux_write_complete(i)
        );
    end generate;

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
