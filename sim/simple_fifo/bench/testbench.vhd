library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

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

    signal write_valid : std_ulogic := '0';
    signal write_ready : std_ulogic;
    signal write_ready_early : std_ulogic;
    signal write_data : unsigned(7 downto 0) := X"00";
    signal read_valid : std_ulogic;
    signal read_ready : std_ulogic := '0';
    signal read_data : unsigned(7 downto 0);

begin
    clk <= not clk after 1 ns;

    fifo : entity work.simple_fifo generic map (
        FIFO_DEPTH => 4,
        DATA_WIDTH => 8
    ) port map (
        clk_i => clk,
        write_valid_i => write_valid,
        write_ready_o => write_ready,
        write_ready_early_o => write_ready_early,
        write_data_i => std_ulogic_vector(write_data),
        read_valid_o => read_valid,
        read_ready_i => read_ready,
        unsigned(read_data_o) => read_data
    );


    -- Writing process
    process
        procedure write is
        begin
            write_data <= write_data + 1;
            write_valid <= '1';
            loop
                clk_wait;
                if write_ready then exit; end if;
            end loop;
            write_valid <= '0';
        end;

    begin
        -- First just fill the fifo as fast as possible
        clk_wait;
        for i in 1 to 8 loop
            write;
        end loop;

        -- Wait for readout
        clk_wait(10);

        -- Now write the fifo more slowly with write strobes.
        clk_wait;
        for i in 1 to 8 loop
            write;
            clk_wait;
        end loop;

        -- Now write with proper handshaking.  This will wait for reader.
        clk_wait;
        for i in 1 to 8 loop
            write;
            clk_wait;
        end loop;

        -- Fill the fifo again
        clk_wait(10);
        for i in 1 to 4 loop
            write;
        end loop;

        wait;
    end process;


    -- Reading process
    process
        procedure read is
        begin
            read_ready <= '1';
            loop
                clk_wait;
                if read_valid then exit; end if;
            end loop;
            read_ready <= '0';
        end;

        procedure read_all is
        begin
            read_ready <= '1';
            while read_valid loop
                clk_wait;
            end loop;
            clk_wait;
            read_ready <= '0';
        end;
    begin
        -- Wait for first burst to complete
        clk_wait(10);

        -- Read out what we just wrote
        read_all;

        -- Long wait: this will block the writer
        clk_wait(50);

        -- Again, read out everything stored
        read_all;

        -- Wait for stalled process
        clk_wait(10);

        -- Again, read out everything stored
        read_all;

        clk_wait(5);

        -- Finally read continually
        loop
            read;
        end loop;

        wait;
    end process;
end;
