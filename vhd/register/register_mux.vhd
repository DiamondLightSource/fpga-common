-- I/O register mux

-- Decodes register plus address read and write into appropriate strobes and
-- read data multiplexing.  Also routes read_ack signal properly.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.register_defs.all;

entity register_mux is
    generic (
        BUFFER_DEPTH : natural := 0
    );
    port (
        clk_i : in std_ulogic;

        -- Register write.
        write_strobe_i : in std_ulogic;
        write_address_i : in unsigned;
        write_data_i : in reg_data_t;
        write_ack_o : out std_ulogic;

        write_strobe_o : out std_ulogic_vector;
        write_data_o : out reg_data_array_t;
        write_ack_i : in std_ulogic_vector;

        -- Register read.
        read_strobe_i : in std_ulogic;
        read_address_i : in unsigned;
        read_data_o : out reg_data_t;
        read_ack_o : out std_ulogic := '0';

        -- Multiplexed registers
        read_data_i : in reg_data_array_t;      -- Individual read registers
        read_strobe_o : out std_ulogic_vector;   -- Individual read selects
        read_ack_i : in std_ulogic_vector        -- Individual read acknowlege
    );
end;

architecture arch of register_mux is
    signal read_strobe_in : std_ulogic;
    signal read_address_in : read_address_i'SUBTYPE;

    signal read_address : natural;
    signal write_address : natural;
    signal read_data : reg_data_t;
    signal read_ack : std_ulogic;

    -- Buffer signals
    signal write_strobe_out : write_strobe_o'SUBTYPE;
    signal write_data_out : write_data_o'SUBTYPE;
    signal write_ack_in : write_ack_i'SUBTYPE;
    signal read_data_in : read_data_i'SUBTYPE;
    signal read_strobe_out : read_strobe_o'SUBTYPE;
    signal read_ack_in : read_ack_i'SUBTYPE;

begin
    -- The strobe instances already check that read and write ranges are
    -- ascending and zero based, so we just need to check read_data_i.
    assert read_data_i'LOW = 0 and read_data_i'LENGTH = read_ack_i'LENGTH
        report "read_data_i does not match read_ack_i"
        severity failure;

    write_strobe_inst : entity work.register_mux_strobe port map (
        clk_i => clk_i,
        strobe_i => write_strobe_i,
        address_i => write_address_i,
        ack_o => write_ack_o,
        strobe_o => write_strobe_out,
        ack_i => write_ack_in
    );

    read_strobe_inst : entity work.register_mux_strobe port map (
        clk_i => clk_i,
        strobe_i => read_strobe_in,
        address_i => read_address_in,
        ack_o => read_ack,
        strobe_o => read_strobe_out,
        ack_i => read_ack_in
    );

    -- Read data needs to be demultiplexed and latched at the right point, and
    -- need to delay the read acknowledge out at the same time.
    read_address <= to_integer(read_address_in);
    write_address <= to_integer(write_address_i);

    process (clk_i) begin
        if rising_edge(clk_i) then
            -- Extra timing to help with read address decoding
            read_strobe_in <= read_strobe_i;
            read_address_in <= read_address_i;

            -- All addresses beyond the decoded range return 0
            if read_address <= read_data_i'HIGH then
                read_data <= read_data_in(read_address);
            else
                read_data <= (others => '0');
            end if;
            -- Note that read_ack is set one tick after the corresponding
            -- read_ack_i, and hence will pick up the correct read_data
            -- registered above.
            if read_ack = '1' then
                read_data_o <= read_data;
            end if;
            read_ack_o <= read_ack;

            if write_strobe_i then
                write_data_out(write_address) <= write_data_i;
            end if;
        end if;
    end process;


    -- Optional buffer to help with timing for large register files.  Note that
    -- if this is instantiated then the register strobe/ack rules described in
    -- register_buffer must be followed.
    mux_buffer : entity work.register_buffer generic map (
        BUFFER_DEPTH => BUFFER_DEPTH
    ) port map (
        clk_i => clk_i,

        write_strobe_i => write_strobe_out,
        write_data_i => write_data_out,
        write_ack_o => write_ack_in,
        write_strobe_o => write_strobe_o,
        write_data_o => write_data_o,
        write_ack_i => write_ack_i,

        read_data_o => read_data_in,
        read_strobe_i => read_strobe_out,
        read_ack_o => read_ack_in,
        read_data_i => read_data_i,
        read_strobe_o => read_strobe_o,
        read_ack_i => read_ack_i
    );
end;
