-- Template for cos/sin lookup table, used by nco_cos_sin_table.py

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.nco_defs.all;

use ieee.math_real.all;

entity nco_cos_sin_table is
    generic (
        LOOKUP_DELAY : natural
    );
    port (
        clk_i : in std_ulogic;

        addr_i : in cos_sin_addr_t;
        cos_sin_o : out cos_sin_19_t := (others => (others => '0'))
    );
end;

architecture arch of nco_cos_sin_table is
    -- The target block ram is 1024x36
    constant SAMPLES : natural := 1024;
    -- The scaling is a bit curious: we need the rounded result to fit into 15
    -- bits (as an unsigned number), but we want 18 significant bits stored.
    constant RESULT_BITS : natural := 15;
    constant STORED_BITS : natural := 18;

    subtype cos_sin_data_t is std_ulogic_vector(2*STORED_BITS-1 downto 0);
    type lookup_t is array(0 to SAMPLES-1) of cos_sin_data_t;

    -- Compute the cos/sin lookup table
    function generate_lookup return lookup_t
    is
        constant EXTRA_BITS : natural := STORED_BITS - RESULT_BITS;
        constant SCALE : real := 2.0**EXTRA_BITS * (2.0**RESULT_BITS - 1.0);
        variable lookup_table : lookup_t;
        variable theta : real;
        variable c, s : integer;
    begin
        for i in 0 to SAMPLES-1 loop
            theta := MATH_PI / 4.0 / real(SAMPLES) * real(i);
            c := integer(round(SCALE * cos(theta)));
            s := integer(round(SCALE * sin(theta)));
            lookup_table(i) :=
                to_std_ulogic_vector_u(s, STORED_BITS) &
                to_std_ulogic_vector_u(c, STORED_BITS);
        end loop;
        return lookup_table;
    end;

    signal table : lookup_t := generate_lookup;

    attribute ram_style : string;
    attribute ram_style of table : signal is "BLOCK";

    signal data : cos_sin_data_t := (others => '0');
    signal cos_sin : cos_sin_data_t := (others => '0');

    function bits_to_cos_sin(data : std_ulogic_vector) return cos_sin_19_t is
        variable result : cos_sin_19_t;
    begin
        result.cos := signed('0' & data(17 downto 0));
        result.sin := signed('0' & data(35 downto 18));
        return result;
    end;

begin
    -- To ensure that all the required registers are folded into the lookup
    -- table, we need the following 2 stages:
    --      addr_i => data => cos_sin = cos_sin_o
    assert LOOKUP_DELAY = 2
        report "Invalid LOOKUP_DELAY: " & to_string(LOOKUP_DELAY)
        severity failure;

    -- Double-buffered table lookup to help with BRAM registers.
    process (clk_i) begin
        if rising_edge(clk_i) then
            data <= table(to_integer(addr_i));
            cos_sin <= data;
        end if;
    end process;

    cos_sin_o <= bits_to_cos_sin(cos_sin);
end;
