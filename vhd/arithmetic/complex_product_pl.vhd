-- Complex sequential product.
--
-- A streamed IQ input is multiplied by a constant IQ input to produce a
-- streamed complex product.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity complex_product_pl is
    generic (
        -- Bits to silently discard from the top
        DISCARD_TOP : natural := 0;
        PROCESS_DELAY : natural := 5
    );
    port (
        clk_i : in std_ulogic;

        -- Constant term (should stay constant for complete I/Q cycle, should
        -- be synchronous with data_i)
        const_cos_i : in signed;
        const_sin_i : in signed;

        -- Streamed term.  The Q term must be strobed with last_i
        valid_i : in std_ulogic;
        last_i : in std_ulogic;
        data_i : in signed;

        -- Streamed output, delayed PROCESS_DELAY ticks from input
        valid_o : out std_ulogic := '0';
        last_o : out std_ulogic := '0';
        data_o : out signed
    );
end;

architecture arch of complex_product_pl is
    constant CONST_WIDTH : natural := const_cos_i'LENGTH;
    constant DATA_WIDTH : natural := data_i'LENGTH;
    constant OUT_WIDTH : natural := data_o'LENGTH;
    constant PRODUCT_WIDTH : natural := CONST_WIDTH + DATA_WIDTH;
    constant ACCUM_WIDTH : natural := PRODUCT_WIDTH + 1;
    -- Compute how many bits we're discarding from the bottom
    constant DISCARD_WIDTH : natural := ACCUM_WIDTH - OUT_WIDTH - DISCARD_TOP;

    constant ROUNDING_BIT : signed(ACCUM_WIDTH-1 downto 0) := (
        DISCARD_WIDTH-1 => '1',
        others => '0');
    subtype OUT_RANGE is natural
        range DISCARD_WIDTH+OUT_WIDTH-1 downto DISCARD_WIDTH;

    -- Stage 1
    signal last_in : std_ulogic := '0';
    signal valid_in : std_ulogic := '0';
    signal real_data_in : data_i'SUBTYPE := (others => '0');
    signal imag_data_in : data_i'SUBTYPE := (others => '0');
    signal real_const_in : const_cos_i'SUBTYPE := (others => '0');
    signal imag_const_in : const_cos_i'SUBTYPE := (others => '0');

    -- Stage 2
    signal last_in2 : std_ulogic := '0';
    signal valid_in2 : std_ulogic := '0';
    signal real_product : signed(PRODUCT_WIDTH-1 downto 0) := (others => '0');
    signal imag_product : signed(PRODUCT_WIDTH-1 downto 0) := (others => '0');

    -- Stage 3
    signal last_in3 : std_ulogic := '0';
    signal valid_in3 : std_ulogic := '0';
    signal real_sum : signed(ACCUM_WIDTH-1 downto 0) := (others => '0');
    signal imag_sum : signed(ACCUM_WIDTH-1 downto 0) := (others => '0');

    -- Stage 4
    signal last_in4 : std_ulogic := '0';
    signal valid_in4 : std_ulogic := '0';
    signal data_out : data_o'SUBTYPE := (others => '0');
    signal data_out_delay : data_o'SUBTYPE := (others => '0');

begin
    -- Processing delay:
    --
    --  const_cos_i, const_sin_i, last_i, valid_i, data_i
    --      => const_{real,imag}_in, {start,valid}_in, {real,imag}_data_in
    --      => {start,valid}_in2, {real,imag}_product
    --      => {start,valid}_in3, {real,imag}_sum
    --      => {start,valid}_in4 ... (waiting for second round of sum)
    --      => last_o, valid_o, data_o
    assert PROCESS_DELAY = 5
        report "Invalid PROCESS_DELAY: " & to_string(PROCESS_DELAY)
        severity failure;

    -- Computing (a+ib)(c+id) = (ac-bd) + i(ad+bc).  In this case write
    --      cc = const_cos_i, cs = const_sin_i,
    --      d1 = data_i at last_i, d0 = data_i otherwise
    -- and we we're computing:
    --
    --  real_sum = d0 * cc - d1 * cs
    --  imag_sum = d0 * ss + d1 * ss
    --
    -- This is made more complicated by the need to pipeline in a way that's
    -- compatible with DSP48E operation.
    process (clk_i) begin
        if rising_edge(clk_i) then
            -- First stage: data into input registers
            last_in <= last_i;
            valid_in <= valid_i;
            real_data_in <= data_i;
            imag_data_in <= data_i;
            if last_i then
                real_const_in <= const_sin_i;
                imag_const_in <= const_cos_i;
            else
                real_const_in <= const_cos_i;
                imag_const_in <= const_sin_i;
            end if;

            -- Second stage: product
            last_in2 <= last_in;
            valid_in2 <= valid_in;
            real_product <= real_const_in * real_data_in;
            imag_product <= imag_const_in * imag_data_in;

            -- Third stage: accumulator
            last_in3 <= last_in2;
            valid_in3 <= valid_in2;
            if valid_in2 then
                if last_in2 then
                    real_sum <= real_sum - real_product;
                    imag_sum <= imag_sum + imag_product;
                else
                    real_sum <= ROUNDING_BIT + real_product;
                    imag_sum <= ROUNDING_BIT + imag_product;
                end if;
            end if;

            -- Fourth stage: wait for sums to complete
            last_in4 <= last_in3;
            valid_in4 <= valid_in3;

            -- Fifth stage: final output
            last_o <= last_in4;
            valid_o <= valid_in4;
            if valid_in4 then
                if last_in4 then
                    data_out <= data_out_delay;
                else
                    data_out <= real_sum(OUT_RANGE);
                    data_out_delay <= imag_sum(OUT_RANGE);
                end if;
            end if;
        end if;
    end process;

    data_o <= data_out;
end;
