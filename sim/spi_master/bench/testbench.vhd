library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.support.all;

entity testbench is
end testbench;


architecture arch of testbench is
    signal clk : std_ulogic := '0';

    procedure clk_wait(count : in natural := 1) is
    begin
        for i in 1 to count loop
            wait until rising_edge(clk);
        end loop;
    end procedure;

    constant LOG_SCLK_DIVISOR : natural := 2;
--     constant ADDRESS_BITS : natural := 15;
--     constant DATA_BITS : natural := 8;
    constant ADDRESS_BITS : natural := 4;
    constant DATA_BITS : natural := 4;

    constant THREE_WIRE_BUS : boolean := true;

    -- Slave signals
    signal csn : std_ulogic;
    signal sclk : std_ulogic;
    signal slave_mosi : std_ulogic;
    signal slave_miso : std_ulogic;
    signal slave_miso_enable : std_ulogic;
    signal moen : std_ulogic;

    -- Master signals
    signal master_mosi : std_ulogic;
    signal master_miso : std_ulogic;
    signal master_mosi_enable : std_ulogic;

    -- Shared bus
    signal shared_data : std_logic := 'Z';

    -- Master control
    signal start : std_ulogic;
    signal r_wn : std_ulogic;
    signal command : std_ulogic_vector(ADDRESS_BITS-1 downto 0);
    signal data : std_ulogic_vector(DATA_BITS-1 downto 0);
    signal busy : std_ulogic;
    signal response : std_ulogic_vector(DATA_BITS-1 downto 0);

    procedure write(message : string := "") is
        variable linebuffer : line;
    begin
        write(linebuffer, message);
        writeline(output, linebuffer);
    end;

begin
    clk <= not clk after 2 ns;

    spi_slave : entity work.sim_spi_slave generic map (
        ADDRESS_BITS => ADDRESS_BITS,
        DATA_BITS => DATA_BITS
    ) port map (
        csn_i => csn,
        sclk_i => sclk,
        mosi_i => slave_mosi,
        miso_o => slave_miso,
        miso_enable_o => slave_miso_enable
    );


    spi_master : entity work.spi_master generic map (
        LOG_SCLK_DIVISOR => LOG_SCLK_DIVISOR,
        ADDRESS_BITS => ADDRESS_BITS,
        DATA_BITS => DATA_BITS
    ) port map (
        clk_i => clk,

        csn_o => csn,
        sclk_o => sclk,
        mosi_o => master_mosi,
        moen_o => master_mosi_enable,
        miso_i => master_miso,

        start_i => start,
        r_wn_i => r_wn,
        command_i => command,
        data_i => data,
        busy_o => busy,
        response_o => response
    );


    -- For three wire transfer need to go through common tri-stated shared bus
    gen_bus : if THREE_WIRE_BUS generate
        shared_data <= slave_miso when slave_miso_enable else 'Z';
        shared_data <= master_mosi when master_mosi_enable else 'Z';
        slave_mosi <= shared_data;
        master_miso <= to_x01(shared_data);
    else generate
        slave_mosi <= master_mosi;
        master_miso <= slave_miso;
    end generate;


    -- Test bench
    process
        function read_or_write(r_wn_in : std_ulogic) return string is
        begin
            if r_wn_in then
                return "R";
            else
                return "W";
            end if;
        end;

        procedure write_spi(
            r_wn_in : std_ulogic;
            command_in : natural;
            data_in : natural) is
        begin
            r_wn <= r_wn_in;
            command <= to_std_ulogic_vector_u(command_in, ADDRESS_BITS);
            data <= to_std_ulogic_vector_u(data_in, DATA_BITS);
            start <= '1';

            clk_wait;
            start <= '0';
            command <= (others => 'X');
            data <= (others => 'X');

            loop
                clk_wait;
                exit when not busy;
            end loop;

            write(
                "@ " & to_string(now, unit => ns) &
                " spi " & read_or_write(r_wn_in) & " " &
                to_string(command_in) & " " & to_string(data_in) &
                " => " & to_hstring(response));
        end;

    begin
        start <= '0';

        clk_wait(5);

        write_spi('0', 1, 2);
        write_spi('1', 1, 0);

        for n in 0 to 15 loop
            write_spi('0', n + 16, n);
        end loop;

        for n in 0 to 15 loop
            write_spi('1', n + 16, 0);
        end loop;

        wait;
    end process;
end;
