-- Programmable long delay.  This delay uses block ram.
--
-- Two extra clock ticks are added to the programmed delay.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity long_delay is
    generic (
        WIDTH : natural;
        INITIAL : std_ulogic := '0';
        EXTRA_DELAY : natural := 2      -- Validation only
    );
    port (
        clk_i : in std_ulogic;

        delay_i : in unsigned;
        enable_i : in std_ulogic;
        data_i : in std_ulogic_vector(WIDTH-1 downto 0);
        data_o : out std_ulogic_vector(WIDTH-1 downto 0)
    );
end;

architecture arch of long_delay is
    constant ADDR_BITS : natural := delay_i'LENGTH;
    subtype address_t is unsigned(ADDR_BITS-1 downto 0);

    signal write_addr : address_t := (others => '0');
    signal read_addr : address_t := (others => '0');

begin
    memory : entity work.memory_array generic map (
        ADDR_BITS => ADDR_BITS,
        DATA_BITS => WIDTH,
        MEM_STYLE => "BLOCK",
        INITIAL => (others => INITIAL),
        READ_DELAY => EXTRA_DELAY - 1
    ) port map (
        clk_i => clk_i,
        write_strobe_i => enable_i,
        write_addr_i => write_addr,
        write_data_i => data_i,
        read_strobe_i => enable_i,
        read_addr_i => read_addr,
        read_data_o => data_o
    );

    process (clk_i) begin
        if rising_edge(clk_i) then
            if enable_i then
                write_addr <= write_addr + 1;
                read_addr <= write_addr - delay_i;
            end if;
        end if;
    end process;
end;
