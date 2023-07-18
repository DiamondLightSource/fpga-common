-- Transfer of bank of registers across a clock boundary

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.register_defs.all;

entity register_bank_cc is
    port (
        clk_in_i : in std_ulogic;       -- Master clock
        clk_out_i : in std_ulogic;      -- Slave clock
        -- clk_out status on clk_in domain.  If this is '0' then all register
        -- transactions will be unconditionally completed to avoid stalls.
        clk_out_ok_i : in std_ulogic := '1';

        -- Master clock domain (on clk_in_i)
        write_address_i : in unsigned;
        write_data_i : in reg_data_t;
        write_strobe_i : in std_ulogic;
        write_ack_o : out std_ulogic;

        read_address_i : in unsigned;
        read_data_o : out reg_data_t;
        read_strobe_i : in std_ulogic;
        read_ack_o : out std_ulogic;

        -- Slave clock domain (on clk_out_i)
        write_address_o : out unsigned;
        write_data_o : out reg_data_t;
        write_strobe_o : out std_ulogic;
        write_ack_i : in std_ulogic;

        read_address_o : out unsigned;
        read_data_i : in reg_data_t;
        read_strobe_o : out std_ulogic;
        read_ack_i : in std_ulogic
    );
end;

architecture arch of register_bank_cc is
    constant ADDRESS_WIDTH : natural := write_address_i'LENGTH;
    constant FULL_DATA_WIDTH : natural := ADDRESS_WIDTH + REG_DATA_WIDTH;
    subtype ADDRESS_RANGE is natural
        range ADDRESS_WIDTH + REG_DATA_WIDTH - 1 downto REG_DATA_WIDTH;

    signal write_data_in : std_ulogic_vector(FULL_DATA_WIDTH-1 downto 0);
    signal write_data_out : std_ulogic_vector(FULL_DATA_WIDTH-1 downto 0);

    signal read_address_in : std_ulogic_vector(read_address_i'RANGE);
    signal read_address_out : std_ulogic_vector(read_address_o'RANGE);

begin
    -- Writing: need to send data and address together
    write_cc : entity work.cross_clocks_write port map (
        clk_in_i => clk_in_i,
        clk_out_ok_i => clk_out_ok_i,
        strobe_i => write_strobe_i,
        ack_o => write_ack_o,
        data_i => write_data_in,

        clk_out_i => clk_out_i,
        strobe_o => write_strobe_o,
        ack_i => write_ack_i,
        data_o => write_data_out
    );
    -- Why do I need separate assignments here, why can't I just put these into
    -- the association list above?  VHDL friction, that's why
    write_data_in(REG_DATA_RANGE) <= write_data_i;
    write_data_in(ADDRESS_RANGE) <= std_ulogic_vector(write_address_i);
    write_data_o <= write_data_out(REG_DATA_RANGE);
    write_address_o <= unsigned(write_data_out(ADDRESS_RANGE));


    -- Reading: need special entity for bidirection sending
    read_cc : entity work.cross_clocks_write_read port map (
        clk_in_i => clk_in_i,
        clk_out_ok_i => clk_out_ok_i,
        strobe_i => read_strobe_i,
        ack_o => read_ack_o,
        write_data_i => read_address_in,
        read_data_o => read_data_o,

        clk_out_i => clk_out_i,
        strobe_o => read_strobe_o,
        ack_i => read_ack_i,
        write_data_o => read_address_out,
        read_data_i => read_data_i
    );
    -- More gratuitous VHDL friction here, cannot do these assignments in the
    -- association list above
    read_address_in <= std_ulogic_vector(read_address_i);
    read_address_o <= unsigned(read_address_out);
end;
