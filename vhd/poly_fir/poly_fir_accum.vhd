-- Output accumulator for Polyphase FIR

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity poly_fir_accum is
    generic (
        WAYS : natural;
        INPUT_BITS : natural;       -- Bits for a single FIR product term
        INPUT_GAIN : natural;       -- Number of terms added for each output
        FILTER_GAIN : integer;      -- Final filter gain
        PROCESS_DELAY : natural;    -- Validation only
        SATURATE_OUTPUT : boolean   -- Enable output saturation
    );
    port (
        clk_i : in std_ulogic;

        -- Input data
        start_i : in std_ulogic;
        enable_i : in std_ulogic;
        data_i : in signed;

        -- Filtered data
        data_o : out signed;
        overflow_o : out std_ulogic
    );
end;

architecture arch of poly_fir_accum is
    constant ACCUM_LENGTH : natural := 48;
    subtype ACCUM_RANGE is natural range ACCUM_LENGTH-1 downto 0;

    constant OUT_LENGTH : natural := data_o'LENGTH;

    -- Compute the appropriate input and output shifts to fit the desired
    -- result into the accumulator.
    constant TOTAL_BITS : natural := INPUT_BITS + bits(INPUT_GAIN-1);
    -- The binary point for the input data (assuming both taps and data scaled
    -- to nominal +-1 range) is at offset INPUT_BITS-2, and is then shifted
    -- right by INPUT_SHIFT to allow for overflow detection.
    constant INPUT_SHIFT : natural := maximum(TOTAL_BITS - ACCUM_LENGTH, 0);
    -- The final output gain is determined by shifting the input binary point
    -- right by the selected gain (the gain will invariably be a negative number
    -- at this point).
    constant TOP_RESULT_BIT : natural :=
        INPUT_BITS - 2 - INPUT_SHIFT - FILTER_GAIN;
    -- Use this top bit to compute the output bits.
    subtype OUT_RANGE is natural
        range TOP_RESULT_BIT downto TOP_RESULT_BIT - OUT_LENGTH + 1;

    constant ROUNDING_IN : signed(ACCUM_RANGE) := (
        OUT_RANGE'RIGHT-1 => '1',
        others => '0');

    subtype OVF_RANGE is natural range ACCUM_LENGTH-1 downto TOP_RESULT_BIT;
    constant ONES_MASK : signed(OVF_RANGE) := (others => '1');
    signal all_ones : std_ulogic := '0';
    signal all_zeros : std_ulogic := '0';

    signal start_in : std_ulogic := '0';
    signal enable_in : std_ulogic := '0';
    signal data_in : data_i'SUBTYPE := (others => '0');
    signal accum_in : signed(ACCUM_RANGE);
    signal accum : signed(ACCUM_RANGE) := (others => '0');
    signal accum_delay : signed(ACCUM_RANGE);

    signal overflow_out : std_ulogic;
    signal saturated_accum : signed(OUT_RANGE) := (others => '0');
    signal saturated_overflow : std_ulogic := '0';

    -- Try to use DSP for accumulator
    attribute use_dsp : string;
    attribute use_dsp of accum : signal is "YES";

begin
    -- Ensure output fits into result and we have room for rounding bit
    assert OUT_RANGE'RIGHT > 0
        report "Output does not fit into result.  Too much output gain?"
        severity failure;

    -- Process delay from start_i, enable_i, data_i to data_o, overflow_o:
    --
    --  enable_i, start_i, data_i
    --      => enable_in, start_in, data_in
    --      => accum = data_o, overflow_o
    -- plus one extra tick if SATURATE_OUTPUT selected
    assert PROCESS_DELAY = 2 + to_integer(SATURATE_OUTPUT)
        report "Invalid PROCESS_DELAY: " & to_string(PROCESS_DELAY)
        severity failure;


    cond : if WAYS > 1 generate
        signal accum_delay_in : signed(ACCUM_RANGE);

    begin
        delay : entity work.fixed_delay generic map (
            WIDTH => ACCUM_LENGTH,
            DELAY => WAYS - 2
        ) port map (
            clk_i => clk_i,
            enable_i => enable_in,
            data_i => std_ulogic_vector(accum),
            signed(data_o) => accum_delay_in
        );

        timing : entity work.dlyreg generic map (
            WIDTH => ACCUM_LENGTH
        ) port map (
            clk_i => clk_i,
            enable_i => enable_in,
            data_i => std_ulogic_vector(accum_delay_in),
            signed(data_o) => accum_delay
        );
    else generate
        accum_delay <= accum;
    end generate;


    -- Separate out the accumulator input selection from accumulator assignment
    -- so that overflow can be computed in DSP48E compatible way.
    with start_in select
        accum_in <=
            data_in + ROUNDING_IN when '1',
            data_in + accum_delay when others;
    overflow_out <= not all_ones and not all_zeros;

    process (clk_i) begin
        if rising_edge(clk_i) then
            start_in <= start_i;
            enable_in <= enable_i;
            data_in <= shift_right(data_i, INPUT_SHIFT);

            if enable_in then
                accum <= accum_in;
                all_ones  <= to_std_ulogic(accum_in(OVF_RANGE) = ONES_MASK);
                all_zeros <= to_std_ulogic(accum_in(OVF_RANGE) = 0);
            end if;

            -- Saturation
            saturated_accum <= saturate(
                accum(OUT_RANGE), overflow_out, accum(accum'LEFT));
            saturated_overflow <= overflow_out;
        end if;
    end process;

    gen_result : if SATURATE_OUTPUT generate
        data_o <= saturated_accum;
        overflow_o <= saturated_overflow;
    else generate
        data_o <= accum(OUT_RANGE);
        overflow_o <= overflow_out;
    end generate;
end;
