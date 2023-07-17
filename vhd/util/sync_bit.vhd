-- Clock domain crossing synchronisation

-- Note that the delay from bit_i valid to bit_o valid varies with the phase
-- between the clock of bit_i, but will be between 1 and 2 ticks of clk_i.

library ieee;
use ieee.std_logic_1164.all;

entity sync_bit is
    generic (
        INITIAL : std_ulogic := '0'
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
    signal bit_out : std_ulogic := INITIAL;

    -- Tell synthesis to treat these bits a little specially
    attribute async_reg : string;
    attribute async_reg of bit_in : signal is "TRUE";
    attribute async_reg of bit_out : signal is "TRUE";

    -- This custom attribute must be matched with the following entry in the
    -- constraints file:
    --  set_false_path \
    --      -to [get_cells -hierarchical -filter { false_path_to == "TRUE" }]
    attribute false_path_to : string;
    attribute false_path_to of bit_in : signal is "TRUE";

begin
    process (clk_i, reset_i) begin
        if reset_i then
            bit_in <= INITIAL;
            bit_out <= INITIAL;
        elsif rising_edge(clk_i) then
            bit_in <= bit_i;
            bit_out <= bit_in;
        end if;
    end process;
    bit_o <= bit_out;
end;
