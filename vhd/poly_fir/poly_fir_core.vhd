-- This is the FIR core of the Polyphase filter

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity poly_fir_core is
    generic (
        DATA_DELAY : natural;
        PROCESS_DELAY : natural;
        MEM_STYLE : string := "";
        -- Needed to help out Vivado
        DATA_WIDTH : natural
    );
    port (
        clk_i : in std_ulogic;

        enable_i : in std_ulogic;           -- Data input strobe
        data_i : in signed(DATA_WIDTH-1 downto 0);
        taps_i : in signed_array;

        data_o : out signed
    );
end;

architecture arch of poly_fir_core is
    constant TAP_COUNT : natural := taps_i'LENGTH;

    signal delayed_data : signed_array(0 to TAP_COUNT-1)(DATA_WIDTH-1 downto 0)
        := (others => (others => '0'));

begin
    -- Data delays: an N+1 delay here results in an FIR which combines elements
    -- separated by a delay of N ticks.  Each polyphase filter operates on
    -- elements separated by DECIMATION updates, and we have WAYS channels
    -- interleaved, so the delay here is DECIMATION*WAYS+1.
    delayed_data(0) <= data_i;
    delays : for i in 1 to TAP_COUNT-1 generate
        delay : entity work.fixed_delay generic map (
            WIDTH => DATA_WIDTH,
            DELAY => DATA_DELAY + 1,
            MEM_STYLE => MEM_STYLE
        ) port map (
            clk_i => clk_i,
            enable_i => enable_i,
            data_i => std_ulogic_vector(delayed_data(i-1)),
            signed(data_o) => delayed_data(i)
        );
    end generate;


    -- Compute dot product of spanned data and taps.  Each step produces one
    -- polyphase filter result, which needs to be combined in the accumulator.
    --
    -- Overflow cannot occur at this stage unless TAP_COUNT is 32 or more.
    dot_product : entity work.dot_product generic map (
        A_WIDTH => DATA_WIDTH,
        B_WIDTH => taps_i(0)'LENGTH,
        TAP_COUNT => TAP_COUNT,
        PROCESS_DELAY => PROCESS_DELAY
    ) port map (
        clk_i => clk_i,

        enable_i => enable_i,
        a_i => delayed_data,
        b_i => taps_i,

        ab_o => data_o,
        ovf_o => open
    );
end;
