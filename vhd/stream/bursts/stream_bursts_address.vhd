-- Address generator for bursts

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.axi_defs.all;

entity stream_bursts_address is
    port (
        clk_i : in std_ulogic;

        -- Should be strobed at start of capture to reset address.
        reset_address_i : in std_ulogic;
        -- Advance to next address (and written to address FIFO)
        advance_address_i : in std_ulogic;

        -- Generated address
        address_o : out unsigned;

        -- Range of capture addresses.
        first_address_i : in unsigned;
        last_address_i : in unsigned;

        -- Address of the currently written burst, updated when address is
        -- advanced
        count_sent_o : out std_ulogic;
        capture_address_o : out unsigned
    );
end;

architecture arch of stream_bursts_address is
    signal write_address : address_o'SUBTYPE;

begin
    process (clk_i) begin
        if rising_edge(clk_i) then
            -- Address management: reset before start of capture, otherwise
            -- advance from first to last address in cycles
            if advance_address_i then
                capture_address_o <= write_address;
                if write_address = last_address_i then
                    write_address <= first_address_i;
                else
                    write_address <= write_address + 1;
                end if;
            elsif reset_address_i then
                write_address <= first_address_i;
            end if;
            count_sent_o <= advance_address_i;
        end if;
    end process;

    address_o <= write_address;
end;
