library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.support.all;

entity testbench is
end testbench;

architecture arch of testbench is
    constant CORDIC_BITS : natural := 25;
    constant ANGLE_BITS : natural := CORDIC_BITS / 2;
    subtype CORDIC_RANGE is natural range CORDIC_BITS-1 downto 0;
    subtype ANGLE_RANGE is natural range ANGLE_BITS-1 downto 0;

    constant PROCESS_DELAY : natural := CORDIC_BITS / 2 + 1;

    function mag_scaling return real is
        variable scale : real := 1.0;
    begin
        for n in 1 to CORDIC_BITS / 2 loop
            scale := scale * (1.0 + 2.0**(-2 * n));
        end loop;
        return sqrt(scale);
    end;


    signal clk : std_ulogic := '0';

    signal x_in : signed(CORDIC_RANGE) := (others => '0');
    signal y_in : signed(CORDIC_RANGE) := (others => '0');

    signal valid_out : std_ulogic := '0';
    signal mag_out : unsigned(CORDIC_RANGE);
    signal angle_out : signed(ANGLE_RANGE);

    signal phase : real := 0.0;
    signal frequency : real := 0.1;
    signal magnitude : real := 1.0;
    signal counter : natural := 0;
    signal magnitude_scaling : real := 1.0;

    constant data_scaling : real := 2.0 ** (CORDIC_BITS-1) - 1.0;

    signal true_mag : unsigned(CORDIC_RANGE) := (others => '0');
    signal true_mag_delay : unsigned_array(0 to PROCESS_DELAY)(CORDIC_RANGE)
        := (others => (others => '0'));
    signal mag_error : signed(CORDIC_RANGE);

    signal true_angle : signed(ANGLE_RANGE) := (others => '0');
    signal true_angle_delay : signed_array(0 to PROCESS_DELAY)(ANGLE_RANGE)
        := (others => (others => '0'));
    signal angle_error : signed(ANGLE_RANGE);

begin
    clk <= not clk after 2 ns;

    cordic : entity work.cordic_pl generic map (
        ANGLE_WIDTH => angle_out'LENGTH,
        PROCESS_DELAY => PROCESS_DELAY
    ) port map (
        clk_i => clk,
        x_i => x_in,
        y_i => y_in,
        mag_o => mag_out,
        angle_o => angle_out
    );


    -- Generate input data
    process (clk)
        function to_signed(x : real) return signed is
        begin
            return to_signed(integer(x * data_scaling), CORDIC_BITS);
        end;

        function to_unsigned(x : real) return unsigned is
        begin
            return to_unsigned(integer(x * data_scaling), CORDIC_BITS);
        end;

    begin
        if rising_edge(clk) then
            x_in <= to_signed(magnitude * cos(phase));
            y_in <= to_signed(magnitude * sin(phase));
            true_mag_delay(0) <= to_unsigned(magnitude * mag_scaling);
            true_angle_delay(0) <= to_signed(integer(
                phase / MATH_PI * 2.0**(ANGLE_BITS-1)), ANGLE_BITS);

            if counter > 50 then
                magnitude_scaling <= 0.99;
            end if;

            counter <= counter + 1;
            phase <= phase + frequency;
            magnitude <= magnitude_scaling * magnitude;
        end if;
    end process;

    gen_delay : for i in 1 to PROCESS_DELAY generate
        process (clk) begin
            if rising_edge(clk) then
                true_mag_delay(i) <= true_mag_delay(i-1);
                true_angle_delay(i) <= true_angle_delay(i-1);
            end if;
        end process;
    end generate;

    valid_out <= '1' after 54 ns;
    true_mag <= true_mag_delay(PROCESS_DELAY);
    true_angle <= true_angle_delay(PROCESS_DELAY);
    mag_error <= signed(mag_out - true_mag);
    angle_error <= angle_out - true_angle when valid_out else (others => '0');
end;
