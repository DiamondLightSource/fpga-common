library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use ieee.math_real.all;

use work.support.all;
use work.nco_defs.all;

entity testbench is
end testbench;


architecture arch of testbench is
    procedure clk_wait(signal clk_i : in std_ulogic; count : in natural) is
        variable i : natural;
    begin
        for i in 0 to count-1 loop
            wait until rising_edge(clk_i);
        end loop;
    end procedure;


    signal clk : std_ulogic := '0';


    procedure tick_wait(count : natural := 1) is
    begin
        clk_wait(clk, count);
    end procedure;

    signal phase_advance : angle_t;
    signal reset_phase : std_ulogic;
    signal unscaled : cos_sin_18_t;

    signal reference : cos_sin_18_t;
    signal difference : cos_sin_18_t;
    signal enable_check : boolean := false;
    signal sim_error : boolean;

    signal scaled_cos : real := 0.0;
    signal scaled_sin : real := 0.0;
    signal magnitude : real := 1.0;
    signal magnitude_error : real := 0.0;

    -- This delay must match the NCO core delay.  This is the sum of
    -- LOOKUP_DELAY and REFINE_DELAY defined in nco_core plus any delay added
    -- by nco_cos_sin_prepare and nco_cos_sin_octant.
    constant PROCESS_DELAY : natural := 16;

begin
    clk <= not clk after 1 ns;

    nco : entity work.nco_core generic map (
        PROCESS_DELAY => PROCESS_DELAY
    ) port map (
        clk_i => clk,
        phase_advance_i => phase_advance,
        reset_phase_i => reset_phase,
        cos_sin_o => unscaled
    );


    -- Compare simulation with reference
    sim_nco : entity work.sim_nco generic map (
        PROCESS_DELAY => PROCESS_DELAY
    ) port map (
        clk_i => clk,
        phase_advance_i => phase_advance,
        reset_phase_i => reset_phase,
        cos_sin_o => reference
    );
    process (clk) begin
        if enable_check then
            difference.cos <= unscaled.cos - reference.cos;
            difference.sin <= unscaled.sin - reference.sin;
            sim_error <= abs(difference.cos) > 1 or abs(difference.sin) > 1;
            magnitude <=
                sqrt(scaled_cos * scaled_cos + scaled_sin * scaled_sin);
        end if;
    end process;
    scaled_cos <= real(to_integer(unscaled.cos)) / real(16#1FFFC#);
    scaled_sin <= real(to_integer(unscaled.sin)) / real(16#1FFFC#);
    magnitude_error <= real(16#1FFFC#) * (magnitude - 1.0);

    -- Sweeping through frequencies
    process begin
        phase_advance <= X"001234560000";
        reset_phase <= '1';
        tick_wait(2);
        reset_phase <= '0';
        -- We delay checking the result until startup artifacts have finishing
        -- bubbling through the processing chain.
        tick_wait(12);
        enable_check <= true;

        for i in 1 to 10 loop
            tick_wait(60);
            phase_advance <= shift_left(phase_advance, 1);
        end loop;

        phase_advance <= X"000000000000";
        reset_phase <= '1';
        tick_wait;
        reset_phase <= '0';
        tick_wait;

        phase_advance <= X"147AE1000000";
        wait;
    end process;
end;
