-- Register that updates every time it is read

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.register_defs.all;

entity test_counter is
    port (
        clk_i : in std_ulogic;

        write_strobe_i : in std_ulogic;
        write_data_i : in reg_data_t;
        write_ack_o : out std_ulogic := '0';
        read_strobe_i : in std_ulogic;
        read_data_o : out reg_data_t;
        read_ack_o : out std_ulogic := '0'
    );
end;

architecture arch of test_counter is
    signal counter : unsigned(31 downto 0) := (others => '0');

begin
    process (clk_i) begin
        if rising_edge(clk_i) then
            if read_strobe_i then
                read_data_o <= std_ulogic_vector(counter);
                counter <= counter + 1;
            elsif write_strobe_i then
                counter <= unsigned(write_data_i);
            end if;
            read_ack_o <= read_strobe_i;
            write_ack_o <= write_strobe_i;
        end if;
    end process;
end;
