-- Implementation of dot product using a cascaded array of DSP units

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity dot_product is
    generic (
        -- Width of a_i: must be <= 25
        A_WIDTH : natural;
        -- Width of b_i: must be <= 18
        B_WIDTH : natural;
        -- Number of taps in arrays
        TAP_COUNT : natural;
        -- By default the bottom bits of the accumulator are returned in ab_o.
        -- This parameter can be used to discard low order bits, in which case
        -- rounding is automatically generated to compensate for this.
        OFFSET_OUT : natural := 0;
        -- Time in ticks from a_i(a_i'RIGHT) to ab_o
        PROCESS_DELAY : natural := 3    -- For validation only
    );
    port (
        clk_i : in std_ulogic;

        enable_i : in std_ulogic := '1';
        a_i : in signed_array(0 to TAP_COUNT-1)(A_WIDTH-1 downto 0);
        b_i : in signed_array(0 to TAP_COUNT-1)(B_WIDTH-1 downto 0);

        ab_o : out signed;
        ovf_o : out std_ulogic
    );
end;

architecture arch of dot_product is
    signal accum_array : signed_array(0 to TAP_COUNT-1)(47 downto 0);

    constant OUT_LENGTH : natural := ab_o'LENGTH;
    subtype OUT_RANGE is natural range
        OFFSET_OUT+OUT_LENGTH-1 downto OFFSET_OUT;

begin
    assert OUT_LENGTH <= 48
        report "Output length too long: " & to_string(OUT_LENGTH)
        severity failure;

    rounding : if OFFSET_OUT = 0 generate
        accum_array(0) <= (others => '0');
    else generate
        accum_array(0) <= (OUT_RANGE'RIGHT-1 => '1', others => '0');
    end generate;

    dot : for i in 0 to TAP_COUNT-1 generate
        constant use_pcin : boolean := i /= 0;
        signal p_out : signed(47 downto 0);
        signal pc_out : signed(47 downto 0);
        signal ovf_out : std_ulogic;
        signal enable_p : std_ulogic;

    begin
        -- Delay the enable for the output P register to take account of the DSP
        -- input and M registers.  Use a default of '1' so that this can be
        -- eliminated if enable_i is not needed.
        delay : entity work.fixed_delay generic map (
            DELAY => 2,
            INITIAL => '1'
        ) port map (
            clk_i => clk_i,
            data_i(0) => enable_i,
            data_o(0) => enable_p
        );

        mac : entity work.dsp48e_mac generic map (
            TOP_RESULT_BIT => OUT_RANGE'LEFT,
            USE_PCIN => use_pcin,
            PROCESS_DELAY => PROCESS_DELAY
        ) port map (
            clk_i => clk_i,
            a_i => a_i(i),
            b_i => b_i(i),
            c_i => accum_array(i),
            en_p_i => enable_p,
            p_o => p_out,
            pc_o => pc_out,
            ovf_o => ovf_out
        );

        last_mac : if i = TAP_COUNT-1 generate
            ab_o <= p_out(OUT_RANGE);
            ovf_o <= ovf_out;
        else generate
            accum_array(i + 1) <= pc_out;
        end generate;
    end generate;
end;
