library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity testbench is
end testbench;

architecture arch of testbench is
    signal clk : std_ulogic := '0';

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

begin
    clk <= not clk after 1 ns;

    strobe_ack : entity work.strobe_ack port map (
        clk_i => clk,
        strobe_i => strobe_in,
        ack_o => ack_out,
        busy_i => busy,
        strobe_o => strobe_out
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
end;
