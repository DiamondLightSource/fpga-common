-- Captures both status bits and transient events

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.register_defs.all;

entity register_status is
    generic (
        -- Any event bits identified in this mask need to be cleared by pulsing
        -- clear_sticky_i before or when reading
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

        -- Status bits
        status_bits_i : in reg_data_t;
        -- Event bits
        event_bits_i : in reg_data_t
    );
end;

architecture arch of register_status is
    signal clear_sticky : std_ulogic := '0';
    signal event_bits : reg_data_t := (others => '0');

begin
    process (clk_i) begin
        if rising_edge(clk_i) then
            -- Return combination of event bits and status bits, only one of
            -- each input is expected to be set
            if read_strobe_i then
                read_data_o <= event_bits or status_bits_i;
            end if;
            read_ack_o <= read_strobe_i;

            -- Manage event bits: clear the non sticky ones on readout,
            -- otherwise accumulate event bits
            if read_strobe_i then
                if clear_sticky or clear_sticky_i then
                    event_bits <= event_bits_i;
                else
                    event_bits <= event_bits_i or (event_bits and STICKY_BITS);
                end if;
            else
                event_bits <= event_bits or event_bits_i;
            end if;

            if read_strobe_i then
                clear_sticky <= '0';
            elsif clear_sticky_i then
                clear_sticky <= '1';
            end if;
        end if;
    end process;
end;
