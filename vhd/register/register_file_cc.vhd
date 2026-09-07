-- Simple register file with clock domain crossing for registered data

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.register_defs.all;

entity register_file_cc is
    generic (
        -- Should match period of the fastest clock frequency
        MAX_DELAY : real := 4.0
    );
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
        register_data_o : out reg_data_array_t
    );
end;

architecture arch of register_file_cc is
    -- Data to write using write range
    signal register_strobe : std_ulogic_vector(write_strobe_i'RANGE);
    signal register_data : reg_data_array_t(write_strobe_i'RANGE);

    -- Data to return using read range.
    -- This separate assignment allows the register data to have a different
    -- index range from the register interface, which can be invaluable.
    signal register_strobe_remap : std_ulogic_vector(register_data_o'RANGE);
    signal register_data_remap : register_data_o'SUBTYPE;
    signal register_data_out : register_data_o'SUBTYPE
        := (others => (others => '0'));

begin
    gen_regs : for i in write_strobe_i'RANGE generate
        cc : entity work.cross_clocks_write generic map (
            MAX_DELAY => MAX_DELAY
        ) port map (
            clk_in_i => clk_reg_i,
            clk_out_ok_i => clk_data_ok_i,
            strobe_i => write_strobe_i(i),
            ack_o => write_ack_o(i),
            data_i => write_data_i(i),

            clk_out_i => clk_data_i,
            strobe_o => register_strobe(i),
            data_o => register_data(i)
        );
    end generate;

    -- Remap returned data onto output range
    register_strobe_remap <= register_strobe;
    register_data_remap <= register_data;

    -- Register data on new clock domain
    process (clk_data_i) begin
        if rising_edge(clk_data_i) then
            for i in register_data_o'RANGE loop
                if register_strobe_remap(i) then
                    register_data_out(i) <= register_data_remap(i);
                end if;
            end loop;
        end if;
    end process;
    register_data_o <= register_data_out;
end;
