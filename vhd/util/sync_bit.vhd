-- Clock domain crossing synchronisation

-- Note that the delay from bit_i valid to bit_o valid varies with the phase
-- between the clock of bit_i, but will be between 1 and 2 ticks of clk_i.

library ieee;
use ieee.std_logic_1164.all;

use work.support.all;

entity sync_bit is
    generic (
        INITIAL : std_ulogic := '0';
        DEPTH : natural := 2;
        -- By default a false path from bit_i is configured, but if MAX_DELAY is
        -- wanted this must be set to false and the source must be configured
        -- outside this entity
        FALSE_PATH : boolean := true
    );
    port (
        clk_i : in std_ulogic;
        bit_i : in std_ulogic;
        bit_o : out std_ulogic;
        -- If desired asynchronous reset can be synchronised to clk_i
        reset_i : in std_ulogic := '0'
    );
end;

architecture arch of sync_bit is
    signal bit_in : std_ulogic := INITIAL;
    signal sync_bits : std_ulogic_vector(1 to DEPTH-1) := (others => INITIAL);

    -- Tell synthesis to treat these bits a little specially
    attribute async_reg : string;
    attribute async_reg of bit_in : signal is "TRUE";
    attribute async_reg of sync_bits : signal is "TRUE";

    -- This custom attribute must be matched with the following entry in the
    -- constraints file:
    --  set_false_path \
    --      -to [get_cells -hierarchical -filter { false_path_to == "TRUE" }]
    attribute false_path_to : string;
    attribute false_path_to of bit_in : signal
        is choose(FALSE_PATH, "TRUE", "FALSE");

begin
    assert DEPTH >= 2
        report "Invalid depth " & to_string(DEPTH)
        severity failure;

    process (clk_i, reset_i) begin
        if reset_i then
            bit_in <= INITIAL;
            sync_bits <= (others => INITIAL);
        elsif rising_edge(clk_i) then
            bit_in <= bit_i;
            sync_bits(1) <= bit_in;
            for i in 2 to DEPTH-1 loop
                sync_bits(i) <= sync_bits(i - 1);
            end loop;
        end if;
    end process;
    bit_o <= sync_bits(DEPTH-1);
end;
