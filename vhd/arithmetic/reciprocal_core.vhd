-- Pipelined reciprocal calculation
--
-- Given a 24 bit unsigned A returns 24 bit unsigned X and 4 bit unsigned S
-- satisfying the equation:
--
--      A * X * 2^S = 2^47 + E      where  |E| <= 1
--
-- In other words, there is at most a one-bit error in the result.  Processing
-- takes 9 ticks.

-- The reciprocal 1/A is computed using a table lookup followed by a single
-- round of Newton-Raphson using the update equation:
--
--      x' = x * (2 - A * x) = x - x * (A * x - 1)
--
-- Note that given a good initial estimate for x the term A*x is very close to 1
-- which means that the top bits of this product can be discarded for the final
-- multiplication.

-- This is the core implementation which requires data_i to be fully normalised,
-- in other words the top bit must be set.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity reciprocal_core is
    generic (
        PROCESS_DELAY : natural := 9    -- Used to validate processing delay
    );
    port (
        clk_i : in std_ulogic;

        data_i : in unsigned(23 downto 0);
        data_o : out unsigned(23 downto 0)
    );
end;

architecture arch of reciprocal_core is
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    -- Adjust input and extract lookup

    -- This many bits used to look up initial estimate
    constant LOOKUP_BITS : natural := 11;
    -- This many bits from the initial lookup
    constant INITIAL_BITS : natural := 17;

    signal lookup_index : unsigned(LOOKUP_BITS-1 downto 0) := (others => '0');
    signal data_in_fixup : data_i'SUBTYPE := (others => '0');


    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    -- Look up initial approximation

    signal initial_value : unsigned(INITIAL_BITS-1 downto 0);
    signal data_in_start : data_i'SUBTYPE;


    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    -- First multiplication

    -- Compute A*B = 1 + eB + AL*B.  We have 1 <= 1 and |AL| <= 2^-12, but for
    -- safety (allowing for eB) we need to allow for |A*B-1| < 2^-11.
    -- The first error term is then E1 = A*B-1 and we can safely discard the top
    -- bits, effectively performing the subtraction of 1 for free!
    -- We'll take the bottom 18 bits of the result, and it is safe to discard
    -- the top 13 bits: the top two bits are zeros from the unsigned inputs, and
    -- the remaining 11 bits will all be the same.
    constant DISCARD_TOP : natural := LOOKUP_BITS + 2;
    -- It is safe to set this as low as 14, but there's no particular gain, as
    -- these values all live in fabric DSP registers.
    constant ERROR_BITS : natural := 18;

    signal fractional_error : signed(ERROR_BITS-1 downto 0);
    signal initial_value_delay : initial_value'SUBTYPE;


    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    -- Second multiplication and final correction

    constant PRODUCT_BITS : natural := INITIAL_BITS + 1 + ERROR_BITS;
    -- Compute E2 = B*(A*B-1) = B*E1 and assemble the final result
    --
    --      X = B - E2 = B - B*E1 = B - B*(A*B - 1)
    constant FULL_RESULT_BITS : natural := PRODUCT_BITS + LOOKUP_BITS - 2;
    subtype INITIAL_RESULT_RANGE is natural
        range FULL_RESULT_BITS-1 downto FULL_RESULT_BITS - INITIAL_BITS;
    constant RESULT_BITS : natural := data_o'LENGTH;
    subtype RESULT_RANGE is natural
        range FULL_RESULT_BITS-1 downto FULL_RESULT_BITS - RESULT_BITS;
    constant ROUNDING_BIT : natural := FULL_RESULT_BITS - RESULT_BITS - 1;

    signal a_in : signed(INITIAL_BITS downto 0) := (others => '0');
    signal b_in : signed(ERROR_BITS-1 downto 0) := (others => '0');
    signal c_in_start : signed(47 downto 0) := (others => '0');
    signal product : signed(PRODUCT_BITS-1 downto 0) := (others => '0');
    signal c_in : signed(47 downto 0) := (others => '0');
    signal result : signed(47 downto 0) := (others => '0');


    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    -- Delay definitions, both validated against corresponding entities

    constant LOOKUP_DELAY : natural := 2;   -- Initial lookup
    constant PRODUCT_DELAY : natural := 3;  -- Multiply/accumulate delay

