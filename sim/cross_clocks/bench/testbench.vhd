library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

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

    signal strobe_in : std_ulogic;
    signal ack_in : std_ulogic;
    signal strobe_out : std_ulogic;
    signal ack_out : std_ulogic;

    signal read_ack_in : std_ulogic;
    signal read_data_in : std_ulogic_vector(15 downto 0);
    signal read_strobe_out : std_ulogic;
    signal read_ack_out : std_ulogic := '0';
    signal read_data_out : unsigned(15 downto 0) := X"0000";

    signal write_ack_in : std_ulogic;
    signal write_data_in : unsigned(15 downto 0) := X"0000";
    signal write_strobe_out : std_ulogic;
    signal write_ack_out : std_ulogic := '0';
    signal write_data_out : std_ulogic_vector(15 downto 0);

begin
    clk_in <= not clk_in after 2 ns;
    clk_out <= not clk_out after 2.57 ns;

    cross_clocks : entity work.cross_clocks port map (
        clk_in_i => clk_in,
        strobe_in_i => strobe_in,
        ack_in_o => ack_in,

        clk_out_i => clk_out,
        strobe_out_o => strobe_out,
        ack_out_i => ack_out
    );

    read : entity work.cross_clocks_read generic map (
        WIDTH => 16
    ) port map (
        clk_in_i => clk_in,
        strobe_i => strobe_in,
        ack_o => read_ack_in,
        data_o => read_data_in,

        clk_out_i => clk_out,
        strobe_o => read_strobe_out,
        ack_i => read_ack_out,
        data_i => std_ulogic_vector(read_data_out)
    );

    write : entity work.cross_clocks_write generic map (
        WIDTH => 16
    ) port map (
        clk_in_i => clk_in,
        strobe_i => strobe_in,
        ack_o => write_ack_in,
        data_i => std_ulogic_vector(write_data_in),

        clk_out_i => clk_out,
        strobe_o => write_strobe_out,
        ack_i => write_ack_out,
        data_o => write_data_out
    );

    -- Input process
    process
        procedure clk_wait(count : in natural := 1) is
        begin
            clk_wait(clk_in, count);
        end procedure;

        procedure transaction is
        begin
            strobe_in <= '1';
            clk_wait;
            strobe_in <= '0';
            while not ack_in loop
                clk_wait;
            end loop;
        end procedure;

    begin
        strobe_in <= '0';

        loop
            clk_wait(5);
            transaction;
        end loop;

        wait;
    end process;


    -- Data generation
    process (clk_out) begin
        if rising_edge(clk_out) then
            -- Continuously incrementing data
            read_data_out <= read_data_out + 1;
            write_data_in <= write_data_in + 1;

            -- Delay ack by one tick
            read_ack_out <= read_strobe_out;
            write_ack_out <= write_strobe_out;
        end if;
    end process;


    -- Output process
    process
        procedure clk_wait(count : in natural := 1) is
        begin
            clk_wait(clk_out, count);
        end procedure;

        variable ack_wait : natural := 0;
    begin
        ack_out <= '1';

        loop
            while not strobe_out loop
                clk_wait;
            end loop;
            clk_wait(ack_wait);
            ack_wait := ack_wait + 1;
            ack_out <= '1';
            clk_wait;
            ack_out <= '0';
        end loop;

        wait;
    end process;
end;
