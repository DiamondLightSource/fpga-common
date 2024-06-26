-- Transport a single bidirectional register across clock domain

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.register_defs.all;

entity register_cc is
    generic (
        -- Should match period of the fastest clock frequency
        MAX_DELAY : real := 4.0
    );
    port (
        clk_in_i : in std_ulogic;       -- Master clock
        clk_out_i : in std_ulogic;      -- Slave clock
        -- clk_out status on clk_in domain.  If this is '0' then all register
        -- transactions will be unconditionally completed to avoid stalls.
        clk_out_ok_i : in std_ulogic := '1';

        -- Master clock domain (on clk_in_i)
        write_data_i : in reg_data_array_t;
        write_strobe_i : in std_ulogic_vector;
        write_ack_o : out std_ulogic_vector;

        read_data_o : out reg_data_array_t;
        read_strobe_i : in std_ulogic_vector;
        read_ack_o : out std_ulogic_vector;

        -- Slave clock domain (on clk_out_i)
        write_data_o : out reg_data_array_t;
        write_strobe_o : out std_ulogic_vector;
        write_ack_i : in std_ulogic_vector;

        read_data_i : in reg_data_array_t;
        read_strobe_o : out std_ulogic_vector;
        read_ack_i : in std_ulogic_vector
    );
end;

architecture arch of register_cc is
begin
    gen_write : for i in write_strobe_i'RANGE generate
        write : entity work.cross_clocks_write generic map (
            MAX_DELAY => MAX_DELAY
        ) port map (
            clk_in_i => clk_in_i,
            clk_out_ok_i => clk_out_ok_i,
            strobe_i => write_strobe_i(i),
            ack_o => write_ack_o(i),
            data_i => write_data_i(i),

            clk_out_i => clk_out_i,
            strobe_o => write_strobe_o(i),
            ack_i => write_ack_i(i),
            data_o => write_data_o(i)
        );
    end generate;

    gen_read : for i in read_strobe_i'RANGE generate
        read : entity work.cross_clocks_read generic map (
            MAX_DELAY => MAX_DELAY
        ) port map (
            clk_in_i => clk_in_i,
            clk_out_ok_i => clk_out_ok_i,
            strobe_i => read_strobe_i(i),
            ack_o => read_ack_o(i),
            data_o => read_data_o(i),

            clk_out_i => clk_out_i,
            strobe_o => read_strobe_o(i),
            ack_i => read_ack_i(i),
            data_i => read_data_i(i)
        );
    end generate;
end;
