-- Dual port memory array with individual byte strobes

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity memory_array_dual_bytes is
    generic (
        ADDR_BITS : natural;
        DATA_BITS : natural;
        BYTE_BITS : natural := 8;
        INITIAL : std_ulogic := 'U';
        -- DO NOT MODIFY!  This is not a parameter.
        DATA_BYTES : natural := DATA_BITS / BYTE_BITS
    );
    port (
        -- Read interface
        read_clk_i : in std_ulogic;
        read_strobe_i : in std_ulogic := '1';
        read_addr_i : in unsigned(ADDR_BITS-1 downto 0);
        read_data_o : out std_ulogic_vector(DATA_BITS-1 downto 0);

        -- Write interface
        write_clk_i : in std_ulogic;
        write_strobe_i : in std_ulogic_vector(DATA_BYTES-1 downto 0);
        write_addr_i : in unsigned(ADDR_BITS-1 downto 0);
        write_data_i : in std_ulogic_vector(DATA_BITS-1 downto 0)
    );
end;

architecture arch of memory_array_dual_bytes is
    signal memory : vector_array(0 to 2**ADDR_BITS-1)(DATA_BITS-1 downto 0)
        := (others => (others => INITIAL));
    attribute ram_style : string;
    attribute ram_style of memory : signal is "BLOCK";

begin
    assert DATA_BYTES * BYTE_BITS = DATA_BITS severity failure;

    process (write_clk_i)
        variable high, low : natural;
    begin
        if rising_edge(write_clk_i) then
            for byte in 0 to DATA_BYTES-1 loop
                low := byte * BYTE_BITS;
                high := low + BYTE_BITS - 1;
                if write_strobe_i(byte) then
                    memory(to_integer(write_addr_i))(high downto low)
                        <= write_data_i(high downto low);
                end if;
            end loop;
        end if;
    end process;

    process (read_clk_i) begin
        if rising_edge(read_clk_i) then
            if read_strobe_i then
                read_data_o <= memory(to_integer(read_addr_i));
            end if;
        end if;
    end process;
end;
