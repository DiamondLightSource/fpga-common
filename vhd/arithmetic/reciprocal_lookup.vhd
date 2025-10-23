-- Division lookup table

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity reciprocal_lookup is
    generic (
        LOOKUP_DELAY : natural := 2
    );
    port (
        clk_i : in std_ulogic;
        data_i : in unsigned(10 downto 0);
        data_o : out unsigned(16 downto 0)
    );
end;

architecture arch of reciprocal_lookup is
    constant LOOKUP_BITS : natural := data_i'LENGTH;
    constant STORED_BITS : natural := data_o'LENGTH;
    subtype lookup_t is unsigned_array
        (0 to 2**LOOKUP_BITS-1)(STORED_BITS-1 downto 0);

    -- Compute the reciprocal lookup table: each entry is 1/(1+x) scaled to 17
    -- bits.
    function generate_lookup return lookup_t
    is
        variable lookup_table : lookup_t;
        variable value : natural;
        variable reciprocal : real;
    begin
        -- The first value is hacked to fit, this is 1 LSB less than the true
        -- value of 1.
        lookup_table(0) := (others => '1');
        for i in 1 to 2**LOOKUP_BITS - 1 loop
            value := i + 2**LOOKUP_BITS;
            reciprocal := 2.0**(LOOKUP_BITS + STORED_BITS) / real(value);
            lookup_table(i) := to_unsigned(integer(reciprocal), STORED_BITS);
        end loop;
        return lookup_table;
    end;

    signal lookup_table : lookup_t := generate_lookup;

    attribute ram_style : string;
    attribute ram_style of lookup_table : signal is "BLOCK";

    signal result : unsigned(16 downto 0) := (others => '0');
    signal data_out : unsigned(16 downto 0) := (others => '0');

begin
    -- To ensure that all the required registers are folded into the lookup
    -- table, we need the following 2 stages:
    --      data_i => result => data_o
    assert LOOKUP_DELAY = 2
        report "Invalid LOOKUP_DELAY: " & to_string(LOOKUP_DELAY)
        severity failure;

    -- Double-buffered table lookup to help with BRAM registers.
    process (clk_i) begin
        if rising_edge(clk_i) then
            result <= lookup_table(to_integer(data_i));
            data_out <= result;
        end if;
    end process;

    data_o <= data_out;
end;