begin
    -- Process delay validation:
    --  data_i
    --      => lookup_index, data_in_fixup
    --      =(LOOKUP_DELAY)=> initial_value, data_in_start
    --      =(PRODUCT_DELAY)=> fractional_error, initial_value_delay
    --      =(PRODUCT_DELAY)=> result = data_o
    assert PROCESS_DELAY = 1 + LOOKUP_DELAY + 2*PRODUCT_DELAY
        report "Invalid PROCESS_DELAY: " & to_string(PROCESS_DELAY) & " /= "
            & to_string(1 + LOOKUP_DELAY + 2*PRODUCT_DELAY)
        severity failure;

    -- Normalisation check, simulation only
    -- pragma translate_off
    assert not data_i'EVENT or data_i(data_i'LEFT) = '1' or data_i = 0
        report "Data not normalised"
        severity error;
    -- pragma translate_on


    -- -------------------------------------------------------------------------
    -- Adjust input and extract lookup index
    --
    -- Write A = 1 + AH + AL with 11 bits of resolution in AH, scaled to range
    -- 0 <= AH <= 1-2^-11, and |AL| <= 2^-12.  This is done by using the top bit
    -- of AL to round AH.  Then use AH to compute B such that
    --      A * (1 + AH) * B = 1 + eB,
    -- with a residual maximum error eB < 2^-16.
    --
    process (clk_i)
        -- The lookup value is rounded (to give us an extra bit of accuracy),
        -- but we want to truncate the result if it overflows; fortunately in
        -- this case the extra bit of accuracy is less significant.
        constant LOOKUP_LEFT : natural := data_i'LEFT - 1;
        constant LOOKUP_RIGHT : natural := LOOKUP_LEFT - LOOKUP_BITS;
        -- After normalisation the top bit is 1, so we ignore this for lookup.
        -- However, we include an extra lower bit for rounding.
        subtype LOOKUP_RANGE is natural range LOOKUP_LEFT downto LOOKUP_RIGHT;
        subtype RESULT_RANGE is natural
            range LOOKUP_LEFT downto LOOKUP_RIGHT + 1;

        variable rounded : unsigned(LOOKUP_LEFT + 1 downto LOOKUP_RIGHT);

    begin
        if rising_edge(clk_i) then
            rounded := ('0' & data_i(LOOKUP_RANGE)) + 1;
            if rounded(rounded'LEFT) = '1' then
                lookup_index <= (RESULT_RANGE => '1');
            else
                lookup_index <= rounded(RESULT_RANGE);
            end if;

            -- The following is a truly evil hack.  If the input is equal to
            -- 0x800000 (ie 1.0) the proper result is also 1.0, which will
            -- overflow our result.  Turns out if we just accept a single bit
            -- error here we can make this work.
            if data_i = X"800000" then
                data_in_fixup <= X"800001";
            else
                data_in_fixup <= data_i;
            end if;
        end if;
    end process;


    -- -------------------------------------------------------------------------
    -- Look up initial approximation
    --
    lookup : entity work.reciprocal_lookup generic map (
        LOOKUP_DELAY => LOOKUP_DELAY
    ) port map (
        clk_i => clk_i,
        data_i => lookup_index,
        data_o => initial_value
    );

    -- We need a copy of the original data for the first muliplication step
    delay_data_in : entity work.fixed_delay generic map (
        WIDTH => data_i'LENGTH,
        DELAY => LOOKUP_DELAY
    ) port map (
        clk_i => clk_i,
        data_i => std_ulogic_vector(data_in_fixup),
        unsigned(data_o) => data_in_start
    );


    -- -------------------------------------------------------------------------
    -- First multiplication
    --
    -- Compute A*B = 1 + E, extract lower bits yielding E
    --
    first_product : entity work.rounded_product generic map (
        PROCESS_DELAY => PRODUCT_DELAY,
        DISCARD_TOP => DISCARD_TOP
    ) port map (
        clk_i => clk_i,
        a_i => '0' & signed(data_in_start),
        b_i => '0' & signed(initial_value),
        ab_o => fractional_error
    );
    -- We also need a copy of the initial estimate for the final step
    delay_initial : entity work.fixed_delay generic map (
        WIDTH => initial_value'LENGTH,
        DELAY => PRODUCT_DELAY
    ) port map (
        clk_i => clk_i,
        data_i => std_ulogic_vector(initial_value),
        unsigned(data_o) => initial_value_delay
    );


    -- -------------------------------------------------------------------------
    -- Second multiplication and final correction
    --
    -- Compute x = B - B * (A*B - 1) = B - B*E
    --
    process (clk_i) begin
        if rising_edge(clk_i) then
            -- Tick 1: input registers
            a_in <= signed('0' & initial_value_delay);
            b_in <= fractional_error;
            c_in_start <= (
                INITIAL_RESULT_RANGE => signed(initial_value_delay),
                ROUNDING_BIT => '1',
                others => '0');
            -- Tick 2: product
            product <= a_in * b_in;
            c_in <= c_in_start;
            -- Tick 3: result
            result <= c_in - product;
        end if;
    end process;
    data_o <= unsigned(result(RESULT_RANGE));
end;
