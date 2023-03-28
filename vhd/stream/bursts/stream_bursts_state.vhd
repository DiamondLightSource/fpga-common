-- State machine for burst capture control

-- Note: the control outputs are *not* registered, which is unfortunate, as the
-- logic in this block is pretty complicated.  Unfortunately I don't see a
-- reasonable way to achieve this ... and it appears to work.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.axi_defs.all;

entity stream_bursts_state is
    generic (
        LOG_BURST_LENGTH : natural;         -- log2 of burst length
        ENABLE_FLOW_CONTROL : boolean
    );
    port (
        clk_i : in std_ulogic;

        -- Data stream in
        -- Note that the stated burst length will be enforced by truncating or
        -- padding bursts of the wrong length.
        data_valid_i : in std_ulogic;
        data_last_i : in std_ulogic;
        data_ready_o : out std_ulogic;

        -- Interface to address control
        reset_address_o : out std_ulogic;
        write_address_o : out std_ulogic;
        address_ready_i : in std_ulogic;

        -- Interface to data FIFO
        write_data_ready_i : in std_ulogic;
        write_data_valid_o : out std_ulogic;
        write_data_last_o : out std_ulogic;
        write_data_enable_o : out std_ulogic;

        -- Enable capture.  Hold this high until capture_ready_o is set.
        capture_enable_i : in std_ulogic;
        capture_ready_o : out std_ulogic;

        -- Set when data cannot be sent
        data_error_o : out std_ulogic;
        -- Set when burst has been reshaped
        framing_error_o : out std_ulogic
    );
end;

architecture arch of stream_bursts_state is
    -- The core state machine runs in the following states:
    --  DISABLED    All incoming data is discarded, capture not in progress
    --  CAPTURE     Normal capture, data is passed through
    --  PAD         Triggered on receipt of a short burst to generated padding
    --              empty beats to fill the residue of the burst
    --  SKIP        Triggered on over-long burst to skip excess beats.
    type data_state_t is (DISABLED, CAPTURE, PAD, SKIP);
    signal data_state : data_state_t := DISABLED;

    -- Used to identify start of incoming burst
    signal last_seen : std_ulogic := '1';
    -- Counts words written to data FIFO to ensure all bursts are the correctly
    -- configured length
    signal burst_count : unsigned(LOG_BURST_LENGTH-1 downto 0)
        := (others => '1');

    -- Part of the calculation to decide whether it is safe to accept the latest
    -- burst.  In the absence of flow control we don't want to fill the data
    -- FIFO with data for which we can't emit the address.
    signal skip_this_burst : std_ulogic;
    -- Flag set when data is successfully transferred to the data FIFO
    signal write_data_taken : std_ulogic;

begin
    -- When ENABLE_FLOW_CONTROL is disabled and we don't have a free slot in the
    -- address or data FIFO we will drop this packet.
    skip_this_burst <=
        to_std_ulogic(not ENABLE_FLOW_CONTROL) and
        -- Can only make this decision on the very first beat of the burst
        last_seen and data_valid_i and
        -- Both address and data flow control must be ready.  Strictly we could
        -- qualify only on address_ready_i ...
        not (address_ready_i and write_data_ready_i);

    -- During normal capture enable writing all incoming data unless we are
    -- potentially blocked by the address FIFO.
    with data_state select
        write_data_valid_o <=
            -- Need to include address_ready_i guard to ensure that we can
            -- safely emit the address when the data burst is complete
            data_valid_i and address_ready_i and not skip_this_burst
                when CAPTURE,
            -- Padding data is written unconditionally
            '1' when PAD,
            '0' when others;
    write_data_taken <= write_data_valid_o and write_data_ready_i;

    -- Only enable memory updates to the final destination during full capture
    write_data_enable_o <= to_std_ulogic(data_state = CAPTURE);

    -- Force end of packet when packet count is complete
    write_data_last_o <= to_std_ulogic(burst_count = 0);

    -- Flow control to sender
    with data_state select
        data_ready_o <=
            -- Allow data to flow while fifo can take data
            write_data_ready_i and address_ready_i when CAPTURE,
            -- Block fresh data while padding
            '0' when PAD,
            -- When inactive or skipping all data will be dropped
            '1' when DISABLED | SKIP;

    -- Capture engine handshake
    capture_ready_o <= to_std_ulogic(data_state /= DISABLED);

    -- Write the capture address when writing the last beat of the burst.
    -- Need to ensure this is done at this instant so that we can safely check
    -- the address_ready_i bit on the next clock tick for skip_this_burst.
    with data_state select
        write_address_o <=
            '0' when DISABLED | SKIP,
            -- Write and advance address when last beat written to FIFO
            write_data_taken and to_std_ulogic(burst_count = 0)
                when CAPTURE | PAD;

    -- Clear address at start of capture request
    reset_address_o <=
        to_std_ulogic(data_state = DISABLED) and capture_enable_i;

    process (clk_i)
        variable frame_boundary : std_ulogic;
        variable capture_or_disabled : data_state_t;

    begin
        if rising_edge(clk_i) then
            -- We can only safely start and stop capture on a frame boundary,
            -- either on the last tick or any empty space following
            frame_boundary := data_last_i when data_valid_i else last_seen;

            -- Next state on completion of capture, depends on capture enable
            capture_or_disabled := CAPTURE when capture_enable_i else DISABLED;

            -- Data output state control
            case data_state is
                when DISABLED =>
                    -- Wait for capture enable on frame boundary
                    if capture_enable_i and frame_boundary then
                        data_state <= CAPTURE;
                    end if;

                when CAPTURE =>
                    if skip_this_burst then
                        data_state <= SKIP;
                    elsif write_data_taken then
                        if burst_count = 0 then
                            if data_last_i then
                                -- Normal completion of burst
                                data_state <= capture_or_disabled;
                            else
                                -- Outgoing burst complete but incoming burst
                                -- has excess beats.  Need to skip the residue
                                data_state <= SKIP;
                            end if;
                        elsif data_last_i then
                            -- Incoming burst ended early, pad until complete.
                            data_state <= PAD;
                        end if;
                    end if;

                when PAD =>
                    -- Used to pad truncated burst to required length
                    if burst_count = 0 then
                        data_state <= capture_or_disabled;
                    end if;

                when SKIP =>
                    -- Used to skip excess data words from overlong burst
                    if data_valid_i and data_last_i then
                        data_state <= capture_or_disabled;
                    end if;
            end case;


            -- Manage incoming frame boundary.  Use this to identify first word
            -- in each burst.
            if data_valid_i then
                last_seen <= data_last_i;
            end if;

            -- Update burst counter, only counting data successfully written to
            -- the data FIFO.  Failed writes will cause framing errors which
            -- we'll handle by skipping and padding as necessary.
            if write_data_taken then
                if write_data_last_o then
                    burst_count <= (others => '1');
                else
                    burst_count <= burst_count - 1;
                end if;
            end if;


            -- Report data error if data FIFO is ever full when we're writing
            -- This cannot happen when flow control is enabled
            data_error_o <=
                write_data_valid_o and not write_data_ready_i and
                to_std_ulogic(not ENABLE_FLOW_CONTROL);

            -- Report a framing error if we trigger either of the exceptional
            -- capture handling states.
            framing_error_o <=
                to_std_ulogic(data_state = PAD or data_state = SKIP);
        end if;
    end process;
end;
