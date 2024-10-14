-- Simple asynchronous FIFO

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity async_fifo is
    generic (
        FIFO_BITS : natural := 5;       -- log2 FIFO depth
        DATA_WIDTH : natural;           -- Width of data path
        MEM_STYLE : string := "";       -- Can override tool default
        MAX_DELAY : real := 4.0         -- Should be shortest clock period in ns
    );
    port (
        -- Write interface
        write_clk_i : in std_ulogic;
        write_reset_i : in std_ulogic := '0';
        write_valid_i : in std_ulogic;
        write_ready_o : out std_ulogic;
        write_data_i : in std_ulogic_vector(DATA_WIDTH-1 downto 0);

        -- Read interface
        read_clk_i : in std_ulogic;
        read_reset_i : in std_ulogic := '0';
        read_valid_o : out std_ulogic := '0';
        read_ready_i : in std_ulogic;
        read_data_o : out std_ulogic_vector(DATA_WIDTH-1 downto 0)
    );
end;

architecture arch of async_fifo is
    signal write_address : unsigned(FIFO_BITS-1 downto 0);
    signal read_address : unsigned(FIFO_BITS-1 downto 0);

    signal read_enable : std_ulogic;
    signal read_valid : std_ulogic;

begin
    -- Computes in and out addresses together with read/write ready flags.  We
    -- don't use the reserve feature.
    address : entity work.async_fifo_address generic map (
        ADDRESS_WIDTH => FIFO_BITS,
        MAX_DELAY => MAX_DELAY,
        ENABLE_READ_RESERVE => false,
        ENABLE_WRITE_RESERVE => false
    ) port map (
        write_clk_i => write_clk_i,
        write_reset_i => write_reset_i,
        write_access_i => write_valid_i,
        write_ready_o => write_ready_o,
        write_access_address_o => write_address,

        read_clk_i => read_clk_i,
        read_reset_i => read_reset_i,
        read_access_i => read_enable,
        read_valid_o => read_valid,
        read_access_address_o => read_address
    );

    fifo : entity work.memory_array_dual generic map (
        ADDR_BITS => FIFO_BITS,
        DATA_BITS => DATA_WIDTH,
        MEM_STYLE => MEM_STYLE
    ) port map (
        write_clk_i => write_clk_i,
        write_strobe_i => write_valid_i and write_ready_o,
        write_addr_i => write_address,
        write_data_i => write_data_i,

        read_clk_i => read_clk_i,
        read_strobe_i => read_enable and not read_reset_i,
        read_addr_i => read_address,
        read_data_o => read_data_o
    );


    -- Read buffering is straightforward: keep the output buffer filled when
    -- possible, refill when consumed.
    read_enable <= read_valid and (read_ready_i or not read_valid_o);
    process (read_clk_i) begin
        if rising_edge(read_clk_i) then
            if read_reset_i then
                read_valid_o <= '0';
            elsif read_enable then
                read_valid_o <= '1';
            elsif read_ready_i then
                read_valid_o <= '0';
            end if;
        end if;
    end process;
end;
