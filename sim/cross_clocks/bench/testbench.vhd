library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity testbench is
end testbench;


architecture arch of testbench is
    signal clk_in : std_ulogic := '0';
    signal clk_out : std_ulogic := '0';

    procedure clk_wait(signal clk : in std_ulogic; count : in natural := 1) is
    begin
        for i in 1 to count loop
            wait until rising_edge(clk);
        end loop;
    end procedure;

    -- Shared control and data
    signal strobe_in : std_ulogic;
    signal data_in : unsigned(15 downto 0) := X"0000";
    signal data_out : unsigned(15 downto 0) := X"0000";

    -- Data and control on clk_in
    signal read_ack_in : std_ulogic;
    signal read_data_in : unsigned(15 downto 0);
    signal write_ack_in : std_ulogic;
    signal write_read_ack_in : std_ulogic;
    signal write_read_data_in : unsigned(15 downto 0);

    -- Data and control on clk_out
    signal read_strobe_out : std_ulogic;
    signal read_ack_out : std_ulogic := '0';
    signal write_strobe_out : std_ulogic;
    signal write_ack_out : std_ulogic := '0';
    signal write_data_out : unsigned(15 downto 0);
    signal write_read_strobe_out : std_ulogic;
    signal write_read_ack_out : std_ulogic := '0';
    signal write_read_data_out : unsigned(15 downto 0);

    procedure writeln(message : string) is
        variable linebuffer : line;
    begin
        write(linebuffer, message);
        writeline(output, linebuffer);
    end;

begin
    clk_in <= not clk_in after 2 ns;
    clk_out <= not clk_out after 2.57 ns;


    read : entity work.cross_clocks_read port map (
        clk_in_i => clk_in,
        strobe_i => strobe_in,
        ack_o => read_ack_in,
        unsigned(data_o(read_data_in'RANGE)) => read_data_in,

        clk_out_i => clk_out,
        strobe_o => read_strobe_out,
        ack_i => read_ack_out,
        data_i(data_out'RANGE) => std_ulogic_vector(data_out)
    );

    write : entity work.cross_clocks_write port map (
        clk_in_i => clk_in,
        strobe_i => strobe_in,
        ack_o => write_ack_in,
        data_i(data_in'RANGE) => std_ulogic_vector(data_in),

        clk_out_i => clk_out,
        strobe_o => write_strobe_out,
        ack_i => write_ack_out,
        unsigned(data_o(write_data_out'RANGE)) => write_data_out
    );

    write_read : entity work.cross_clocks_write_read port map (
        clk_in_i => clk_in,
        strobe_i => strobe_in,
        ack_o => write_read_ack_in,
        write_data_i(data_in'RANGE) => std_ulogic_vector(data_in),
        unsigned(read_data_o(write_read_data_in'RANGE)) => write_read_data_in,

        clk_out_i => clk_out,
        strobe_o => write_read_strobe_out,
        ack_i => write_read_ack_out,
        unsigned(write_data_o(write_read_data_out'RANGE)) =>
            write_read_data_out,
        read_data_i(data_out'RANGE) =>
            std_ulogic_vector(data_out + write_read_data_out)
    );


    -- Input process: generates transactions repeatedly
    process
        procedure clk_wait(count : in natural := 1) is
        begin
            clk_wait(clk_in, count);
        end procedure;

        procedure transaction is
            variable sent_data : unsigned(15 downto 0);
            variable ack_count : natural := 0;
        begin
            -- Initiate transaction for all three devices under test
            strobe_in <= '1';
            clk_wait;
            sent_data := data_in;
            strobe_in <= '0';

            -- Wait for completion.  Quick and dirty, we know to expect three
            -- ack strobes
            while ack_count < 3 loop
                clk_wait;

                if read_ack_in then
                    ack_count := ack_count + 1;
                    writeln("Read: " & to_hstring(read_data_in));
                end if;

                if write_ack_in then
                    ack_count := ack_count + 1;
                    writeln("Write: " & to_hstring(sent_data));
                end if;

                if write_read_ack_in then
                    ack_count := ack_count + 1;
                    writeln("Write/Read: " &
                        to_hstring(sent_data) & " => " &
                        to_hstring(write_read_data_in));
                end if;
            end loop;
        end procedure;

    begin
        strobe_in <= '0';

        loop
            transaction;
        end loop;

        wait;
    end process;


    -- Data generation: just increment the data on the corresponding clock tick
    process (clk_in) begin
        if rising_edge(clk_in) then
            data_in <= data_in + 1;
        end if;
    end process;

    process (clk_out) begin
        if rising_edge(clk_out) then
            data_out <= data_out + 1;

            -- For now, just acknowledge each transaction on the next tick
            read_ack_out <= read_strobe_out;
            write_ack_out <= write_strobe_out;
            write_read_ack_out <= write_read_strobe_out;

            if read_ack_out then
                writeln(" => read: " & to_hstring(data_out));
            end if;
            if write_ack_out then
                writeln(" => write: " & to_hstring(write_data_out));
            end if;
            if write_read_ack_out then
                writeln(" => write: " & to_hstring(write_read_data_out) &
                " -> " & to_hstring(data_out + write_read_data_out));
            end if;
        end if;
    end process;
end;
