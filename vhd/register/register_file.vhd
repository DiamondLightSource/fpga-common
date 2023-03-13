-- Simple register file

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.register_defs.all;

entity register_file is
    port (
        clk_i : in std_ulogic;

        -- Register interface
        write_strobe_i : in std_ulogic_vector;
        write_data_i : in reg_data_array_t;
        write_ack_o : out std_ulogic_vector;

        -- Register array
        register_data_o : out reg_data_array_t
    );
end;

architecture arch of register_file is
    -- A small subtlety here: we use the write strobe range for the register
    -- file definition so that writes match correctly, but the register_data_o
    -- array is allowed to have a different range.
    signal register_file : reg_data_array_t(write_strobe_i'RANGE) :=
        (others => (others => '0'));

begin
    process (clk_i) begin
        if rising_edge(clk_i) then
            for r in write_strobe_i'RANGE loop
                if write_strobe_i(r) = '1' then
                    register_file(r) <= write_data_i(r);
                end if;
            end loop;
        end if;
    end process;

    register_data_o <= register_file;
    write_ack_o <= (write_ack_o'RANGE => '1');
end;
