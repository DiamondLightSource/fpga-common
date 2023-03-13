-- This is similar in behaviour to pulsed_bits, but is simpler to use: readout
-- always returns all changed bits and no associated write cycle is needed.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.register_defs.all;

entity register_events is
    generic (
        STICKY_BITS : reg_data_t := (others => '0')
    );
    port (
        clk_i : in std_ulogic;

        -- Control register interface
        read_strobe_i : in std_ulogic;
        read_data_o : out reg_data_t := (others => '0');
        read_ack_o : out std_ulogic := '0';

        -- Sticky bits aren't cleared unless this has been pulsed beforehand
        clear_sticky_i : in std_ulogic := '0';

        -- Input pulsed bits
        pulsed_bits_i : in reg_data_t
    );
end;

architecture arch of register_events is
    signal pulsed_bits_in : reg_data_t := (others => '0');
    signal pulsed_bits : reg_data_t := (others => '0');
    signal clear_sticky : std_ulogic := '0';

begin
    process (clk_i) begin
        if rising_edge(clk_i) then
            pulsed_bits_in <= pulsed_bits_i;

            if read_strobe_i = '1' then
                read_data_o <= pulsed_bits;
                if clear_sticky then
                    pulsed_bits <= pulsed_bits_in;
                else
                    pulsed_bits <=
                        pulsed_bits_in or (pulsed_bits and STICKY_BITS);
                end if;
                clear_sticky <= clear_sticky_i;
            else
                pulsed_bits <= pulsed_bits_in or pulsed_bits;
                clear_sticky <= clear_sticky or clear_sticky_i;
            end if;
            read_ack_o <= read_strobe_i;
        end if;
    end process;
end;
