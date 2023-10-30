-- Simple pulse stretching
--
-- Stretches an array of clock pulses to the length specified by DELAY

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity stretch_pulse is
    generic (
        DELAY : natural := 31;
        WIDTH : natural := 1
    );
    port (
        clk_i : in std_ulogic;
        pulse_i : in std_ulogic_vector(WIDTH-1 downto 0);
        pulse_o : out std_ulogic_vector(WIDTH-1 downto 0) := (others => '0')
    );
end;

architecture arch of stretch_pulse is
    signal pulse_delay : std_ulogic_vector(WIDTH-1 downto 0);
    signal pulse_out : pulse_o'SUBTYPE := (others => '0');

begin
    delayline : entity work.fixed_delay generic map (
        DELAY => DELAY,
        WIDTH => WIDTH
    ) port map (
        clk_i => clk_i,
        data_i => pulse_i,
        data_o => pulse_delay
    );

    process (clk_i) begin
        if rising_edge(clk_i) then
            for i in WIDTH-1 downto 0 loop
                if pulse_i(i) then
                    pulse_out(i) <= '1';
                elsif pulse_delay(i) then
                    pulse_out(i) <= '0';
                end if;
            end loop;
            pulse_o <= pulse_out;
        end if;
    end process;
end;
