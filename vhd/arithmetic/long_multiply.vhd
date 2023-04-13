-- Implements 25 x 35 bit multiplication with cascaded DSP48E units

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity long_multiply is
    generic (
        -- Bits to discard from the top, giving extra output gain.  If this left
        -- equal to zero overflow_o can be ignored.
        DISCARD_TOP : natural := 0;
        PROCESS_DELAY : natural := 4    -- For timing validation
    );
    port (
        clk_i : in std_ulogic;
        a_i : in signed;                -- Up to 25 bits wide
        b_i : in signed;                -- Up to 35 bits wide
        ab_o : out signed;              -- Up to 60 bits wide
        overflow_o : out std_ulogic
    );
end;

architecture arch of long_multiply is
    -- Structure of dual multiplier, designed to fit into a cascaded pair of
    -- DSP48E units.  Note the 17 bit shift is part of the DSP fabric!
    --                +---------------------------+
    --                |       a_in * b_low        | (43 bits)
    --                +---------------------------+
    --                       +
    --  +---------------------------+
    --  |       a_in * b_high       |<- 17 bits ->| (43 bits)
    --  +---------------------------+
    --                      =
    --  +-----------------------------------------+
    --  |               a_in * b_in               | (60 bits)
    --  +-----------------------------------------+
    --       +---------------+
    --  |    |      ab_o     |
    --  |    +---------------+
    --  |<-->|
    --   DISCARD_TOP bits
    --
    -- Inputs are automatically widened to their maximum widths, so the only
    -- preparation required is to figure out where the output bits come from.

    constant TOP_BIT_OUT : natural := a_i'LENGTH + b_i'LENGTH - DISCARD_TOP - 1;
    constant BOTTOM_BIT_OUT : natural := TOP_BIT_OUT - ab_o'LENGTH + 1;

    -- Overflow detection mask, zero bits are checked for equality.  We check
    -- topmost result bit and on up.
    subtype OVF_RANGE is natural range 42 downto TOP_BIT_OUT-17;
    constant ONES_MASK : signed(OVF_RANGE) := (others => '1');


    function rounding_bit return signed is
        variable result : signed(47 downto 0) := (others => '0');
    begin
        if BOTTOM_BIT_OUT > 0 and BOTTOM_BIT_OUT < 48 then
            result(BOTTOM_BIT_OUT - 1) := '1';
        end if;
        return result;
    end;


    -- Input normalisation
    signal a_in : signed(24 downto 0);
    signal b_in : signed(34 downto 0);

    -- Given b_i = b_low + 2^17 b_high we compute
    --  a_i * b_i = a_i * b_low + 2^17 a_i * b_high
    signal b_low : signed(17 downto 0);
    signal b_high : signed(17 downto 0);

    -- Low order
    signal a_low_in : signed(24 downto 0);
    signal b_low_in : signed(17 downto 0);
    signal m_low : signed(42 downto 0);
    signal p_low : signed(47 downto 0);
    signal p_low_out : signed(16 downto 0);

    -- High order
    signal a_high_in : signed(24 downto 0);
    signal b_high_in : signed(17 downto 0);
    signal a_high_in2 : signed(24 downto 0);
    signal b_high_in2 : signed(17 downto 0);
    signal m_high : signed(42 downto 0);
    signal p_high : signed(42 downto 0);
    signal p_high_out : signed(42 downto 0);

    -- Overflow detection
    signal all_ones : std_ulogic;
    signal all_zeros : std_ulogic;

    -- Don't let input registers get eaten by the DSP
    attribute DONT_TOUCH : string;
    attribute DONT_TOUCH of a_i : signal is "yes";
    attribute DONT_TOUCH of b_i : signal is "yes";

begin
    -- Processing delay:
    --  a_i, b_i = a_in, b_in
    --      => a_low_in, a_high_in, b_low_in, b_high_in
    --      => m_low, a_high_in2, b_high_in2
    --      => p_low, m_high
    --      => p_low_out, p_high_out = ab_o
    assert PROCESS_DELAY = 4
        report "Invalid PROCESS_DELAY: " & to_string(PROCESS_DELAY)
        severity failure;

    -- Sanity checks for input argument sizes
    assert a_i'LENGTH <= 25
        report "a_i too long: " & to_string(a_i'LENGTH) & " > 25"
        severity failure;
    assert b_i'LENGTH <= 35
        report "b_i too long: " & to_string(b_i'LENGTH) & " > 35"
        severity failure;
    assert b_i'LENGTH > 18
        report "Don't use long_multiply for a short multiply!"
        severity failure;

    -- Normalise input lengths to full size
    a_in <= resize(a_i, 25);
    b_in <= resize(b_i, 35);

    -- Separate b_in into low and high halves
    b_low <= '0' & b_in(16 downto 0);
    b_high <= b_in(34 downto 17);

    -- This is separated out to facilitate overflow computation
    p_high <= m_high + p_low(47 downto 17);

    process (clk_i) begin
        if rising_edge(clk_i) then
            -- First low order multiplier
            a_low_in <= a_in;
            b_low_in <= b_low;
            m_low <= a_low_in * b_low_in;
            p_low <= m_low + rounding_bit;
            p_low_out <= p_low(16 downto 0);

            -- Second high order multipler.  Needs extra 1 tick of delay to
            -- align with the p_low term we need
            a_high_in <= a_in;
            b_high_in <= b_high;
            a_high_in2 <= a_high_in;
            b_high_in2 <= b_high_in;
            m_high <= a_high_in2 * b_high_in2;
            p_high_out <= p_high;
            all_ones <= to_std_ulogic(p_high(OVF_RANGE) = ONES_MASK);
            all_zeros <= to_std_ulogic(p_high(OVF_RANGE) = 0);
        end if;
    end process;

    gen_out : if BOTTOM_BIT_OUT >= 17 generate
        ab_o <= p_high_out(TOP_BIT_OUT-17 downto BOTTOM_BIT_OUT-17);
    else generate
        ab_o <= p_high_out(TOP_BIT_OUT-17 downto 0) &
                p_low_out(16 downto BOTTOM_BIT_OUT);
    end generate;
    overflow_o <= not all_ones and not all_zeros;
end;
