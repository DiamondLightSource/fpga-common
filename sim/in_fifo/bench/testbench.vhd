library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use ieee.math_real.all;

entity testbench is
end testbench;

architecture arch of testbench is
    constant FIFO_WIDTH : natural := 8;
    -- Scaling for random variation of clock in ps
    constant RANDOM_SCALE : real := 1000.0;

    signal clock_delay : time := 1 ns;
    signal clock_skew : time := 0 ps;

    signal clk_in : std_ulogic := '0';
    signal clk_out : std_ulogic := '0';
    signal data_in : std_ulogic_vector(FIFO_WIDTH-1 downto 0)
        := (others => '0');
    signal last_data_out : std_ulogic_vector(FIFO_WIDTH-1 downto 0)
        := (others => '0');
    signal data_out : std_ulogic_vector(FIFO_WIDTH-1 downto 0);
    signal delta : unsigned(FIFO_WIDTH-1 downto 0) := (others => '0');
    signal reset : std_ulogic := '0';
    signal depth : unsigned(2 downto 0);
    signal nearly_empty : std_ulogic;
    signal empty : std_ulogic;
    signal nearly_full : std_ulogic;
    signal full : std_ulogic;

begin
    clk_out <= not clk_out after 2 ns;
    clk_in <= transport clk_out after clock_delay + clock_skew;

    fifo : entity work.in_fifo generic map (
        FIFO_WIDTH => FIFO_WIDTH
    ) port map (
        clk_in_i => clk_in,
        data_i => data_in,

        clk_out_i => clk_out,
        data_o => data_out,

        reset_i => reset,

        depth_o => depth,
        nearly_empty_o => nearly_empty,
        empty_o => empty,
        nearly_full_o => nearly_full,
        full_o => full
    );

    -- Data generation and clk_in skew generation
    process (clk_in)
        variable seed1, seed2 : positive := 1;
        variable random : real;
    begin
        uniform(seed1, seed2, random);
        clock_skew <= integer(random * RANDOM_SCALE) * 1 ps;

        if rising_edge(clk_in) then
            data_in <= std_ulogic_vector(signed(data_in) + 1);
        end if;
    end process;

    -- Data readout
    process (clk_out) begin
        if rising_edge(clk_out) then
            last_data_out <= data_out;
            delta <= unsigned(data_out) - unsigned(last_data_out);

            if delta /= 1 then
                report "Delta = " & to_string(delta);
            end if;
        end if;
    end process;


    -- Exercise FIFO
    process
        procedure clk_wait(delay : natural := 1) is
        begin
            for i in 1 to delay loop
                wait until rising_edge(clk_out);
            end loop;
        end;

        procedure reset_fifo is
        begin
            reset <= '1';
            clk_wait;
            reset <= '0';
        end;

    begin
        reset <= '0';
        clock_delay <= 5 ns;

        clk_wait(10);

        reset_fifo;

        -- Now let's mess with the clock delay
        for n in 0 to 80 loop
            clk_wait(5);
            clock_delay <= n * 800 ps;
        end loop;

        -- Reset the FIFO again
        reset_fifo;

        wait;
    end process;
end;
