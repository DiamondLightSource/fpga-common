-- Clock domain crossing synchronisation
-- Some ideas taken from:
-- https://github.com/VLSI-EDA/\
--  PoC/blob/master/src/misc/sync/sync_Bits_Xilinx.vhdl

library ieee;
use ieee.std_logic_1164.all;

entity sync_bit is
    port (
        clk_i : in std_ulogic;
        bit_i : in std_ulogic;
        bit_o : out std_ulogic := '0'
    );
end;

architecture arch of sync_bit is
    -- Note that the signal name here and the fact that it names an actual
    -- register are used by the constraints file, where an explicit timing
    -- "false path" is created to this register from all other flip-flops.
    signal bit_in : std_ulogic := '0';

    attribute async_reg : string;
    attribute async_reg of bit_in : signal is "TRUE";
    attribute async_reg of bit_o : signal is "TRUE";

    attribute false_path_to : string;
    attribute false_path_to of bit_in : signal is "TRUE";

begin
    process (clk_i) begin
        if rising_edge(clk_i) then
            bit_in <= bit_i;
            bit_o <= bit_in;
        end if;
    end process;
end;
