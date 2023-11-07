-- Simple pulse stretching
--
-- Lengthens pulse_i by DELAY extra ticks
--
-- Note that if pulse_i retriggers before pulse_o is complete it is possible for
-- unstretched pulses to be generated

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity stretch_pulse is
    generic (
        DELAY : natural := 31;
        REGISTER_OUT : boolean := true
    );
    port (
        clk_i : in std_ulogic;
        pulse_i : in std_ulogic;
        pulse_o : out std_ulogic
    );
end;

architecture arch of stretch_pulse is
    signal pulse_delay : std_ulogic;
    signal pulse : std_ulogic;
    signal stretch : std_ulogic := '0';
    signal pulse_out : std_ulogic := '0';

begin
    delayline : entity work.fixed_delay generic map (
        DELAY => DELAY
    ) port map (
        clk_i => clk_i,
        data_i(0) => pulse_i,
        data_o(0) => pulse_delay
    );

    -- Stretch the pulse.  The stretch flag extends the pulse until the delayed
    -- pulse is seen: this is only useful when the incoming pulse is shorter
    -- than the requested delay.
    pulse <= pulse_i or stretch or pulse_delay;

    process (clk_i) begin
        if rising_edge(clk_i) then
            if pulse_delay then
                stretch <= '0';
            elsif pulse_i then
                stretch <= '1';
            end if;
            pulse_out <= pulse;
        end if;
    end process;

    gen_out : if REGISTER_OUT generate
        pulse_o <= pulse_out;
    else generate
        pulse_o <= pulse;
    end generate;
end;
