-- Numerically Controlled Oscillator
--
-- Runs at ADC clock rate, generates both cosine and sine outputs, both scaled
-- and unscaled as appropriate.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.nco_defs.all;

entity nco_cos_sin is
    generic (
        -- Delay from phase_i to valid cos_sin_o
        PROCESS_DELAY : natural := 13
    );
    port (
        clk_i : in std_ulogic;
        phase_i : in unsigned;
        cos_sin_o : out cos_sin_18_t  -- 18 bit unscaled cos/sin
    );
end;

architecture arch of nco_cos_sin is
    -- The figure below shows the required timing relationships between the
    -- stages of signal processing:
    --
    --              [prepare]
    --      +-----------+-----------+
    --      | octant    | residue   | lookup
    --      |           O.......... | ................................
    --      |           |           O.................          ^
    --      |           |           |           ^               | RESIDUE_
    --      |           |      [lookup_table]   | LOOKUP_DELAY  | DELAY
    --      |           |           | raw       v               v
    --      |           |           O.................................
    --      |           +-----+-----+       ^
    --      |              [refine]         | REFINE_DELAY
    --      |                 | refined     v
    --      O.................O..................
    --      |                 |
    --      +--------+--------+
    --         [fixup_octant]
    --
    -- The following delays are checked by the appropriate component below and
    -- need to be used to ensure that the various processing stages are in step.
    constant LOOKUP_DELAY : natural := 2;   -- Defined by lookup_table
    constant REFINE_DELAY : natural := 5;   -- Defined by refine
    constant RESIDUE_DELAY : natural := 4;  -- Defined by refine

    -- Total delay for external check
    constant PREPARE_DELAY : natural := 1;  -- Defined by prepare
    constant OCTANT_DELAY : natural := 3;   -- Defined by octant
    constant TOTAL_DELAY : natural :=
        PREPARE_DELAY + RESIDUE_DELAY + REFINE_DELAY + OCTANT_DELAY;

    -- Lookup table
    signal lookup : lookup_t;
    signal cos_sin_raw : cos_sin_19_t;

    -- Refinement
    signal octant : octant_t;
    signal residue : residue_t;
    signal cos_sin_refined : cos_sin_18_t;

begin
    assert PROCESS_DELAY = TOTAL_DELAY
        report "Invalid PROCESS_DELAY: "
            & to_string(PROCESS_DELAY) & "/=" & to_string(TOTAL_DELAY)
        severity failure;

    -- Split angle into octant, lookup and residue.  The returned octant is
    -- delayed as appropriate for the final correction.
    prepare : entity work.nco_cos_sin_prepare generic map (
        PREPARE_DELAY => PREPARE_DELAY,
        LOOKUP_DELAY => LOOKUP_DELAY,
        RESIDUE_DELAY => RESIDUE_DELAY,
        REFINE_DELAY => REFINE_DELAY
    ) port map (
        clk_i => clk_i,
        angle_i => phase_i,
        lookup_o => lookup,
        residue_o => residue,
        octant_o => octant
    );

    -- Lookup table
    lookup_table : entity work.nco_cos_sin_table generic map (
        LOOKUP_DELAY => LOOKUP_DELAY
    ) port map (
        clk_i => clk_i,
        addr_i => lookup,
        cos_sin_o => cos_sin_raw
    );

    -- Refine the lookup by linear interpolation
    refine : entity work.nco_cos_sin_refine generic map (
        RESIDUE_DELAY => RESIDUE_DELAY,
        REFINE_DELAY => REFINE_DELAY
    ) port map (
        clk_i => clk_i,
        residue_i => residue,
        cos_sin_i => cos_sin_raw,
        cos_sin_o => cos_sin_refined
    );

    -- Flip the final result into place according to the original octant
    fixup_octant : entity work.nco_cos_sin_octant generic map (
        OCTANT_DELAY => OCTANT_DELAY
    ) port map (
        clk_i => clk_i,
        octant_i => octant,
        cos_sin_i => cos_sin_refined,
        cos_sin_o => cos_sin_o
    );
end;
