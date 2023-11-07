library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity testbench is
end testbench;

architecture arch of testbench is
    signal clk : std_ulogic := '1';

    procedure clk_wait(count : in natural := 1) is
    begin
        for i in 0 to count-1 loop
            wait until rising_edge(clk);
        end loop;
    end procedure;

    signal strobe_in : std_ulogic;
    signal ack_out : std_ulogic;
    signal busy : std_ulogic;
    signal strobe_out : std_ulogic;

    signal pulse_in : std_ulogic := '0';
    signal pulse_0 : std_ulogic;
    signal pulse_0r : std_ulogic;
    signal pulse_1 : std_ulogic;
    signal pulse_2 : std_ulogic;
    signal pulse_10 : std_ulogic;

begin
    clk <= not clk after 1 ns;

    strobe_ack : entity work.strobe_ack port map (
        clk_i => clk,
        strobe_i => strobe_in,
        ack_o => ack_out,
        busy_i => busy,
        strobe_o => strobe_out
    );

    stretch_0 : entity work.stretch_pulse generic map (
        DELAY => 0,
        REGISTER_OUT => false
    ) port map (
        clk_i => clk,
        pulse_i => pulse_in,
        pulse_o => pulse_0
    );

    stretch_0r : entity work.stretch_pulse generic map (
        DELAY => 0,
        REGISTER_OUT => true
    ) port map (
        clk_i => clk,
        pulse_i => pulse_in,
        pulse_o => pulse_0r
    );

    stretch_1 : entity work.stretch_pulse generic map (
        DELAY => 1,
        REGISTER_OUT => false
    ) port map (
        clk_i => clk,
        pulse_i => pulse_in,
        pulse_o => pulse_1
    );

    stretch_2 : entity work.stretch_pulse generic map (
        DELAY => 2,
        REGISTER_OUT => false
    ) port map (
        clk_i => clk,
        pulse_i => pulse_in,
        pulse_o => pulse_2
    );

    stretch_10 : entity work.stretch_pulse generic map (
        DELAY => 10,
        REGISTER_OUT => false
    ) port map (
        clk_i => clk,
        pulse_i => pulse_in,
        pulse_o => pulse_10
    );

    process begin
        strobe_in <= '0';
        busy <= '0';
        clk_wait(2);

        -- Strobe when idle is passed straight through
        strobe_in <= '1';
        clk_wait;
        strobe_in <= '0';
        clk_wait(2);

        strobe_in <= '1';
        busy <= '1';
        clk_wait;
        strobe_in <= '0';
        clk_wait(2);

        busy <= '0';

        wait;
    end process;

    process
        procedure pulse(width : natural; pause : natural) is
        begin
            pulse_in <= '1';
            clk_wait(width);
            pulse_in <= '0';
            clk_wait(pause);
        end;
    begin
        pulse_in <= '0';
        clk_wait(2);

        pulse(1, 20);
        pulse(2, 20);
        pulse(3, 20);
        pulse(4, 20);
        pulse(10, 20);
        pulse(10, 20);

        clk_wait(10);

        pulse(1, 1);
        pulse(1, 1);
        pulse(1, 1);

        wait;
    end process;
end;
