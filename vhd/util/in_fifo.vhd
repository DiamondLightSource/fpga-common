-- Simple IO fifo based on matched input and output frequencies, sometimes
-- referred to as "mesochronous" clocks.  This allows the FIFO synchronisation
-- to be substantially simplified.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity in_fifo is
    generic (
        FIFO_WIDTH : natural
    );
    port (
        clk_in_i : in std_ulogic;
        data_i : in std_ulogic_vector(FIFO_WIDTH-1 downto 0);

        clk_out_i : in std_ulogic;
        data_o : out std_ulogic_vector(FIFO_WIDTH-1 downto 0);

        reset_i : in std_ulogic;

        -- The following reports are somewhat approximate.
        depth_o : out unsigned(2 downto 0);
        empty_o : out std_ulogic := '0';
        nearly_empty_o : out std_ulogic := '0';
        nearly_full_o : out std_ulogic := '0';
        full_o : out std_ulogic := '0'
    );
end;

architecture arch of in_fifo is
    -- The following constants are fudge factors for safely locating the in and
    -- out pointers and detecting underflow or overflow
    constant RESET_OFFSET : natural := 6;
    constant EMPTY_OFFSET : natural := 7;
    constant NEARLY_EMPTY_OFFSET : natural := 6;
    constant NEARLY_FULL_OFFSET : natural := 1;
    constant FULL_OFFSET : natural := 0;

    signal fifo : vector_array(0 to 7)(FIFO_WIDTH-1 downto 0)
        := (others => (others => '0'));
    signal in_ptr : std_ulogic_vector(2 downto 0) := "000";
    signal out_ptr : std_ulogic_vector(2 downto 0) := "000";

    signal in_ptr_sync : std_ulogic_vector(2 downto 0) := "000";
    signal in_ptr_out : std_ulogic_vector(2 downto 0) := "000";

    signal depth : unsigned(2 downto 0) := "000";

    attribute ASYNC_REG : string;
    attribute ASYNC_REG of in_ptr_sync : signal is "TRUE";
    attribute ASYNC_REG of in_ptr_out : signal is "TRUE";
    attribute max_delay_to : string;
    attribute max_delay_to of in_ptr_sync : signal is "TRUE";

    function add(value : std_ulogic_vector; step : integer := 1)
        return std_ulogic_vector is
    begin
        return unsigned_to_gray(gray_to_unsigned(value) + step);
    end;

begin
    -- Writing to the FIFO is simply free running
    process (clk_in_i) begin
        if rising_edge(clk_in_i) then
            fifo(to_integer(unsigned(in_ptr))) <= data_i;
            in_ptr <= add(in_ptr, 1);
        end if;
    end process;

    -- Bring in_ptr over to clk_out domain
    -- This could just be an array of sync_bit entities, but we'll actually want
    -- a max_delay attribute which will need to be managed separately
    process (clk_out_i) begin
        if rising_edge(clk_out_i) then
            in_ptr_sync <= in_ptr;
            in_ptr_out <= in_ptr_sync;
        end if;
    end process;

    process (clk_out_i) begin
        if rising_edge(clk_out_i) then
            if reset_i then
                out_ptr <= add(in_ptr_out, RESET_OFFSET);
            else
                out_ptr <= add(out_ptr, 1);
            end if;
            depth <=
                gray_to_unsigned(out_ptr) - gray_to_unsigned(in_ptr_out) - 1;

            -- Compute the status flags
            empty_o <= to_std_ulogic(depth >= EMPTY_OFFSET);
            nearly_empty_o <= to_std_ulogic(depth >= NEARLY_EMPTY_OFFSET);
            nearly_full_o <= to_std_ulogic(depth <= NEARLY_FULL_OFFSET);
            full_o <= to_std_ulogic(depth <= FULL_OFFSET);
        end if;
    end process;

    data_o <= fifo(to_integer(unsigned(out_ptr)));
    depth_o <= depth;
end;
