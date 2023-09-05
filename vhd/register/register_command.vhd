-- Converts write to a register into an array of strobed bits

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.register_defs.all;

entity register_command is
    port (
        clk_i : in std_ulogic;

        -- Control register interface
        write_strobe_i : in std_ulogic;
        write_data_i : in reg_data_t;
        write_ack_o : out std_ulogic := '0';

        -- Output strobed bits
        strobed_bits_o : out reg_data_t;
        -- Optional acknowledge per strobed bit
        strobed_ack_i : in reg_data_t := (others => '1')
    );
end;

architecture arch of register_command is
    signal strobed_bits : reg_data_t := (others => '0');
    signal busy_bits : reg_data_t := (others => '0');
    signal need_ack_bits : reg_data_t;
    signal unacked_bits : reg_data_t;
    signal ack_ready : std_ulogic;

begin
    need_ack_bits <= write_data_i when write_strobe_i else busy_bits;
    unacked_bits <= need_ack_bits and not strobed_ack_i;
    ack_ready <= not vector_or(unacked_bits);
    process (clk_i) begin
        if rising_edge(clk_i) then
            strobed_bits <= write_strobe_i and write_data_i;
            busy_bits <= unacked_bits;

            if write_strobe_i then
                write_ack_o <= ack_ready;
            else
                write_ack_o <= vector_or(busy_bits) and ack_ready;
            end if;
        end if;
    end process;
    strobed_bits_o <= strobed_bits;
end;
