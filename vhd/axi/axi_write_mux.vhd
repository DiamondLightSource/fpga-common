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
        LOG_REQUEST_QUEUE : natural := 3;   -- Depth of request FIFO
        LOG_COMPLETION_QUEUE : natural := 5 -- Number of outstanding completions
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
    subtype DATA_SELECT_RANGE is
        natural range bits(MUX_CHANNEL_COUNT - 1) downto 0;

    signal mux_select_in : unsigned(DATA_SELECT_RANGE);
    signal mux_select_valid : std_ulogic := '0';

    signal data_fifo_write_ready : std_ulogic;
    signal data_fifo_read_valid : std_ulogic;
    signal data_fifo_read_ready : std_ulogic := '0';
    signal data_mux_next : unsigned(DATA_SELECT_RANGE);
    signal data_mux_select : unsigned(DATA_SELECT_RANGE);
    signal data_mux_valid : std_ulogic := '0';

    signal completion_fifo_write_ready : std_ulogic;
    signal completion_select : unsigned(DATA_SELECT_RANGE);
    signal completion_valid : std_ulogic := '0';


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
    signal axi_data_valid : std_ulogic := '0';
    signal axi_data_last : std_ulogic;
    signal axi_data : std_ulogic_vector(8 * 2**LOG_DATA_BYTES - 1 downto 0);
    signal axi_data_enable : std_ulogic;

    -- Skid buffer for output data
    signal skid_data_valid : std_ulogic := '0';
    signal skid_data_last : std_ulogic;
    signal skid_data : std_ulogic_vector(8 * 2**LOG_DATA_BYTES - 1 downto 0);
    signal skid_data_enable : std_ulogic;


