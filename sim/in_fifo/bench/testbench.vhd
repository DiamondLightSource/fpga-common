library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.textio.all;
use ieee.math_real.all;

entity testbench is
end testbench;

architecture arch of testbench is
    constant FIFO_WIDTH : natural := 8;
    -- Scaling for random variation of clock in ps
    constant RANDOM_SCALE : real := 1200.0;

    signal clock_delay : real := 0.0;   -- Delay in ns
    signal clock_skew : time := 0 ps;

    signal clk_in : std_ulogic := '0';
    signal clk_out : std_ulogic := '0';
    signal data_in : unsigned(FIFO_WIDTH-1 downto 0)
        := (others => '0');
    signal last_data_out : unsigned(FIFO_WIDTH-1 downto 0)
        := (others => '0');
    signal data_out : unsigned(FIFO_WIDTH-1 downto 0);
    signal delta : signed(FIFO_WIDTH-1 downto 0) := (others => '0');
    signal reset : std_ulogic := '0';
    signal error_out : std_ulogic;

    signal tick_counter : natural := 0;
    signal reset_counter : natural := 20;

begin
    clk_out <= not clk_out after 2 ns;
    clk_in <= transport clk_out after
        1 ps * integer(1.0e3 * clock_delay) + clock_skew;

    fifo : entity work.in_fifo generic map (
        FIFO_WIDTH => FIFO_WIDTH
    ) port map (
        clk_in_i => clk_in,
        data_i => std_ulogic_vector(data_in),

        clk_out_i => clk_out,
        unsigned(data_o) => data_out,
        reset_i => reset,
        error_o => error_out
    );


    -- Data generation and clk_in random skew generation
    process (clk_in)
        variable seed1, seed2 : positive := 1;
        variable random : real;
    begin
        uniform(seed1, seed2, random);
        clock_skew <= integer(random * RANDOM_SCALE) * 1 ps;

        if rising_edge(clk_in) then
            data_in <= data_in + 1;
        end if;
    end process;


    -- Data readout and checking
    process (clk_out)
        variable linebuffer : line;
    begin
        if rising_edge(clk_out) then
            last_data_out <= data_out;
            delta <= signed(data_out - last_data_out);

            if reset then
                reset_counter <= 15;
            elsif reset_counter > 0 then
                reset_counter <= reset_counter - 1;
            elsif delta /= 1 then
                write(linebuffer,
                    "@" & to_string(tick_counter) &
                    " delta = " & to_string(to_integer(delta)));
                writeline(output, linebuffer);
            end if;
            tick_counter <= tick_counter + 1;
        end if;
    end process;


    -- Exercise FIFO
    process
        -- Setting this to 0.3 generates no errors, but to test error reporting
        -- this is set to 0.4
        constant DELAY_STEP : real := 0.4;

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
        clock_delay <= 50.0;

        clk_wait(10);

        reset_fifo;

        loop
            -- Run with default clock
            clk_wait(50);

            -- Now let's mess with the clock delay
            for n in 0 to 40 loop
                clk_wait(5);
                clock_delay <= clock_delay + DELAY_STEP;
            end loop;

            clk_wait(50);
            -- Reset the FIFO again
            reset_fifo;
            clk_wait(50);

            -- Bring the delay back down again
            for n in 0 to 40 loop
                clk_wait(5);
                clock_delay <= clock_delay - DELAY_STEP;
            end loop;
        end loop;

        wait;
    end process;
end;
