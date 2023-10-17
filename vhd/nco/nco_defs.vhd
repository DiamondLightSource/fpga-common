library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

package nco_defs is
    type cos_sin_t is record
        cos : signed;
        sin : signed;
    end record;

    -- Two different sizes of cos/sin.  We output an unscaled 18-bit value for
    -- frequency shifts.  Also an internal 19-bit value is returned by table
    -- lookup (the top bit is always zero) before refinement.
    subtype cos_sin_18_t is cos_sin_t(cos(17 downto 0), sin(17 downto 0));
    subtype cos_sin_19_t is cos_sin_t(cos(18 downto 0), sin(18 downto 0));

    -- Global phase and phase advance
    subtype angle_t is unsigned(47 downto 0);
    subtype short_angle_t is unsigned(31 downto 0);

    -- For calculation the angle is split into three parts: octant, lookup, and
    -- 8 bits of residue.
    subtype octant_t is unsigned(2 downto 0);
    subtype lookup_t is unsigned(9 downto 0);
    subtype residue_t is unsigned(7 downto 0);

    -- 10 bit lookup
    subtype cos_sin_addr_t is unsigned(9 downto 0);

    function to_angle_t(angle : unsigned) return angle_t;
end;

package body nco_defs is
    function to_angle_t(angle : unsigned) return angle_t is
        constant IN_WIDTH : natural := angle'LENGTH;
        constant OUT_WIDTH : natural := angle_t'LENGTH;
    begin
        return (
            OUT_WIDTH-1 downto OUT_WIDTH-IN_WIDTH => angle,
            others => '0');
    end;
end;
