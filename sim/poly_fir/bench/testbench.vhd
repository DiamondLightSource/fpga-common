library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.textio.all;
use ieee.std_logic_textio.all;

use work.support.all;
use work.stream_defs.all;

use work.bench_config.all;

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

    signal start_write : std_ulogic;
    signal write_tap : std_ulogic;
    signal tap : signed(17 downto 0);
    signal stream_in : data_stream_t(data(24 downto 0));

    signal last_out : std_ulogic;
    signal enable_out : std_ulogic;
    signal data_out : signed(31 downto 0);
    signal stream_out : data_stream_t(data(31 downto 0));

    signal overflow : std_ulogic;

    constant TAP_COUNT : natural := 3;
    constant DECIMATION : natural := 4;
    constant WAYS : natural := 8;
--     constant WAYS : natural := 2;

    signal test_enables_in : std_ulogic_vector(0 to WAYS-1);
    signal test_enables_out : std_ulogic_vector(0 to WAYS-1);
    signal test_data_in : signed_array(0 to WAYS-1)(24 downto 0)
        := (others => (others => '0'));
    signal test_data_out : signed_array(0 to WAYS-1)(31 downto 0);

    signal running : boolean := false;

begin
    clk <= not clk after 2 ns;

    stream_mux : entity work.stream_mux generic map (
        WIDTH => 25,
        WAYS => WAYS
    ) port map (
        clk_i => clk,
        enables_i => test_enables_in,
        data_i => vector_array(test_data_in),
        stream_o => stream_in
    );

    sel : if USE_SLOW_POLY_FIR generate
        poly_fir : entity work.slow_poly_fir generic map (
            OVERLAPS => TAP_COUNT,
            DECIMATION => DECIMATION,
            WAYS => WAYS,
            FILTER_GAIN => -3,
            DATA_WIDTH => 25
        ) port map (
            clk_i => clk,

            start_write_i => start_write,
            write_tap_i => write_tap,
            tap_i => tap,

            last_i => stream_in.last,
            enable_i => stream_in.valid,
            data_i => signed(stream_in.data),

            last_o => last_out,
            enable_o => enable_out,
            data_o => data_out,

            overflow_o => overflow
        );
    else generate
        poly_fir : entity work.poly_fir generic map (
            TAP_COUNT => TAP_COUNT,
            DECIMATION => DECIMATION,
            WAYS => WAYS,
            FILTER_GAIN => -3,
            DATA_WIDTH => 25
        ) port map (
            clk_i => clk,

            start_write_i => start_write,
            write_tap_i => write_tap,
            tap_i => tap,

            last_i => stream_in.last,
            enable_i => stream_in.valid,
            data_i => signed(stream_in.data),

            last_o => last_out,
            enable_o => enable_out,
            data_o => data_out,

            overflow_o => overflow
        );
    end generate;

    stream_out <= (
        valid => enable_out, last => last_out,
        data => std_ulogic_vector(data_out));


    stream_demux : entity work.stream_demux generic map (
        WIDTH => 32,
        WAYS => WAYS
    ) port map (
        clk_i => clk,
        stream_i => stream_out,
        enables_o => test_enables_out,
        signed_array(data_o) => test_data_out
    );


    -- Drive system from stimulus files
    process
        procedure strobe_signal(signal strobe_o : out std_ulogic) is
        begin
            strobe_o <= '1';
            clk_wait;
            strobe_o <= '0';
        end;

        procedure write_next_tap(value : signed(17 downto 0)) is
        begin
            tap <= value;
            strobe_signal(write_tap);
        end;

        procedure strobe_data is
        begin
            test_enables_in <= (others => '1');
            clk_wait;
            test_enables_in <= (others => '0');
            clk_wait(WAYS + STROBE_DATA_DELAY);
        end;

        procedure load_taps(filename : string) is
            file filter_taps : text;
            variable current_line : line;
            variable current_value : integer;
        begin
            strobe_signal(start_write);
            file_open(filter_taps, filename, read_mode);
            for i in 0 to DECIMATION*TAP_COUNT - 1 loop
                readline(filter_taps, current_line);
                read(current_line, current_value);
                write_next_tap(to_signed(current_value, 18));
            end loop;
            file_close(filter_taps);
        end;

        procedure load_stimulus(filename : string) is
            file stimulus_file : text;
            variable current_line : line;
            variable current_value : integer;
        begin
            file_open(stimulus_file, filename, read_mode);
            while not endfile(stimulus_file) loop
                readline(stimulus_file, current_line);
                for i in 0 to WAYS-1 loop
                    read(current_line, current_value);
                    test_data_in(i) <= to_signed(current_value, 25);
                end loop;
                strobe_data;
            end loop;
            file_close(stimulus_file);
        end;

    begin
        start_write <= '0';
        write_tap <= '0';
        test_enables_in <= (others => '0');

        clk_wait(2);

        -- Load the taps
        load_taps("filter-taps.txt");
        clk_wait(2);


        -- Load the stimulus and drive the system
        running <= true;
        load_stimulus("stimulus.txt");

        -- Wait for the filter to run through and end
        for i in 0 to DECIMATION * TAP_COUNT loop
            strobe_data;
        end loop;
        running <= false;

        -- Now let the filter run indefinitely
        loop
            load_stimulus("stimulus.txt");
        end loop;

        wait;
    end process;


    -- Capture first cycle of stimulus and save to disk
    process
        file result_file : text;
        variable current_line : line;
        variable current_value : integer;

    begin
        wait until running;

        file_open(result_file, "result.txt", write_mode);
        while running loop
            for i in 0 to WAYS-1 loop
                wait until test_enables_out(i);
                current_value := to_integer(test_data_out(i));
                write(current_line, current_value);
                write(current_line, ' ');
            end loop;
            writeline(result_file, current_line);
        end loop;
        file_close(result_file);

        wait;
    end process;
end;
