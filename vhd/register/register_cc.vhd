-- Transport a single bidirectional register across clock domain

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.register_defs.all;

entity register_cc is
    port (
        clk_in_i : in std_ulogic;       -- Master clock
        clk_out_i : in std_ulogic;      -- Slave clock
        -- clk_out status on clk_in domain.  If this is '0' then all register
        -- transactions will be unconditionally completed to avoid stalls.
        clk_out_ok_i : in std_ulogic := '1';

        -- Master clock domain (on clk_in_i)
        write_data_i : in reg_data_t;
        write_strobe_i : in std_ulogic;
        write_ack_o : out std_ulogic;

        read_data_o : out reg_data_t;
        read_strobe_i : in std_ulogic;
        read_ack_o : out std_ulogic;

        -- Slave clock domain (on clk_out_i)
        write_data_o : out reg_data_t;
        write_strobe_o : out std_ulogic;
        write_ack_i : in std_ulogic;

        read_data_i : in reg_data_t;
        read_strobe_o : out std_ulogic;
        read_ack_i : in std_ulogic
    );
end;

architecture arch of register_cc is
    subtype EMPTY_RANGE is natural range -1 downto 0;
    constant EMPTY_VALUE : unsigned := (EMPTY_RANGE => '0');

begin
    register_cc : entity work.register_bank_cc port map (
        clk_in_i => clk_in_i,
        clk_out_i => clk_out_i,
        clk_out_ok_i => clk_out_ok_i,

        write_address_i => EMPTY_VALUE,
        write_data_i => write_data_i,
        write_strobe_i => write_strobe_i,
        write_ack_o => write_ack_o,
        read_address_i => EMPTY_VALUE,
        read_data_o => read_data_o,
        read_strobe_i => read_strobe_i,
        read_ack_o => read_ack_o,

        write_address_o(EMPTY_RANGE) => open,
        write_data_o => write_data_o,
        write_strobe_o => write_strobe_o,
        write_ack_i => write_ack_i,
        read_address_o(EMPTY_RANGE) => open,
        read_data_i => read_data_i,
        read_strobe_o => read_strobe_o,
        read_ack_i => read_ack_i
    );
end;
