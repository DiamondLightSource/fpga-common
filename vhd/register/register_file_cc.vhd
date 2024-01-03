-- Simple register file with clock domain crossing for registered data

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.register_defs.all;

entity register_file_cc is
    port (
        clk_reg_i : in std_ulogic;

        -- Register interface
        write_strobe_i : in std_ulogic_vector;
        write_data_i : in reg_data_array_t;
        write_ack_o : out std_ulogic_vector;
        -- Data domain clock status synchronised to register clock domain
        clk_data_ok_i : in std_ulogic := '1';

        -- Register array on data clock domain
        clk_data_i : in std_ulogic;
        register_data_o : out reg_data_array_t;
        data_strobe_o : out std_ulogic_vector
    );
end;

architecture arch of register_file_cc is
    signal register_data : reg_data_array_t(write_strobe_i'RANGE);

begin
    gen_regs : for i in write_strobe_i'RANGE generate
        cc : entity work.cross_clocks_write port map (
            clk_in_i => clk_reg_i,
            clk_out_ok_i => clk_data_ok_i,
            strobe_i => write_strobe_i(i),
            ack_o => write_ack_o(i),
            data_i => write_data_i(i),

            clk_out_i => clk_data_i,
            strobe_o => data_strobe_o(i),
            data_o => register_data(i)
        );
    end generate;

    -- This separate assignment allows the register data to have a different
    -- index range from the register interface, which is sometimes useful.
    register_data_o <= register_data;
end;
