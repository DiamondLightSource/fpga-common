-- A simple FIFO implementation suitable for FIFO buffers of no more than around
-- three.  When FIFO_DEPTH=1 generates a simple single buffer, 2 generates a
-- classic skid buffer, but larger depths are unable to effectively use memory
-- resources due to the conditional shift structure.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity simple_fifo is
    generic (
        FIFO_DEPTH : natural;           -- Number of FIFO entries
        DATA_WIDTH : natural            -- Width of data path
    );
    port (
        clk_i : in std_ulogic;

        -- Write interface
        write_valid_i : in std_ulogic;
        write_ready_o : out std_ulogic := '1';
        write_data_i : in std_ulogic_vector(DATA_WIDTH-1 downto 0);

        -- Unregistered write_ready_o one tick early, useful for specialised
        -- applications.
        write_ready_early_o : out std_ulogic;

        -- Read interface
        read_valid_o : out std_ulogic := '0';
        read_ready_i : in std_ulogic;
        read_data_o : out std_ulogic_vector(DATA_WIDTH-1 downto 0)
    );
end;

architecture arch of simple_fifo is
    subtype DATA_RANGE is natural range DATA_WIDTH-1 downto 0;

    signal fifo : vector_array(0 to FIFO_DEPTH-1)(DATA_RANGE);
    signal count : natural range 0 to FIFO_DEPTH;

    signal will_read : boolean;
    signal will_write : boolean;
    signal new_count : natural range 0 to FIFO_DEPTH;

    signal new_write_ready : boolean;
    signal new_read_valid : boolean;

begin
    assert FIFO_DEPTH <= 3
        report "Use fifo entity for larger FIFO depths"
        severity warning;

    -- We always return the zero entry from the FIFO
    read_data_o <= fifo(0);

    will_read  <= count > 0 and read_ready_i = '1';
    will_write <= count < FIFO_DEPTH and write_valid_i = '1';

    -- Note that the guards on count in this expression are redundant, as they
    -- are already taken into account ... but without these guards QuestaSim
    -- will temporarily try to compute invalid values for new_count, and will
    -- terminate the simulation.
    new_count <=
        count + 1 when will_write and not will_read and count < FIFO_DEPTH else
        count - 1 when will_read and not will_write and count > 0 else
        count;

    new_write_ready <= new_count < FIFO_DEPTH;
    new_read_valid  <= new_count > 0;

    -- Early view of new_write_ready if external registering needed
    write_ready_early_o <= to_std_ulogic(new_write_ready);

    process (clk_i) begin
        if rising_edge(clk_i) then
            if will_read then
                if will_write then
                    fifo(count-1) <= write_data_i;
                end if;
                for i in 1 to FIFO_DEPTH loop
                    if i < count then
                        fifo(i-1) <= fifo(i);
                    end if;
                end loop;
            elsif will_write then
                fifo(count) <= write_data_i;
            end if;

            count <= new_count;
            write_ready_o <= to_std_ulogic(new_write_ready);
            read_valid_o  <= to_std_ulogic(new_read_valid);
        end if;
    end process;
end;
