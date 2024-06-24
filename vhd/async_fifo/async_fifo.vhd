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
    subtype DATA_RANGE is natural range DATA_WIDTH-1 downto 0;

    signal fifo : vector_array(0 to 2**FIFO_BITS-1)(DATA_RANGE);
    attribute RAM_STYLE : string;
    attribute RAM_STYLE of fifo : signal is MEM_STYLE;

    signal write_address : unsigned(FIFO_BITS-1 downto 0);
    signal read_address : unsigned(FIFO_BITS-1 downto 0);

    signal read_enable : std_ulogic;
    signal read_ready : std_ulogic;

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
        read_ready_o => read_ready,
        read_access_address_o => read_address
    );


    -- We can write directly into the FIFO, no extra buffering required
    process (write_clk_i) begin
        if rising_edge(write_clk_i) then
            if write_valid_i and write_ready_o then
                fifo(to_integer(write_address)) <= write_data_i;
            end if;
        end if;
    end process;


    -- Read buffering is straightforward: keep the output buffer filled when
    -- possible, refill when consumed.
    read_enable <= read_ready and (read_ready_i or not read_valid_o);
    process (read_clk_i) begin
        if rising_edge(read_clk_i) then
            if read_reset_i then
                read_valid_o <= '0';
            elsif read_enable then
                read_data_o <= fifo(to_integer(read_address));
                read_valid_o <= '1';
            elsif read_ready_i then
                read_valid_o <= '0';
            end if;
        end if;
    end process;
end;