begin
    -- The implementation consists of the following elements:
    --
    --  * Address dispatch.  The highest priority available address request is
    --    forwarded to the AXI output and the selected channel is simultaneously
    --    written to a data FIFO and a completion FIFO.  This requires blocking
    --    until all three destinations are available.
    --  * Data dispatch.  Channels to forward are read in turn from the data
    --    FIFO and one burst from that channel is forwarded.
    --  * Completion dispatch.  Each completion is forwarded in turn to the
    --    channnel.

    -- FIFO for data bursts, keeps track of which channel to send next.  We will
    -- rely on correct framing to manage the burst length!
    data_fifo : entity work.fifo generic map (
        FIFO_BITS => LOG_REQUEST_QUEUE,
        DATA_WIDTH => mux_select_in'LENGTH
    ) port map (
        clk_i => clk_i,

        write_valid_i => mux_select_valid,
        write_ready_o => data_fifo_write_ready,
        write_data_i => std_ulogic_vector(mux_select_in),

        read_valid_o => data_fifo_read_valid,
        read_ready_i => data_fifo_read_ready,
        unsigned(read_data_o) => data_mux_next
    );


    -- FIFO for write completion responses, keeps track of which channel is
    -- expecting the next write complete response
    completion_fifo : entity work.fifo generic map (
        FIFO_BITS => LOG_COMPLETION_QUEUE,
        DATA_WIDTH => mux_select_in'LENGTH
    ) port map (
        clk_i => clk_i,

        write_valid_i => mux_select_valid,
        write_ready_o => completion_fifo_write_ready,
        write_data_i => std_ulogic_vector(mux_select_in),

        read_valid_o => completion_valid,
        read_ready_i => axi_i.write_complete,
        unsigned(read_data_o) => completion_select
    );


    process (clk_i)
        -- Computes index of next available input ready signal.  Lowest numbered
        -- index takes priority
        procedure find_next_ready(
            variable mux_select : out natural;
            variable found : out std_ulogic) is
        begin
            for i in 0 to MUX_CHANNEL_COUNT-1 loop
                -- Look for incoming addresses that we haven't acknowledged yet
                if mux_i(i).address_valid then
                    found := '1';
                    mux_select := i;
                    return;
                end if;
            end loop;
            found := '0';
        end;


        -- Update the outgoing address using a simple "ping-pong" buffer
        procedure update_address_out(
            mux_select : natural; address_valid : std_ulogic) is
        begin
            if axi_address_valid then
                axi_address_valid <= not axi_i.address_ready;
            else
                axi_address_valid <= address_valid;
                axi_address <= mux_i(mux_select).address;
                axi_burst_length <= mux_i(mux_select).burst_length;
            end if;
        end;


        -- Process incoming address.  Ensure we can write the address to the AXI
        -- master port and can write the mux selection to the data and
        -- completion queues.
        procedure process_address is
            variable mux_select : natural;
            variable mux_ix : natural;
            variable address_found : std_ulogic;
            variable address_valid : std_ulogic;

        begin
            -- Update priority selection.  Only allow selection to proceed if
            -- all three destinations are ready.
            find_next_ready(mux_select, address_found);
            address_valid :=
                -- Check incoming address found
                address_found and
                -- Check no outstanding address out
                not axi_address_valid and
                -- Check for room in our data and completion queues
                data_fifo_write_ready and completion_fifo_write_ready;

            -- Acknowleged the selected address
            compute_strobe(mux_address_ready, mux_select, address_valid);

            -- Write selection to data and completion FIFOs
            mux_select_in <= to_unsigned(mux_select, mux_select_in'LENGTH);
            mux_select_valid <= address_valid;

            -- Write address to AXI slave
            update_address_out(mux_select, address_valid);

            -- If we miss a completion eventually the completion FIFO will fill
            -- and we'll stop accepting writes.
            missing_completion_o <=
                address_found and not completion_fifo_write_ready;
        end;


        -- Updates the AXI data out buffer via a skid buffer so we can properly
        -- manage our flow control.
        --   The flag data_out_ready record whether this buffer will be ready to
        -- take data on the next tick
        procedure update_data_out(
            mux_select : natural;
            data_out_valid : std_ulogic;
            variable data_out_ready : out std_ulogic) is
        begin
            -- Manage the output buffer
            if axi_i.data_ready or not axi_data_valid then
                -- In this state we can update the output buffer, use incoming
                -- data or the skid buffer as appropriate.  We will be ready
                -- for more data on the next tick.
                if skid_data_valid then
                    skid_data_valid <= '0';
                    axi_data_valid <= '1';
                    axi_data_last <= skid_data_last;
                    axi_data_enable <= skid_data_enable;
                    axi_data <= skid_data;
                else
                    axi_data_valid <= data_out_valid;
                    axi_data_last <= mux_i(mux_select).data_last;
                    axi_data_enable <= mux_i(mux_select).data_enable;
                    axi_data <= mux_i(mux_select).data;
                end if;
                data_out_ready := '1';
            elsif axi_data_valid and data_out_valid then
                -- Can't put the data in the output buffer so put it in the
                -- skid buffer instead.  We are not ready for more data.
                skid_data_valid <= '1';
                skid_data_last <= mux_i(mux_select).data_last;
                skid_data_enable <= mux_i(mux_select).data_enable;
                skid_data <= mux_i(mux_select).data;
                data_out_ready := '0';

                -- The data_out_ready flag is designed to specifically avoid
                -- this case.  If the skid buffer is already full then we will
                -- be losing data here.
                assert not skid_data_valid severity failure;
            else
                -- We can accept data so long as the skid buffer is empty
                data_out_ready := not skid_data_valid;
            end if;
        end;


        procedure update_data_mux_select(
            next_mux_valid : std_ulogic; load_next : std_ulogic) is
        begin
            if load_next or not data_mux_valid then
                data_mux_select <= data_mux_next;
                data_mux_valid <= next_mux_valid;
                data_fifo_read_ready <= next_mux_valid;
            else
                data_fifo_read_ready <= '0';
            end if;
        end;


        -- Data forwarding is surprisingly delicate.  Data needs to be forwarded
        -- without bubbles, so the flow is a bit tricky.  This processing has
        -- the following three steps:
        --  * Update the AXI output buffer.  This is a skid buffer to allow us
        --    to know in advance whether data can be taken on the next tick.
        --  * Use the status flag from the output buffer to update the data
        --    ready flag for the next beat.  At this point we may need to switch
        --    to the next available channel.
        --  * Advance the channel selection if appropriate.  The channel
        --    selection is double buffered to help with advancing the data ready
        --    flag at the end of each burst.
        procedure process_data is
            variable next_mux_valid : std_ulogic;
            variable mux_select : natural;
            variable data_out_valid : std_ulogic;
            variable data_out_last : std_ulogic;
            variable next_data_ready : std_ulogic;

        begin
            -- We alternate between using a reading the next value and accepting
            -- it, which means during the acceptance cycle we have to mark the
            -- next value as invalid.
            next_mux_valid :=
                data_fifo_read_valid and not data_fifo_read_ready;

            if data_mux_valid then
                mux_select := to_integer(data_mux_select);
                data_out_valid :=
                    mux_i(mux_select).data_valid and
                    mux_o(mux_select).data_ready;
                data_out_last :=
                    data_out_valid and
                    mux_i(mux_select).data_last;

                -- Update the output buffer, discover whether we can take data
                -- for the next tick.
                update_data_out(mux_select, data_out_valid, next_data_ready);

                -- Update the appropriate data input for the correct data
                if not data_out_last then
                    -- In the middle of a burst use current selection
                    compute_strobe(mux_data_ready, mux_select, next_data_ready);
                elsif next_mux_valid then
                    -- At the end use the next selection if available
                    compute_strobe(
                        mux_data_ready, to_integer(data_mux_next),
                        next_data_ready);
                else
                    -- If no selection, nothing to do
                    mux_data_ready <= (others => '0');
                end if;

                -- Advance data mux selection on last beat of write
                update_data_mux_select(next_mux_valid, data_out_last);
            else
                -- Stand still until we have something to do
                update_data_out(0, '0', next_data_ready);
                mux_data_ready <= (others => '0');
                update_data_mux_select(next_mux_valid, '0');
            end if;
        end;


        -- Most of the work for completion is already done in the FIFO handshake
        procedure process_completion is
        begin
            compute_strobe(
                mux_write_complete, to_integer(completion_select),
                axi_i.write_complete);

            -- If we don't have a FIFO entry for this completion we have a
            -- protocol error
            unexpected_completion_o <=
                axi_i.write_complete and not completion_valid;
        end;

    begin
        if rising_edge(clk_i) then
            -- Dispatch incoming address to AXI slave and FIFOs
            process_address;
            -- Dispatch the selected data stream
            process_data;
            -- Ensure completions are handled
            process_completion;
        end if;
    end process;


    -- Assign mux_o array
    gen_mux_o : for i in 0 to MUX_CHANNEL_COUNT-1 generate
        mux_o(i) <= (
            address_ready => mux_address_ready(i),
            data_ready => mux_data_ready(i),
            write_complete => mux_write_complete(i)
        );
    end generate;

    -- Assign axi_o
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
