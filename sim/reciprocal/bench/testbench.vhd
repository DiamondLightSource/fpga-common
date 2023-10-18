library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use ieee.math_real.all;

use work.support.all;

entity testbench is
end testbench;

architecture arch of testbench is
    signal clk : std_ulogic := '0';

    procedure clk_wait is
    begin
        wait until rising_edge(clk);
    end procedure;

    constant PROCESS_DELAY : natural := 10;

    signal data_in : unsigned(23 downto 0) := (others => '0');
    signal shift_out : unsigned(4 downto 0);
    signal data_out : unsigned(23 downto 0);
    signal zero_out : std_ulogic;

    signal data_in_delay : unsigned(23 downto 0);
    signal error_result : signed(23 downto 0);

    constant MAX_ERROR : natural := 1;
    signal ok : boolean := true;
    signal all_ok : boolean := true;

begin
    clk <= not clk after 2 ns;

    reciprocal : entity work.reciprocal generic map (
        PROCESS_DELAY => PROCESS_DELAY
    ) port map (
        clk_i => clk,
        data_i => data_in,
        shift_o => shift_out,
        data_o => data_out,
        zero_o => zero_out
    );

    delay : entity work.fixed_delay generic map (
        DELAY => PROCESS_DELAY,
        WIDTH => 24
    ) port map (
        clk_i => clk,
        data_i => std_ulogic_vector(data_in),
        unsigned(data_o) => data_in_delay
    );

    results : process (data_in_delay, data_out, shift_out)
        variable raw_product : unsigned(47 downto 0);
        variable full_corrected_product : unsigned(47 downto 0);
        variable corrected_product : unsigned(23 downto 0);
        variable difference : signed(23 downto 0);
        variable difference_ok : boolean;

    begin
        raw_product := data_in_delay * data_out;
        full_corrected_product :=
            shift_left(raw_product, to_integer(shift_out));
        corrected_product := full_corrected_product(47 downto 24);
        difference :=
            signed(not corrected_product(23) & corrected_product(22 downto 0));
        difference_ok :=
            abs(to_integer(difference)) <= MAX_ERROR or data_in_delay = 0;

        error_result <= difference;
        ok <= difference_ok;
        if not difference_ok then
            all_ok <= false;
        end if;
    end process;

    process
        procedure test(test_data : unsigned(23 downto 0)) is
        begin
            clk_wait;
            data_in <= test_data;
        end;

        variable seed1 : positive := 1;
        variable seed2 : positive := 1;
        variable rand : real;

    begin
        clk_wait;

        test(X"AD87BB");
        test(X"201A02");
        test(X"806808");
        test(X"800000");
        test(X"800001");
        test(X"800002");

        test(X"E00000");
        test(X"700000");
        test(X"380000");
        test(X"1C0000");
        test(X"0E0000");
        test(X"00000E");
        test(X"000007");

        test(X"000001");

        test(X"E12345");
        test(13X"1C24" & 11X"345");
        test(13X"1C24" & 11X"6FF");
        test(13X"1C24" & 11X"700");
        test(13X"1C24" & 11X"7FF");

        test(X"7FFFFF");
        test(X"7FF000");
        test(X"7FF800");
        test(X"800001");
        test(X"800002");
        test(X"800004");
        test(X"8006FF");
        test(X"8007FF");

        -- Now some random numbers
        loop
            uniform(seed1, seed2, rand);
            test(to_unsigned(integer(floor(rand * 16777216.0)), 24));
        end loop;

        wait;
    end process;
end;
