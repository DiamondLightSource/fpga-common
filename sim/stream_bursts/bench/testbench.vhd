library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.support.all;
use work.axi_defs.all;
use work.stream_defs.all;

entity testbench is
end testbench;

architecture arch of testbench is
    signal clk : std_ulogic := '0';

    procedure clk_wait(count : in natural := 1) is
    begin
        for i in 0 to count-1 loop
            wait until rising_edge(clk);
        end loop;
    end procedure;

    constant LOG_DATA_BYTES : natural := 2;
--     constant LOG_BURST_LENGTH : natural := 3;
    constant LOG_BURST_LENGTH : natural := 1;
    constant ENABLE_FLOW_CONTROL : boolean := true;

    -- The address width allows room for 3 bits of burst address, 2 bits of byte
    -- address, and the remaining from the burst length
    constant ADDRESS_WIDTH : natural := LOG_BURST_LENGTH + 5;
    subtype ADDRESS_RANGE is natural
        range ADDRESS_WIDTH-1 downto LOG_BURST_LENGTH+LOG_DATA_BYTES;

    -- Signals for bursts_top
    signal stream : data_stream_t
        (data(8 * 2**LOG_DATA_BYTES - 1 downto 0));
    signal stream_ready : std_ulogic;
    signal axi_out : axi_write_t(
        address(ADDRESS_WIDTH-1 downto LOG_DATA_BYTES),
        data(8 * 2**LOG_DATA_BYTES - 1 downto 0));
    signal axi_in : axi_write_ready_t;
    signal capture_enable : std_ulogic;
    signal capture_ready : std_ulogic;
    signal count_sent : std_ulogic;
    signal first_address : unsigned(ADDRESS_RANGE);
    signal last_address : unsigned(ADDRESS_RANGE);
    signal capture_address : unsigned(ADDRESS_RANGE);
    signal data_error : std_ulogic;
    signal framing_error : std_ulogic;

    -- Stream generation
    signal block_address : std_ulogic := '0';
    signal block_data : std_ulogic := '0';

    signal burst_count : natural;

    procedure write(message : string) is
        variable linebuffer : line;
    begin
        write(linebuffer, message);
        writeline(output, linebuffer);
    end;

begin
    clk <= not clk after 1 ns;

    bursts : entity work.stream_bursts generic map (
        LOG_BURST_LENGTH => LOG_BURST_LENGTH,
        ADDRESS_WIDTH => ADDRESS_WIDTH,
        LOG_DATA_BYTES => LOG_DATA_BYTES,
        ENABLE_FLOW_CONTROL => ENABLE_FLOW_CONTROL
    ) port map (
        clk_i => clk,

        stream_i => stream,
        stream_ready_o => stream_ready,

        axi_o => axi_out,
        axi_i => axi_in,

        capture_enable_i => capture_enable,
        capture_ready_o => capture_ready,
        count_sent_o => count_sent,

        first_address_i => first_address,
        last_address_i => last_address,
        capture_address_o => capture_address,

        data_error_o => data_error,
        framing_error_o => framing_error
    );

    first_address <= "001";
    last_address <= "101";


    axi_slave : entity work.axi_write_slave generic map (
        MAX_ADDRESS_COUNT => 2
    ) port map (
        clk_i => clk,
        axi_i => axi_out,
        axi_o => axi_in,
        block_address_i => block_address,
        block_data_i => block_data
    );


    -- Burst sender
    process
        constant BURST_LENGTH : natural := 2**LOG_BURST_LENGTH;
        constant DATA_WIDTH : natural := 8*2**LOG_DATA_BYTES;

        variable burst_counter : natural := 0;

        procedure send_burst(
            count : natural; delay : natural := 0; gap : natural := 0)
        is
            variable data_counter : natural := 0;
        begin
            for i in 1 to count loop
                stream <= (
                    valid => '1',
                    last => to_std_ulogic(i = count),
                    data =>
                        to_std_ulogic_vector_u(burst_counter mod 256, 8) &
                        to_std_ulogic_vector_u(i, DATA_WIDTH - 8)
                );
                loop
                    clk_wait;
                    if stream_ready = '1' or not ENABLE_FLOW_CONTROL then
                        exit;
                    end if;
                end loop;
                stream.valid <= '0';
                clk_wait(delay);
            end loop;
            burst_counter := burst_counter + 1;
            -- Enforce one tick gap between bursts
            clk_wait(gap);
        end;

    begin
        stream.valid <= '0';

        clk_wait(10);

        -- Send about a dozen normal bursts to start off
        for n in 1 to 12 loop
            send_burst(BURST_LENGTH, 1);
        end loop;

        -- Now send some bursts of the wrong length
        send_burst(BURST_LENGTH*2);
        send_burst(BURST_LENGTH*2);
        send_burst(BURST_LENGTH/2);
        send_burst(BURST_LENGTH/2);
        send_burst(BURST_LENGTH/2);
        send_burst(BURST_LENGTH/2);

        -- Send some normal bursts back to back
        for n in 1 to 10 loop
            send_burst(BURST_LENGTH);
        end loop;
        send_burst(BURST_LENGTH, 2);
        clk_wait(10);
        send_burst(BURST_LENGTH);

        -- Now send a couple of short bursts
        send_burst(1);
        clk_wait(5);
        send_burst(6);
        clk_wait(10);

        -- Some normal bursts spaced out a little
        send_burst(BURST_LENGTH);
        clk_wait(2);
        send_burst(BURST_LENGTH);
        clk_wait(2);

        -- Now a long burst followed by a stream of normal bursts
        send_burst(2 * BURST_LENGTH);
        loop
            send_burst(BURST_LENGTH);
        end loop;

        wait;
    end process;


    -- Manage capture enable
    process
        procedure start_capture is
        begin
            capture_enable <= '1';
            while not capture_ready loop
                clk_wait;
            end loop;
            clk_wait;
            write("start capture");
        end;

        procedure stop_capture is
        begin
            capture_enable <= '0';
            while capture_ready loop
                clk_wait;
            end loop;
            clk_wait;
            write("stop capture");
        end;

    begin
        capture_enable <= '0';
        block_address <= '0';
        block_data <= '0';

        clk_wait(12);

        -- Start with a reasonably long normal capture
        start_capture;
        clk_wait(100);

        clk_wait(10);

        block_address <= '1';
        block_data <= '1';

        clk_wait(10);
        stop_capture;

        start_capture;

        clk_wait(20);
        block_data <= '0';
        clk_wait(10);
        block_address <= '0';
        clk_wait(10);
        block_address <= '1';
        clk_wait(10);
        block_data <= '1';
        block_address <= '0';
        clk_wait(10);
        block_data <= '0';

        clk_wait(10);
        stop_capture;

        start_capture;

        clk_wait(10);
        stop_capture;

        start_capture;

        clk_wait(20);

        clk_wait(10);
        stop_capture;

        start_capture;

        wait;
    end process;


    -- Count burst lengths
    process (clk)
        variable counter : natural := 0;
    begin
        if rising_edge(clk) then
            if axi_out.data_valid and axi_in.data_ready then
                counter := counter + 1;
                if axi_out.data_last then
                    burst_count <= counter;
                    counter := 0;
                end if;

                write(
                    "rx: " & to_hstring(axi_out.data) &
                    " " & to_string(axi_out.data_enable) &
                    " " & to_string(axi_out.data_last));
            end if;
        end if;
    end process;
end;
