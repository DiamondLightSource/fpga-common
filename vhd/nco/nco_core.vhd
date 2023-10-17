-- Numerically Controlled Oscillator
--
-- Runs at ADC clock rate, generates both cosine and sine outputs, both scaled
-- and unscaled as appropriate.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.nco_defs.all;

entity nco_core is
    generic (
        -- This delay must match the NCO core delay.  This is the sum of
        -- LOOKUP_DELAY and REFINE_DELAY defined in nco_core plus any delay
        -- added by nco_cos_sin_prepare and nco_cos_sin_octant.
        PROCESS_DELAY : natural := 16
    );
    port (
        clk_i : in std_ulogic;
        phase_advance_i : in angle_t;
        reset_phase_i : in std_ulogic := '0';
        cos_sin_o : out cos_sin_18_t  -- 18 bit unscaled cos/sin
    );
end;

architecture arch of nco_core is
    constant PHASE_DELAY : natural := 3;    -- Defined by phase
    constant COS_SIN_DELAY : natural := 13; -- Defined by cos_sin
    constant TOTAL_DELAY : natural := PHASE_DELAY + COS_SIN_DELAY;

    signal phase : angle_t;

begin
    assert PROCESS_DELAY = TOTAL_DELAY
        report "Invalid PROCESS_DELAY: "
            & to_string(PROCESS_DELAY) & "/=" & to_string(TOTAL_DELAY)
        severity failure;

    -- Phase advance computation for NCO
    nco_phase : entity work.nco_phase generic map (
        PHASE_DELAY => PHASE_DELAY
    ) port map (
        clk_i => clk_i,
        phase_advance_i => phase_advance_i,
        reset_phase_i => reset_phase_i,
        phase_o => phase
    );

    cos_sin : entity work.nco_cos_sin generic map (
        PROCESS_DELAY => COS_SIN_DELAY
    ) port map (
        clk_i => clk_i,
        phase_i => phase,
        cos_sin_o => cos_sin_o
    );
end;
