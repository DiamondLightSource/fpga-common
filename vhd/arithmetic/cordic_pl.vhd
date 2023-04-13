-- Pipelined CORDIC

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.support.all;

entity cordic_pl is
    generic (
        -- For delay validation when required
        -- The delay from (x_i,y_i) to (mag_o,angle_o) can be computed as
        --  PROCESS_DELAY = 1 + mag_o'LENGTH/2.
        PROCESS_DELAY : natural := 0;
        -- Defining this here makes it easier to default angle_o when unused
        ANGLE_WIDTH : natural := 2
    );
    port (
        clk_i : in std_ulogic;

        x_i : in signed;
        y_i : in signed;

        mag_o : out unsigned;
        angle_o : out signed(ANGLE_WIDTH-1 downto 0)
    );
begin
    -- The two inputs should be of equal length
    assert x_i'LENGTH = y_i'LENGTH
        report "Input vectors must be same length"
        severity failure;
    -- We can't generate more bits than we're given
    assert mag_o'LENGTH <= x_i'LENGTH
        report "Cannot generate enough bits: "
            & to_string(mag_o'LENGTH) & " <= " & to_string(x_i'LENGTH)
        severity failure;
end;

architecture arch of cordic_pl is
    constant INPUT_WIDTH : natural := x_i'LENGTH;
    constant OUTPUT_WIDTH : natural := mag_o'LENGTH;
    constant CORDIC_COUNT : natural := OUTPUT_WIDTH / 2;
    -- We accumulate enough extra bits at the bottom of x to ensure that the
    -- bottom bit error is reasonably low.
    constant EXTRA_BITS : natural := bits(CORDIC_COUNT);
    constant EXTRA_ROUNDING : std_ulogic_vector(EXTRA_BITS-1 downto 0)
        := (EXTRA_BITS-1 => '1', others => '0');
    constant X_WIDTH : natural := INPUT_WIDTH + EXTRA_BITS;


    -- The top n-1 bits of y are redundant and can be ignored.  It would be the
    -- top n bits, but initial growth in x can push values into one more bit.
    function get_y(y : signed; n : natural) return signed is
        constant HIGH_BIT : natural :=
            minimum(INPUT_WIDTH-1, INPUT_WIDTH - n + 1);
    begin
        return resize(y(HIGH_BIT downto 0), INPUT_WIDTH);
    end;

    function shift_y(y : signed; shift : natural) return unsigned is
        constant EXTRA_ZEROS : std_ulogic_vector(EXTRA_BITS-1 downto 0)
            := (others => '0');
    begin
        return unsigned(
            shift_right(get_y(y, shift) & signed(EXTRA_ZEROS), shift));
    end;

    function shift_x(x : unsigned; shift : natural) return signed is
    begin
        return signed(shift_right(x(X_WIDTH-1 downto EXTRA_BITS), shift));
    end;

    function rotate(shift : natural) return signed is
    begin
        return to_signed(integer(
            2.0 ** (ANGLE_WIDTH-1) * arctan(2.0 ** (-shift)) / MATH_PI),
            ANGLE_WIDTH);
    end;


    signal x : unsigned_array(0 to CORDIC_COUNT)(X_WIDTH-1 downto 0)
        := (others => (others => '0'));
    signal y : signed_array(0 to CORDIC_COUNT)(INPUT_WIDTH-1 downto 0)
        := (others => (others => '0'));
    signal angle : signed_array(0 to CORDIC_COUNT)(ANGLE_WIDTH-1 downto 0)
        := (others => (others => '0'));

    signal x_gt_y : std_ulogic;
    signal x_gt_my : std_ulogic;

begin
    -- Process delay is simply CORDIC_COUNT+1
    assert PROCESS_DELAY = 0 or PROCESS_DELAY = CORDIC_COUNT + 1
        report "Invalid PROCESS_DELAY: "
            & to_string(PROCESS_DELAY) & " /= " & to_string(CORDIC_COUNT + 1)
        severity failure;
    assert X_WIDTH >= OUTPUT_WIDTH
        report "Not enough bits for result "
            & to_string(X_WIDTH) & " < " & to_string(OUTPUT_WIDTH)
        severity failure;

    x_gt_y  <= to_std_ulogic(x_i >= y_i);
    x_gt_my <= to_std_ulogic(x_i >= -y_i);

    process (clk_i) begin
        if rising_edge(clk_i) then
            -- Normalise the input by rotating the initial vector into the
            -- quadrant defined by x >= 0, x >= y.
            case std_ulogic_vector'(x_gt_y & x_gt_my) is
                when "11" =>
                    -- Zero rotation
                    x(0) <= unsigned(x_i) & unsigned(EXTRA_ROUNDING);
                    y(0) <= y_i;
                    angle(0) <= (
                        ANGLE_WIDTH-1 downto ANGLE_WIDTH-2 => "00",
                        others => '0');
                when "01" =>
                    -- Rotation by 90 degrees
                    x(0) <= unsigned(y_i) & unsigned(EXTRA_ROUNDING);
                    y(0) <= -x_i;
                    angle(0) <= (
                        ANGLE_WIDTH-1 downto ANGLE_WIDTH-2 => "01",
                        others => '0');
                when "00" =>
                    -- Rotation by 180 degrees
                    x(0) <= unsigned(-x_i) & unsigned(EXTRA_ROUNDING);
                    y(0) <= -y_i;
                    angle(0) <= (
                        ANGLE_WIDTH-1 downto ANGLE_WIDTH-2 => "10",
                        others => '0');
                when "10" =>
                    -- Rotation by 270 degrees
                    x(0) <= unsigned(-y_i) & unsigned(EXTRA_ROUNDING);
                    y(0) <= x_i;
                    angle(0) <= (
                        ANGLE_WIDTH-1 downto ANGLE_WIDTH-2 => "11",
                        others => '0');
                when others =>
            end case;

            -- Loop through the stages
            for n in 1 to CORDIC_COUNT loop
                if get_y(y(n-1), n) >= 0 then
                    x(n) <= x(n-1) + shift_y(y(n-1), n);
                    y(n) <= y(n-1) - shift_x(x(n-1), n);
                    angle(n) <= angle(n-1) + rotate(n);
                else
                    x(n) <= x(n-1) - shift_y(y(n-1), n);
                    y(n) <= y(n-1) + shift_x(x(n-1), n);
                    angle(n) <= angle(n-1) - rotate(n);
                end if;
            end loop;
        end if;
    end process;

    mag_o <= x(CORDIC_COUNT)(X_WIDTH-1 downto X_WIDTH-OUTPUT_WIDTH);
    angle_o <= angle(CORDIC_COUNT);
end;
