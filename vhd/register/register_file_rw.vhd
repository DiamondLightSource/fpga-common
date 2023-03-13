-- Simple register file with readback

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.register_defs.all;

entity register_file_rw is
    port (
        clk_i : in std_ulogic;

        -- Register interface
        write_strobe_i : in std_ulogic_vector;
        write_data_i : in reg_data_array_t;
        write_ack_o : out std_ulogic_vector;
        -- Readback interface
        read_strobe_i : in std_ulogic_vector;
        read_data_o : out reg_data_array_t;
        read_ack_o : out std_ulogic_vector;

        -- Register array
        register_data_o : out reg_data_array_t
    );
end;

architecture arch of register_file_rw is
begin
    registers : entity work.register_file port map (
        clk_i => clk_i,

        write_strobe_i => write_strobe_i,
        write_data_i => write_data_i,
        write_ack_o => write_ack_o,

        register_data_o => register_data_o
    );

    -- Readback interface
    read_data_o <= register_data_o;
    read_ack_o <= (read_ack_o'RANGE => '1');
end;
