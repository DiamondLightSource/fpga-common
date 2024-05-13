-- Wraps the slight complexity of computing a rounded product, ensures correct
-- mapping to DSP48E without extra logic (except for OR on overflow_o if used).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity rounded_product is
    generic (
        -- Bits to discard from the top, giving extra output gain.  If this left
        -- equal to zero overflow_o can be ignored.
        DISCARD_TOP : natural := 0;
        PROCESS_DELAY : natural := 3;
        -- If enable_i is unused this should be left as '1' to ensure that all
        -- the enable registers are optimised out.  However, if enable_i is
        -- used then this should probably be set to '0' to avoid a spurious
        -- done output during startup.
        DEFAULT_ENABLE : std_ulogic := '1'
    );
    port (
        clk_i : in std_ulogic;

        enable_i : in std_ulogic := '1';
        a_i : in signed;                -- Wider term
        b_i : in signed;                -- Narrow term

        ab_o : out signed;              -- Rounded output
        overflow_o : out std_ulogic;    -- Set if output has overflowed
        done_o : out std_ulogic         -- enable_i delayed by PROCESS_DELAY
    );
end;

architecture arch of rounded_product is
    constant A_WIDTH : natural := a_i'LENGTH;
    constant B_WIDTH : natural := b_i'LENGTH;
    constant OUT_WIDTH : natural := ab_o'LENGTH;
    constant PRODUCT_WIDTH : natural := A_WIDTH + B_WIDTH;
    constant BOTTOM_BIT : natural := PRODUCT_WIDTH - OUT_WIDTH - DISCARD_TOP;

    function rounding_bit return signed is
        variable result : signed(PRODUCT_WIDTH-1 downto 0) := (others => '0');
    begin
        if BOTTOM_BIT > 0 then
            result(BOTTOM_BIT - 1) := '1';
        end if;
        return result;
    end;

    signal a_in : a_i'SUBTYPE := (others => '0');
    signal b_in : b_i'SUBTYPE := (others => '0');
    signal enable_product : std_ulogic := DEFAULT_ENABLE;
    signal product : signed(PRODUCT_WIDTH-1 downto 0) := (others => '0');
    signal ab : signed(PRODUCT_WIDTH-1 downto 0) := (others => '0');
    signal enable_out : std_ulogic := DEFAULT_ENABLE;
    signal ab_out : signed(PRODUCT_WIDTH-1 downto 0) := (others => '0');
    signal done : std_ulogic := DEFAULT_ENABLE;

    -- Overflow detection.  Written in this slightly weird way to ensure that it
    -- properly maps to the appropriate DSP48E resources.
    subtype OVF_RANGE is natural
        range PRODUCT_WIDTH-1 downto PRODUCT_WIDTH-DISCARD_TOP-1;
    constant ONES_MASK : signed(OVF_RANGE) := (others => '1');
    signal all_ones : std_ulogic;
    signal all_zeros : std_ulogic;

    -- Ensure input registers aren't eaten by the DSP!
    attribute DONT_TOUCH : string;
    attribute DONT_TOUCH of a_i : signal is "yes";
    attribute DONT_TOUCH of b_i : signal is "yes";

begin
    -- Processing delay:
    --  a_i, b_i
    --      => a_in, b_in
    --      => product
    --      => ab_out, overflow_o
    assert PROCESS_DELAY = 3
        report "Invalid PROCESS_DELAY: " & to_string(PROCESS_DELAY)
        severity failure;
    -- Ensure the inputs and result will fit within a DSP48E1 unit
    assert A_WIDTH <= 25
        report "a_i too long: " & to_string(A_WIDTH) & " > 25"
        severity failure;
    assert B_WIDTH <= 18
        report "b_i too long: " & to_string(B_WIDTH) & " > 18"
        severity failure;

    ab <= product + rounding_bit;
    process (clk_i) begin
        if rising_edge(clk_i) then
            if enable_i then
                a_in <= a_i;
                b_in <= b_i;
            end if;
            enable_product <= enable_i;
            if enable_product then
                product <= a_in * b_in;
            end if;
            enable_out <= enable_product;
            if enable_out then
                ab_out <= ab;
                all_ones <= to_std_ulogic(ab(OVF_RANGE) = ONES_MASK);
                all_zeros <= to_std_ulogic(ab(OVF_RANGE) = 0);
            end if;
            done <= enable_out;
        end if;
    end process;

    ab_o <= ab_out(PRODUCT_WIDTH-DISCARD_TOP-1 downto BOTTOM_BIT);
    gen_ovf : if DISCARD_TOP > 0 generate
        overflow_o <= not all_ones and not all_zeros;
    else generate
        overflow_o <= '0';
    end generate;
    done_o <= done;
end;
