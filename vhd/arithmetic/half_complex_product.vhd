-- Computes a*b+c*d or a*b-c*d depending on generic flag.  Used to compute half
-- of a complex product

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity half_complex_product is
    generic (
        -- Bits to silently discard from the top
        DISCARD_TOP : natural := 0;
        PROCESS_DELAY : natural := 0;
        DO_SUBTRACT : boolean;
        SATURATE_OUTPUT : boolean := false  -- Enable output saturation
    );
    port (
        clk_i : in std_ulogic;

        a_i : in signed;
        b_i : in signed;
        c_i : in signed;
        d_i : in signed;

        overflow_o : out std_ulogic;
        result_o : out signed
    );
end;

architecture arch of half_complex_product is
    constant AC_WIDTH : natural := a_i'LENGTH;
    constant BD_WIDTH : natural := b_i'LENGTH;
    constant OUT_WIDTH : natural := result_o'LENGTH;
    constant PRODUCT_WIDTH : natural := AC_WIDTH + BD_WIDTH;
    constant ACCUM_WIDTH : natural := PRODUCT_WIDTH + 1;
    constant BOTTOM_BIT : natural := ACCUM_WIDTH - OUT_WIDTH - DISCARD_TOP;
    subtype product_t is signed(PRODUCT_WIDTH-1 downto 0);
    subtype accum_t is signed(ACCUM_WIDTH-1 downto 0);

    function rounding_bit return signed is
        variable result : accum_t := (others => '0');
    begin
        if BOTTOM_BIT > 0 then
            result(BOTTOM_BIT - 1) := '1';
        end if;
        return result;
    end;

    -- First stage
    signal a_in : a_i'SUBTYPE := (others => '0');
    signal b_in : b_i'SUBTYPE := (others => '0');
    signal c_in1 : c_i'SUBTYPE := (others => '0');
    signal d_in1 : d_i'SUBTYPE := (others => '0');
    -- Second stage
    signal ab : product_t := (others => '0');
    signal c_in : c_i'SUBTYPE := (others => '0');
    signal d_in : d_i'SUBTYPE := (others => '0');
    -- Third stage
    signal ab_out : accum_t := (others => '0');
    signal cd : product_t := (others => '0');
    -- Fourth stage
    signal total : accum_t;
    signal result : accum_t := (others => '0');
    signal overflow_out : std_ulogic;
    -- Saturation
    signal saturated_result : result_o'SUBTYPE := (others => '0');
    signal saturated_overflow : std_ulogic := '0';

    -- Overflow detection.  Written in this slightly weird way to ensure that it
    -- properly maps to the appropriate DSP48E resources.
    subtype OVF_RANGE is natural
        range ACCUM_WIDTH-1 downto ACCUM_WIDTH-DISCARD_TOP-1;
    constant ONES_MASK : signed(OVF_RANGE) := (others => '1');
    signal all_ones : std_ulogic := '0';
    signal all_zeros : std_ulogic := '0';

    subtype RESULT_RANGE is natural
        range ACCUM_WIDTH-DISCARD_TOP-1 downto BOTTOM_BIT;

    -- Ensure input registers aren't eaten by the DSP!
    attribute DONT_TOUCH : string;
    attribute DONT_TOUCH of a_i : signal is "yes";
    attribute DONT_TOUCH of b_i : signal is "yes";

    -- However, we do want the final result to stay inside the DSP!
    attribute USE_DSP : string;
    attribute USE_DSP of result : signal is "yes";

begin
    -- Processing delay
    --  a_i, b_i, c_i, d_i
    --      => a_in, b_in, c_in1, d_in1
    --      => ab, c_in, d_in
    --      => ab_out, cd, total
    --      => result, all_ones, all_zeros = result_o, overflow_o
    -- plus one extra tick if SATURATE_OUTPUT selected
    assert PROCESS_DELAY = 0 or PROCESS_DELAY = 4 + to_integer(SATURATE_OUTPUT)
        report "Invalid PROCESS_DELAY: " & to_string(PROCESS_DELAY)
        severity failure;
    assert a_i'LENGTH = c_i'LENGTH and b_i'LENGTH = d_i'LENGTH
        report "Inconsistent input widths"
        severity failure;

    -- Compute the final result here so we can determine overflow
    gen_total : if DO_SUBTRACT generate
        total <= ab_out - cd;
    else generate
        total <= ab_out + cd;
    end generate;
    overflow_out <= not all_ones and not all_zeros;

    process (clk_i) begin
        if rising_edge(clk_i) then
            -- First stage, placing inputs in DSP registers
            -- Note that c*d needs to be one tick later for the sum to align
            a_in <= a_i;
            b_in <= b_i;
            c_in1 <= c_i;
            d_in1 <= d_i;

            -- Second stage, first product and more delay
            ab <= a_in * b_in;
            c_in <= c_in1;
            d_in <= d_in1;

            -- Third stage, rounding and second product
            ab_out <= ab + rounding_bit;
            cd <= c_in * d_in;

            -- Final stage, gathering result and overflow bits
            result <= total;
            all_ones <= to_std_ulogic(total(OVF_RANGE) = ONES_MASK);
            all_zeros <= to_std_ulogic(total(OVF_RANGE) = 0);

            -- Saturation
            saturated_result <= saturate(
                result(RESULT_RANGE), overflow_out, result(result'LEFT));
            saturated_overflow <= overflow_out;
        end if;
    end process;

    gen_result : if SATURATE_OUTPUT generate
        result_o <= saturated_result;
        overflow_o <= saturated_overflow;
    else generate
        result_o <= result(RESULT_RANGE);
        overflow_o <= overflow_out;
    end generate;
end;
