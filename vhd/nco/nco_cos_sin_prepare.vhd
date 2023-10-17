-- Preparation of lookup

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.nco_defs.all;

entity nco_cos_sin_prepare is
    generic (
        -- This is the delay of the residue_o signal for validation
        PREPARE_DELAY : natural;
        -- The following determine the precise timing of the lookup_o and
        -- octant_o signals.
        LOOKUP_DELAY : natural;     -- Time to look up addr in memory
        RESIDUE_DELAY : natural;    -- Lead time required on residue
        REFINE_DELAY : natural      -- Delay for final octant correction
    );
    port (
        clk_i : in std_ulogic;
        angle_i : in unsigned;

        -- Table lookup
        lookup_o : out lookup_t;
        residue_o : out residue_t := (others => '0');
        -- Octant for final correction
        octant_o : out octant_t
    );
end;

architecture arch of nco_cos_sin_prepare is
    -- In order to meet the timing relationships documented in nco_core the
    -- octant_o and lookup_o delays need to be delayed by the times computed
    -- below.

    -- The lookup table output needs to arrive RESIDUE_DELAY ticks after
    -- residue_o, and we know that this delay is longer than the lookup time.
    constant LOOKUP_DELAY_OUT : natural := RESIDUE_DELAY - LOOKUP_DELAY;

    -- The octant_o fixup output needs to come after all other processing is
    -- complete.  In this case we also need to take account of our internal
    -- delay (residue_o is one tick laster than octant), and so we have the
    -- following critical path:
    --  angle_i = residue
    --      =(PREPARE_DELAY)=> residue_o = refine.residue_i
    --      =(RESIDUE_DELAY+REFINE_DELAY) => refine.cos_sin_o
    constant OCTANT_DELAY_OUT : natural :=
        PREPARE_DELAY + RESIDUE_DELAY + REFINE_DELAY;

    constant ANGLE_WIDTH : natural := angle_i'LENGTH;
    subtype OCTANT_RANGE is natural range ANGLE_WIDTH-1 downto ANGLE_WIDTH-3;
    subtype LOOKUP_RANGE is natural range ANGLE_WIDTH-4 downto ANGLE_WIDTH-13;
    subtype RESIDUE_RANGE is natural range ANGLE_WIDTH-14 downto ANGLE_WIDTH-21;


    signal octant : octant_t;
    signal lookup : lookup_t;
    signal lookup_out : lookup_t := (others => '0');
    signal residue : residue_t;

begin
    -- Delay in this block:
    --  angle_i => lookup_out, residue_o
    assert PREPARE_DELAY = 1
        report "Invalid PREPARE_DELAY: " & to_string(PREPARE_DELAY)
        severity failure;

    -- Split the top 21 bits input angle into its three components
    --
    --   -1    -3 -4   -13 -14   -21
    --  +--------+--------+---------+
    --  | octant | lookup | residue |
    --  +--------+--------+---------+
    --    3 bits   10 bits   8 bits
    octant <= angle_i(OCTANT_RANGE);
    lookup <= angle_i(LOOKUP_RANGE);
    residue <= angle_i(RESIDUE_RANGE);

    -- Compute appropriate lookup and residue fields
    process (clk_i) begin
        if rising_edge(clk_i) then
            -- Start by selecting the correct address.  Even octants go
            -- forwards, odd ones backwards.
            if octant(0) = '0' then
                lookup_out <= lookup;
                residue_o <= residue;
            else
                lookup_out <= not lookup;
                residue_o <= not residue;
            end if;
        end if;
    end process;

    -- Delay lookup so refine.cos_sin_i is early enough
    i_lookup_delay : entity work.fixed_delay generic map (
        DELAY => LOOKUP_DELAY_OUT,
        WIDTH => lookup_t'LENGTH
    ) port map (
        clk_i => clk_i,
        data_i => std_ulogic_vector(lookup_out),
        unsigned(data_o) => lookup_o
    );

    -- Delay octant so refine.cos_sin_o in step with octant_o
    i_octant_delay : entity work.fixed_delay generic map (
        DELAY => OCTANT_DELAY_OUT,
        WIDTH => octant_t'LENGTH
    ) port map (
        clk_i => clk_i,
        data_i => std_ulogic_vector(octant),
        unsigned(data_o) => octant_o
    );
end;
