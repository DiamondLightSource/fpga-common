-- Control over capture of a single burst formatted data stream

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.axi_defs.all;

use work.stream_defs.all;
use work.stream_capture_defs.all;

entity stream_capture_bursts is
    generic (
        LOG_BURST_LENGTH : natural;         -- log2 of burst length
        PROGRESS_BIT : natural;             -- Addr bit for progress interrupt
        ADDRESS_WIDTH : natural;            -- Includes all byte address parts
        LOG_DATA_BYTES : natural := 2;      -- 4 bytes, 32 bits
        ADDRESS_FIFO_DEPTH : natural := 2;
        LOG_DATA_FIFO_DEPTH : natural := 1;
        ENABLE_FLOW_CONTROL : boolean := false
    );
    port (
        clk_i : in std_ulogic;

        -- Data stream
        -- Note that due to a restriction in capture_bursts_stream there *must*
        -- be at least one tick of delay between bursts in this stream.
        stream_i : in data_stream_t;
        -- If ENABLE_FLOW_CONTROL is false this can be ignored, otherwise normal
        -- data flow handshaking must be used.
        stream_ready_o : out std_ulogic;

        -- Write interface to AXI slave
        axi_o : out axi_write_t(
            address(ADDRESS_WIDTH-1 downto LOG_DATA_BYTES),
            data(8 * 2**LOG_DATA_BYTES-1 downto 0));
        axi_i : in axi_write_ready_t;

        -- Register interface
        control_i : in stream_capture_control_t;
        status_o : out stream_capture_status_t;

        -- Start and end addresses.  If not specified the entire address range
        -- is addressed.
        first_address_i : in unsigned(ADDRESS_WIDTH-1 downto 0)
            := (others => '0');
        last_address_i : in unsigned(ADDRESS_WIDTH-1 downto 0)
            := (others => '1');

        trigger_i : in std_ulogic
    );
end;

architecture arch of stream_capture_bursts is
    subtype ADDRESS_RANGE is natural
        range ADDRESS_WIDTH-1 downto LOG_BURST_LENGTH+LOG_DATA_BYTES;

    signal capture_enable : std_ulogic;
    signal capture_ready : std_ulogic;
    signal capture_address : unsigned(ADDRESS_RANGE);
    signal count_sent : std_ulogic;

    -- status_o signals
    signal capture_address_out :
        unsigned(status_o.capture_address'LENGTH-1 downto 0);
    signal capture_busy_out : std_ulogic;
    signal triggered_out : std_ulogic;
    signal framing_error_out : std_ulogic;
    signal data_error_out : std_ulogic;
    signal complete_out : std_ulogic;
    signal progress_out : std_ulogic;

begin
    control : entity work.stream_capture_control port map (
        clk_i => clk_i,

        start_i => control_i.start,
        stop_i => control_i.stop,
        abort_i => control_i.abort,
        runout_count_i => control_i.runout_count,
        capture_address_o => capture_address_out,
        capture_busy_o => capture_busy_out,
        triggered_o => triggered_out,

        capture_enable_o => capture_enable,
        capture_ready_i => capture_ready,
        capture_address_i => capture_address - first_address_i(ADDRESS_RANGE),
        count_sent_i => count_sent,

        trigger_i => trigger_i
    );


    stream : entity work.stream_bursts generic map (
        ADDRESS_WIDTH => ADDRESS_WIDTH,
        LOG_DATA_BYTES => LOG_DATA_BYTES,
        LOG_BURST_LENGTH => LOG_BURST_LENGTH,
        ADDRESS_FIFO_DEPTH => ADDRESS_FIFO_DEPTH,
        LOG_DATA_FIFO_DEPTH => LOG_DATA_FIFO_DEPTH,
        ENABLE_FLOW_CONTROL => ENABLE_FLOW_CONTROL
    ) port map (
        clk_i => clk_i,

        stream_i => stream_i,
        stream_ready_o => stream_ready_o,

        axi_o => axi_o,
        axi_i => axi_i,

        capture_enable_i => capture_enable,
        capture_ready_o => capture_ready,
        count_sent_o => count_sent,

        first_address_i => first_address_i(ADDRESS_RANGE),
        last_address_i => last_address_i(ADDRESS_RANGE),
        capture_address_o => capture_address,

        data_error_o => data_error_out,
        framing_error_o => framing_error_out
    );


    complete_out <= not capture_ready;
    progress_out <= capture_address(PROGRESS_BIT);
    status_o <= (
        capture_address => capture_address_out,
        capture_busy => capture_busy_out,
        framing_error => framing_error_out,
        data_error => data_error_out,
        triggered => triggered_out,
        complete => complete_out,
        progress => progress_out
    );
end;
