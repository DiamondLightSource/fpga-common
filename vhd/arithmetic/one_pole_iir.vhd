-- Simple one pole filter with pole at 1-2^-N.
--
-- When iir_shift_i is set to N the 3dB point of this filter is at around
--
--      2^-N * sample_frequency / 2pi
--
-- for sufficiently large N (for N = 4 the error is around 3% and halves for
-- each increment of N).

library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity one_pole_iir is
    generic (
        -- Number of concurrent channels of data
        CHANNELS : natural := 1;
        -- Array of selected shifts indexed by iir_shift_i.  If not specified
        -- the input iir_shift_i sets the shift directly.
        SHIFTS : integer_array := (1 to 0 => 0);
        -- Delay from data in to out
        PROCESS_DELAY : natural := 2;
        -- Select one-tick IIR.  Only needed if one channel and an update is
        -- needed on every tick.
        ONE_TICK_IIR : boolean := false;
        -- Can override default delay memory style
        DELAY_MEM_STYLE : string := ""
    );
    port (
        clk_i : in std_ulogic;

        iir_shift_i : in unsigned;

        enable_i : in std_ulogic := '1';
        last_i : in std_ulogic := '1';
        data_i : in signed;

        enable_o : out std_ulogic;
        last_o : out std_ulogic;
        data_o : out signed
    );
end;

architecture arch of one_pole_iir is
    function compute_max_shift return natural is
    begin
        if SHIFTS'LENGTH = 0 then
            -- If no SHIFTS array specified implement full input range of shifts
            return 2**iir_shift_i'LENGTH - 1;
        else
            return maximum(SHIFTS);
        end if;
    end;

    -- Allow for scaling increase.  If we've done our reckoning right there
    -- should be no overflow.
    constant MAX_SHIFT : natural := compute_max_shift;
    constant ACCUM_BITS : natural := data_i'LENGTH + MAX_SHIFT;

    -- Return the top bits from the accumulator
    subtype DATA_OUT_RANGE is natural
        range ACCUM_BITS - 1 downto ACCUM_BITS - data_o'LENGTH;

    -- Accumulator and shifted accumulator
    subtype accum_t is signed(ACCUM_BITS-1 downto 0);
    signal data_in : accum_t := (others => '0');
    signal accum_in : accum_t := (others => '0');
    signal partial_accum : accum_t := (others => '1');
    signal fixup_accum_bit : natural range 0 to 1;
    signal accum_out : accum_t := (others => '0');

    signal shift_in : natural range 0 to MAX_SHIFT;
    signal enable_in : std_ulogic := '0';
    signal last_in : std_ulogic := '1';


begin
    -- Delay from data_i to data_o:
    --  data_i, iir_shift_i = shift_in
    --      => data_in
    --      => accum_out = data_o
    assert PROCESS_DELAY = 2
        report "Incorrect process delay " & integer'image(PROCESS_DELAY)
        severity failure;
    -- Can't combine one-tick and multiple channels
    assert not ONE_TICK_IIR or CHANNELS = 1
        report "Don't use ONE_TICK_IIR with multiple channels"
        severity failure;

    shift_in <=
        SHIFTS(to_integer(iir_shift_i)) when SHIFTS'LENGTH > 0
        else to_integer(iir_shift_i);


    delay : entity work.fixed_delay generic map (
        WIDTH => ACCUM_BITS,
        DELAY => maximum(CHANNELS - 2, 0),
        MEM_STYLE => DELAY_MEM_STYLE
    ) port map (
        clk_i => clk_i,
        enable_i => enable_in,
        data_i => std_ulogic_vector(accum_out),
        signed(data_o) => accum_in
    );


    process (clk_i)
        -- The IIR increment step should be:
        --      y <= x + y - abs_ceiling(y >> N)
        -- where
        --      abs_ceiling(y) = ceiling(y)     for y >= 0
        --      abs_ceiling(y) = floor(y)       for y < 0
        --
        -- Performing this extra adjustment ensures that the accumulator always
        -- decreases and helps to ensure that the accumulator will never
        -- overflow.  This function computes the extra fixup bit which needs to
        -- be added to compute abs_ceiling(y>>N)
        function shift_fixup(x : accum_t; shift : natural) return integer is
            variable result : integer := 0;
        begin
            if x < 0 then
                return 0;
            else
                for i in x'RANGE loop
                    -- Make sure we subtract an extra bit to account for any bit
                    -- that got shifted out.  Without this fixup the accumulator
                    -- will never decay to zero on zero input.
                    if i < shift and x(i) = '1' then
                        return 1;
                    end if;
                end loop;
                return 0;
            end if;
        end;

        variable accum_decay : accum_t;
        variable fixup_bit : natural range 0 to 1;

    begin
        if rising_edge(clk_i) then
            -- Partial calculation of (1 - 2^-N)*y and associated fixup bit
            accum_decay := accum_in - shift_right(accum_in, shift_in);
            fixup_bit := shift_fixup(accum_in, shift_in);

            -- Shift the data in so that the gain of the filter stays the same
            -- when the shift is changed.  This is pipelined.
            data_in <=
                shift_left(resize(data_i, ACCUM_BITS), MAX_SHIFT - shift_in);
            enable_in <= enable_i;
            last_in <= last_i;

            if ONE_TICK_IIR then
                -- If updating on every tick then we need to update the
                -- accumulator in one large step.  This is a bit demanding on
                -- timing as some of the combinatorial paths can be very long.
                if enable_in then
                    accum_out <= accum_decay + data_in - fixup_bit;
                end if;
            else
                -- Otherwise we compute the update in two ticks.  A bit of care
                -- is required to align with the associated channel delay.
                if CHANNELS = 1 or enable_in = '1' then
                    partial_accum <= accum_decay;
                    fixup_accum_bit <= fixup_bit;
                end if;
                if enable_in then
                    accum_out <= partial_accum + data_in - fixup_accum_bit;
                end if;
            end if;
            enable_o <= enable_in;
            last_o <= last_in;
        end if;
    end process;

    data_o <= accum_out(DATA_OUT_RANGE);
end;
