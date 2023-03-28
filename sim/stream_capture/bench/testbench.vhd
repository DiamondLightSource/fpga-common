library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.support.all;
use work.axi_defs.all;
use work.stream_defs.all;
use work.stream_capture_defs.all;

entity testbench is
end testbench;

architecture arch of testbench is
    signal clk : std_ulogic := '0';

    procedure clk_wait(count : natural := 1) is
    begin
        for i in 1 to count loop
            wait until rising_edge(clk);
        end loop;
    end;

    procedure write(message : string := "") is
        variable linebuffer : line;
    begin
        write(linebuffer, message);
        writeline(output, linebuffer);
    end;


    constant LOG_DATA_BYTES : natural := 2;
    constant LOG_BURST_LENGTH : natural := 4;
    constant BURST_LENGTH : natural := 2**LOG_BURST_LENGTH;
    constant ADDRESS_WIDTH : natural := 16;
subtype ADDRESS_RANGE is natural
        range ADDRESS_WIDTH-1 downto LOG_DATA_BYTES + LOG_BURST_LENGTH;
    subtype DATA_RANGE is natural range 8*2**LOG_DATA_BYTES-1 downto 0;

    signal data_stream : data_stream_t(data(31 downto 0));
    signal stream_ready : std_ulogic;

    signal axi_write : axi_write_t(
        address(ADDRESS_WIDTH-1 downto LOG_DATA_BYTES), data(DATA_RANGE));
    signal axi_write_ready : axi_write_ready_t;

    -- capture_bursts interface
    signal control : stream_capture_control_t(runout_count(ADDRESS_RANGE));
    signal status : stream_capture_status_t(capture_address(ADDRESS_RANGE));
    signal trigger : std_ulogic;

    -- capture_fifo interface
    signal read_strobe : std_ulogic;
    signal read_data : std_ulogic_vector(DATA_RANGE);
    signal read_ack : std_ulogic;
    signal fifo_underrun : std_ulogic;
    signal fifo_overflow : std_ulogic;
    signal fifo_ready : std_ulogic;
    signal fifo_reset : std_ulogic;

begin
    clk <= not clk after 2 ns;

    axi_slave : entity work.axi_write_slave generic map (
        COMPLETE_DELAY => 2,
        ENABLE_LOGGING => true
    ) port map (
        clk_i => clk,
        axi_i => axi_write,
        axi_o => axi_write_ready
    );


    capture_bursts : entity work.stream_capture_bursts generic map (
        LOG_BURST_LENGTH => LOG_BURST_LENGTH,
        PROGRESS_BIT => 8,
        ADDRESS_WIDTH => ADDRESS_WIDTH,
        LOG_DATA_BYTES => 2
    ) port map (
        clk_i => clk,
        stream_i => data_stream,
        stream_ready_o => stream_ready,
        axi_o => axi_write,
        axi_i => axi_write_ready,
        control_i => control,
        status_o => status,
        first_address_i => X"0000",
        last_address_i => X"0FFF",
        trigger_i => trigger
    );


    capture_fifo : entity work.stream_capture_fifo generic map (
        READY_DEPTH => BURST_LENGTH,
        LOG_FIFO_DEPTH => 6
    ) port map (
        clk_i => clk,
        stream_i => data_stream,
        read_strobe_i => read_strobe,
        read_data_o => read_data,
        read_ack_o => read_ack,
        fifo_underrun_o => fifo_underrun,
        fifo_overflow_o => fifo_overflow,
        fifo_ready_o => fifo_ready,
        fifo_reset_i => fifo_reset
    );


    -- Data generation
    gen_data : entity work.stream_generator generic map (
        BURST_LENGTH => BURST_LENGTH,
        BURST_DELAY => 40,
        TAG => 1
    ) port map (
        clk_i => clk,
        stream_o => data_stream
    );


    -- Control the burst capture engine
    process begin
        control <= (
            start => '0',
            stop => '0',
            abort => '0',
            runout_count => (others => '0'));
        trigger <= '0';

        clk_wait(10);
        control.runout_count <= 10X"0010";
        control.start <= '1';
        control.stop <= '0';
        clk_wait;
        control.start <= '0';

        clk_wait(500);
        trigger <= '1';
        clk_wait;
        trigger <= '0';

        wait;
    end process;


    -- Read fifo continously
    process
        -- Read one word from FIFO without checking
        procedure read_fifo is
        begin
            read_strobe <= '1';
            clk_wait;
            read_strobe <= '0';
            while not read_ack loop
                clk_wait;
            end loop;
        end;


        -- Read complete burst from FIFO after waiting for ready
        procedure read_fifo_burst is
            variable linebuffer : line;

        begin
            -- Wait for fifo to become ready
            while not fifo_ready loop
                clk_wait;
            end loop;

            -- Read from the fifo until consumed
            write(linebuffer, "@ " & to_string(now, unit => ns) & " FIFO:");
            for i in 1 to BURST_LENGTH loop
                read_fifo;
                write(linebuffer, " " & to_hstring(read_data));
            end loop;
            writeline(output, linebuffer);
        end;

    begin
        read_strobe <= '0';
        fifo_reset <= '0';

        -- Do a couple of normal reads
        read_fifo_burst;
        read_fifo_burst;

        -- Try an underrun read
        read_fifo;

        -- Now wait for the FIFO to overflow
        while not fifo_overflow loop
            clk_wait;
        end loop;

        -- Reset the FOF and resume reading
        fifo_reset <= '1';
        clk_wait;
        fifo_reset <= '0';

        loop
            read_fifo_burst;
        end loop;

        wait;
    end process;
end;
