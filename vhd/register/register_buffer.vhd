-- Buffer for register interface

-- Simple register buffering, relies on the following protocol rules for read
-- and write acknowledgements:
--
-- Either:
--      ack must always '1', in which case writes can never be blocked, and
--      the value returned from read must not depend on the strobe
-- Or:
--      ack must always be '0' except in direct response to a strobe.
--
-- These rules allow simple buffering without flow control.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.register_defs.all;

entity register_buffer is
    generic (
        BUFFER_DEPTH : natural := 1
    );
    port (
        clk_i : in std_ulogic;

        -- Write interface
        -- in
        write_strobe_i : in std_ulogic_vector;
        write_data_i : in reg_data_array_t;
        write_ack_o : out std_ulogic_vector;
        -- out
        write_strobe_o : out std_ulogic_vector;
        write_data_o : out reg_data_array_t;
        write_ack_i : in std_ulogic_vector;

        -- Read interface
        -- in
        read_data_o : out reg_data_array_t;
        read_strobe_i : in std_ulogic_vector;
        read_ack_o : out std_ulogic_vector;
        -- out
        read_data_i : in reg_data_array_t;
        read_strobe_o : out std_ulogic_vector;
        read_ack_i : in std_ulogic_vector
    );
end;

architecture arch of register_buffer is
begin
    write_strobe : entity work.dlyreg generic map (
        WIDTH => write_strobe_i'LENGTH,
        DELAY => BUFFER_DEPTH
    ) port map (
        clk_i => clk_i,

        data_i => write_strobe_i,
        data_o => write_strobe_o
    );

    write_ack : entity work.dlyreg generic map (
        WIDTH => write_ack_i'LENGTH,
        DELAY => BUFFER_DEPTH
    ) port map (
        clk_i => clk_i,

        data_i => write_ack_i,
        data_o => write_ack_o
    );

    gen_write : for i in write_data_i'RANGE generate
        write_data : entity work.dlyreg generic map (
            WIDTH => REG_DATA_WIDTH,
            DELAY => BUFFER_DEPTH
        ) port map (
            clk_i => clk_i,

            data_i => write_data_i(i),
            data_o => write_data_o(i)
        );
    end generate;

    read_strobe : entity work.dlyreg generic map (
        WIDTH => read_strobe_i'LENGTH,
        DELAY => BUFFER_DEPTH
    ) port map (
        clk_i => clk_i,

        data_i => read_strobe_i,
        data_o => read_strobe_o
    );

    read_ack : entity work.dlyreg generic map (
        WIDTH => read_ack_i'LENGTH,
        DELAY => BUFFER_DEPTH
    ) port map (
        clk_i => clk_i,

        data_i => read_ack_i,
        data_o => read_ack_o
    );

    gen_read : for i in read_data_i'RANGE generate
        read_data : entity work.dlyreg generic map (
            WIDTH => REG_DATA_WIDTH,
            DELAY => BUFFER_DEPTH
        ) port map (
            clk_i => clk_i,

            data_i => read_data_i(i),
            data_o => read_data_o(i)
        );
    end generate;
end;
