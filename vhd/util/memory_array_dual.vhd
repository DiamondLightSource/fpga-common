-- Memory array with dual clocked access.  This has much the same interface as
-- memory_array

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity memory_array_dual is
    generic (
        ADDR_BITS : natural;
        DATA_BITS : natural;
        -- The memory style can be one of
        --  ""              Use tool default, depends on memory size
        --  "DISTRIBUTED"   Use distributed RAM
        --  "BLOCK"         Use block RAM
        MEM_STYLE : string := "";   -- Default to unspecified

        -- Initial value for memory array
        INITIAL : std_ulogic_vector(DATA_BITS-1 downto 0) := (others => '0')
    );
    port (
        -- Write interface
        write_clk_i : in std_ulogic;
        write_strobe_i : in std_ulogic := '1';
        write_addr_i : in unsigned(ADDR_BITS-1 downto 0);
        write_data_i : in std_ulogic_vector(DATA_BITS-1 downto 0);

        -- Read interface
        read_clk_i : in std_ulogic;
        read_strobe_i : in std_ulogic := '1';
        read_addr_i : in unsigned(ADDR_BITS-1 downto 0);
        read_data_o : out std_ulogic_vector(DATA_BITS-1 downto 0) := INITIAL
    );
end;

architecture arch of memory_array_dual is
    signal memory : vector_array(0 to 2**ADDR_BITS-1)(DATA_BITS-1 downto 0)
        := (others => INITIAL);
    attribute ram_style : string;
    attribute ram_style of memory : signal is MEM_STYLE;

    -- when the source is distributed RAM
    attribute false_path_dram_to : string;
    attribute false_path_dram_to of read_data_o : signal
        is choose(ADDR_BITS <= 6, "TRUE", "FALSE");

begin
    process (write_clk_i) begin
        if rising_edge(write_clk_i) then
            if write_strobe_i then
                memory(to_integer(write_addr_i)) <= write_data_i;
            end if;
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
