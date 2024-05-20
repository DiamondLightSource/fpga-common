library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity testbench is
end testbench;

architecture arch of testbench is
    procedure clk_wait(signal clk : std_ulogic; count : in natural := 1) is
    begin
        for i in 0 to count-1 loop
            wait until rising_edge(clk);
        end loop;
    end procedure;

    procedure write(message : string) is
        variable linebuffer : line;
    begin
        write(linebuffer, message);
        writeline(output, linebuffer);
    end;

    constant FIFO_BITS : natural := 3;

    signal write_clk : std_ulogic := '0';
    signal read_clk : std_ulogic := '0';

    signal write_valid : std_ulogic := '0';
    signal write_ready : std_ulogic;
    signal write_data : unsigned(7 downto 0) := X"00";
    signal read_valid : std_ulogic;
    signal read_ready : std_ulogic := '0';
    signal read_data : unsigned(7 downto 0);
    signal reset_fifo : std_ulogic := '0';

    signal read_reset : std_ulogic;
    signal write_reset : std_ulogic;

    signal enable_read : std_ulogic;
    signal read_delay : natural;

begin
    write_clk <= not write_clk after 0.677 ns;
    read_clk <= not read_clk after 1 ns;


    reset : entity work.async_fifo_reset port map (
        reset_i => reset_fifo,
        write_clk_i => write_clk,
        write_reset_o => write_reset,
        read_clk_i => read_clk,
        read_reset_o => read_reset
    );

    fifo : entity work.async_fifo generic map (
        FIFO_BITS => FIFO_BITS,
        DATA_WIDTH => 8
    ) port map (
        write_clk_i => write_clk,
        write_reset_i => write_reset,
        write_valid_i => write_valid,
        write_ready_o => write_ready,
        write_data_i => std_ulogic_vector(write_data),

        read_clk_i => read_clk,
        read_reset_i => read_reset,
        read_valid_o => read_valid,
        read_ready_i => read_ready,
        unsigned(read_data_o) => read_data
    );


    -- Writing process
    process
        procedure clk_wait(count : in natural := 1) is
        begin
            clk_wait(write_clk, count);
        end procedure;

        procedure write is
        begin
            write_valid <= '1';
            loop
                clk_wait;
                exit when write_ready;
            end loop;
            write_valid <= '0';
            write_data <= write_data + 1;
            write(
                "@ " & to_string(now, unit => ns) &
                ": write <= " & to_string(to_integer(write_data)));
        end;

    begin
        enable_read <= '0';
        read_delay <= 0;
        reset_fifo <= '0';

        -- First just fill the fifo as fast as possible without reading
        clk_wait(2);
        for i in 1 to 8 loop
            write;
        end loop;

        -- Write and read
        enable_read <= '1';
        for i in 1 to 8 loop
            write;
        end loop;

        -- Wait for fifo to empty
        while read_valid loop
            clk_wait;
        end loop;
        enable_read <= '0';

        -- Fill the FIFO more slowly
        clk_wait;
        for i in 1 to 8 loop
            write;
            clk_wait;
        end loop;

        -- Now enable slower reads
        enable_read <= '1';
        read_delay <= 1;

        -- Fill FIFO, let it drain a little
        clk_wait;
        for i in 1 to 8 loop
            write;
        end loop;
        clk_wait(10);

        -- Fill the fifo again with slower and slower reads
        for i in 1 to 8 loop
            write;
            read_delay <= read_delay + 1;
        end loop;

        -- Go straight into reset
        reset_fifo <= '1';
        clk_wait(10);
        reset_fifo <= '0';

        -- Realign the expected read data to account for data lost during reset
        write_data <= to_unsigned(31, 8);
        write("Resetting write_data");

        clk_wait;
        read_delay <= 0;
        for i in 1 to 16 loop
            write;
        end loop;

        wait;
    end process;


    -- Reading process
    process
        variable expecting : natural := 0;

        procedure clk_wait(count : in natural := 1) is
        begin
            clk_wait(read_clk, count);
        end procedure;

        procedure read is
            variable seen : natural;
        begin
            read_ready <= '1';
            loop
                clk_wait;
                exit when read_valid;
            end loop;
            seen := to_integer(read_data);
            write(
                "@ " & to_string(now, unit => ns) &
                ": read => " & to_string(seen));
            read_ready <= '0';

            -- Sanity check, numbers should come out in perfect sequence
            assert seen = expecting
                report "Expected " & to_string(expecting) & " but saw " &
                    to_string(seen)
                severity failure;
            expecting := expecting + 1;
        end;

    begin
        if enable_read and read_valid then
            read;
            clk_wait(read_delay);
        else
            clk_wait;
        end if;
    end process;
end;
