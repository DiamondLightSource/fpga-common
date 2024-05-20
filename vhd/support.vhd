-- Generic helper and support functions for writing VHDL.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package support is
    -- Some generic unconstrained types
    type signed_array is array(natural range <>) of signed;
    type signed_array_array is array(natural range <>) of signed_array;
    type unsigned_array is array(natural range <>) of unsigned;
    type unsigned_array_array is array(natural range <>) of unsigned_array;
    type vector_array is array(natural range <>) of std_ulogic_vector;
    type vector_array_array is array(natural range <>) of vector_array;
    type integer_array is array(natural range<>) of integer;
    type boolean_array is array(natural range<>) of boolean;

    -- Simple complex number type
    type complex_t is record
        real : signed;
        imag : signed;
    end record;
    type complex_array_t is array(natural range<>) of complex_t;


    -- Returns the number of bits required to represent the value x.  Note that,
    -- for example, bits(x) is 3 for x in the range 4 to 7.
    function bits(x : natural) return natural;


    -- These overloaded functions truncate data to in_width by erasing
    -- the bottom data'length-in_width bits, but with rounding.  Rounding is
    -- simply by adding the highest erased bit to avoid a half-bit bias to
    -- -infinity that would otherwise arise.  If extra_width is specified it
    -- it added to the result size, otherwise the result width is in_width.
    --
    --          |--------- data ---------|  input data
    --      |sss|<----- in_width --->|xxx|  sign extended, truncated, rounded
    --      ==============================
    --      |<------ out_width------>|      result after rounding and extension
    --          = in_width+extra_width
    --
    function round(
        data : unsigned;
        in_width : natural;
        extra_width : natural := 0
    ) return unsigned;

    function round(
        data : signed;
        in_width : natural;
        extra_width : natural := 0
    ) return signed;

    -- Silently truncates data to width by discarding bits to the right.
    function truncate(data : unsigned; width : natural) return unsigned;
    function truncate(data : signed; width : natural) return signed;


    -- Assigns input to output and overflow after discarding the rightmost
    -- offset bits and sets overflow if an overflow occurred during the
    -- assignment to output.  Requires output + offset to be no longer than
    -- input.
    --
    --      |------------------ input ---------------|  input data
    --      |vvvvvvvvs|---------------|<-- offset -->|  extracting result
    --      ==========================================
    --               |---- output ----|                 truncated result
    --      ^^^^^^^^^^
    --       overflow                                   overflow detection
    --
    procedure truncate_result(
        signal output : out signed;
        signal overflow : out std_ulogic;
        input : signed; offset : natural := 0);

    -- Same for unsigned.  In this case of course overflow detection is simpler.
    procedure truncate_result(
        signal output : out unsigned;
        signal overflow : out std_ulogic;
        input : unsigned; offset : natural := 0);


    -- Checks data for consistency, returns '1' if all bits are not the same, ie
    -- '0' is returned if data is all zeros or all ones.
    function overflow_detect(data : signed) return std_ulogic;


    -- Taking overflow into account returns saturated value if necessary.
    function saturate(
        data : signed; overflow : std_ulogic; sign : std_ulogic) return signed;
    function saturate(data : unsigned; overflow : std_ulogic) return unsigned;

    -- Helper function for extracting sign bit for data
    function sign_bit(data : signed) return std_ulogic;

    -- Sign extend a std_ulogic_vector
    function sign_extend(data : std_ulogic_vector; width : natural)
        return std_ulogic_vector;


    -- Vectorised functions for mapping logic operations over bit arrays
    function vector_and(data : std_ulogic_vector) return std_ulogic;
    function vector_or(data : std_ulogic_vector) return std_ulogic;
    function vector_xor(data : std_ulogic_vector) return std_ulogic;
    -- Overloads for arithmetic types
    function vector_and(data : signed) return std_ulogic;
    function vector_or(data : signed) return std_ulogic;
    function vector_xor(data : signed) return std_ulogic;
    function vector_and(data : unsigned) return std_ulogic;
    function vector_or(data : unsigned) return std_ulogic;
    function vector_xor(data : unsigned) return std_ulogic;


    -- Simple type conversions
    function to_std_ulogic(bool : boolean) return std_ulogic;
    function to_std_ulogic(nat : natural range 0 to 1) return std_ulogic;
    function to_integer(data : std_ulogic) return natural;
    function to_integer(data : boolean) return natural;
    function to_boolean(data : std_ulogic) return boolean;
    -- Treats argument as signed
    function to_std_ulogic_vector_s(int : integer; width : natural)
        return std_ulogic_vector;
    -- Treats argument as unsigned
    function to_std_ulogic_vector_u(int : natural; width : natural)
        return std_ulogic_vector;
    function to_unsigned(nat : integer) return unsigned;

    -- Resizing an std_ulogic_vector.  Only works for upsizing
    function resize(vector : std_ulogic_vector; size : natural)
        return std_ulogic_vector;

    -- Places value in the left-most bits of result, padding the rest of result
    -- with zeros
    function left_align(value : std_ulogic_vector; length : natural)
        return std_ulogic_vector;
    function left_align(value : signed; length : natural)
        return signed;
    function left_align(value : unsigned; length : natural)
        return unsigned;

    -- Functions for signed max and min int values.  For unsigned we don't need
    -- these as we can just write (others => '1') and (others => '0').
    function max_int(size : natural) return signed;
    function min_int(size : natural) return signed;


    -- Returns array of length bits with the indexed bit set
    function compute_strobe(
        index : natural; length : natural;
        value : std_ulogic := '1'; initial : std_ulogic := '0')
    return std_ulogic_vector;

    procedure compute_strobe(
        signal output : out std_ulogic_vector; index : natural;
        value : std_ulogic := '1'; initial : std_ulogic := '0');

    -- Reverses order of bits in vector
    function reverse(data : in std_ulogic_vector) return std_ulogic_vector;

    -- Choice between two strings based on boolean, useful for attributes and
    -- generic parameters
    function choose(choice : boolean; if_true : string; if_false : string)
        return string;

    -- Gray code support
    function unsigned_to_gray(value : unsigned) return std_ulogic_vector;
    function gray_to_unsigned(value : std_ulogic_vector) return unsigned;

    -- Up/Down counter support, returns value+up-down, generates assertion
    -- failure on overflow
    function up_down(
        value : unsigned; up : std_ulogic; down : std_ulogic) return unsigned;
end;


package body support is
    function bits(x: natural) return natural is
        variable t : natural := x;
        variable n : natural := 0;
    begin
        while t > 0 loop
            t := t / 2;
            n := n + 1;
        end loop;
        return n;
    end function;

    function round(
        data : unsigned;
        in_width : natural;
        extra_width : natural := 0
    ) return unsigned is
        constant right : natural := data'left - in_width + 1;
        constant out_width : natural := in_width + extra_width;
    begin
        return
            resize(data(data'left downto right), out_width) +
            resize(data(right-1 downto right-1), out_width);
    end function;

    function round(
        data : signed;
        in_width : natural;
        extra_width : natural := 0
    ) return signed is
        constant right : natural := data'left - in_width + 1;
        constant out_width : natural := in_width + extra_width;
    begin
        return
            resize(data(data'left downto right), out_width) +
            resize('0' & data(right-1 downto right-1), out_width);
    end function;


    function truncate(data : unsigned; width : natural) return unsigned is
    begin
        return data(data'LEFT downto data'LEFT-width+1);
    end function;

    function truncate(data : signed; width : natural) return signed is
    begin
        return data(data'LEFT downto data'LEFT-width+1);
    end function;


    function overflow_detect(data : signed) return std_ulogic is
    begin
        -- Detect overflow unless all the bits in top_bits are identical.
        -- If not all ones or not all zeros then we have an overflow.
        return not vector_and(data) and vector_or(data);
    end function;

    procedure truncate_result(
        signal output : out signed;
        signal overflow : out std_ulogic;
        input : signed; offset : natural := 0)
    is
        constant output_left : natural := output'length - 1 + offset;
    begin
        output <= input(output_left downto offset);
        overflow <= overflow_detect(input(input'left downto output_left));
    end;

    procedure truncate_result(
        signal output : out unsigned;
        signal overflow : out std_ulogic;
        input : unsigned; offset : natural := 0)
    is
        constant output_left : natural := output'length - 1 + offset;
    begin
        output <= input(output_left downto offset);
        overflow <= vector_or(input(input'left downto output_left+1));
    end;


    function saturate(
        data : signed; overflow : std_ulogic; sign : std_ulogic) return signed
    is
    begin
        if overflow = '1' then
            if sign = '1' then
                return min_int(data'length);
            else
                return max_int(data'length);
            end if;
        else
            return data;
        end if;
    end;

    function saturate(data : unsigned; overflow : std_ulogic) return unsigned
    is
        constant max_val : data'SUBTYPE := (others => '1');
    begin
        if overflow = '1' then
            return max_val;
        else
            return data;
        end if;
    end;

    function sign_bit(data : signed) return std_ulogic is
    begin
        return data(data'left);
    end;

    function sign_extend(data : std_ulogic_vector; width : natural)
        return std_ulogic_vector is
    begin
        return std_ulogic_vector(resize(signed(data), width));
    end;

    function vector_and(data : std_ulogic_vector) return std_ulogic is
        variable result : std_ulogic := '1';
    begin
        for i in data'range loop
            result := result and data(i);
        end loop;
        return result;
    end function;

    function vector_or(data : std_ulogic_vector) return std_ulogic is
        variable result : std_ulogic := '0';
    begin
        for i in data'range loop
            result := result or data(i);
        end loop;
        return result;
    end function;

    function vector_xor(data : std_ulogic_vector) return std_ulogic is
        variable result : std_ulogic := '0';
    begin
        for i in data'range loop
            result := result xor data(i);
        end loop;
        return result;
    end function;

    function vector_and(data : signed) return std_ulogic is begin
        return vector_and(std_ulogic_vector(data));
    end;
    function vector_or(data : signed) return std_ulogic is begin
        return vector_or(std_ulogic_vector(data));
    end;
    function vector_xor(data : signed) return std_ulogic is begin
        return vector_xor(std_ulogic_vector(data));
    end;
    function vector_and(data : unsigned) return std_ulogic is begin
        return vector_and(std_ulogic_vector(data));
    end;
    function vector_or(data : unsigned) return std_ulogic is begin
        return vector_or(std_ulogic_vector(data));
    end;
    function vector_xor(data : unsigned) return std_ulogic is begin
        return vector_xor(std_ulogic_vector(data));
    end;


    function to_std_ulogic(bool : boolean) return std_ulogic is
    begin
        if bool then
            return '1';
        else
            return '0';
        end if;
    end;

    function to_std_ulogic(nat : natural range 0 to 1) return std_ulogic is
    begin
        case nat is
            when 0 => return '0';
            when 1 => return '1';
        end case;
    end;

    function to_integer(data : std_ulogic) return natural is begin
        if data = '1' then
            return 1;
        else
            return 0;
        end if;
    end;

    function to_integer(data : boolean) return natural is begin
        if data then
            return 1;
        else
            return 0;
        end if;
    end;

    function to_boolean(data : std_ulogic) return boolean is begin
        return data = '1';
    end;

    function to_std_ulogic_vector_s(int : integer; width : natural)
        return std_ulogic_vector
    is begin
        return std_ulogic_vector(to_signed(int, width));
    end;

    function to_std_ulogic_vector_u(int : natural; width : natural)
        return std_ulogic_vector
    is begin
        return std_ulogic_vector(to_unsigned(int, width));
    end;

    function to_unsigned(nat : integer) return unsigned is begin
        return to_unsigned(nat, bits(nat));
    end;


    function resize(vector : std_ulogic_vector; size : natural)
        return std_ulogic_vector
    is
        constant WIDTH_IN : natural := vector'LENGTH;
        variable result : std_ulogic_vector(size-1 downto 0);

    begin
        assert size >= WIDTH_IN
            report "Cannot downsize vector of length " &
                integer'image(WIDTH_IN) & " to " & integer'image(size)
                severity failure;
        assert not vector'ASCENDING
            report "Refusing to resize ascending vector"
            severity failure;

        result := (others => '0');
        result(WIDTH_IN-1 downto 0) := vector;
        return result;
    end;


    function left_align(value : std_ulogic_vector; length : natural)
        return std_ulogic_vector
    is
        variable result : std_ulogic_vector(length-1 downto 0);
    begin
        result := (others => '0');
        result(length - 1 downto length - value'LENGTH) := value;
        return result;
    end;

    function left_align(value : signed; length : natural)
        return signed
    is
        variable result : signed(length-1 downto 0);
    begin
        result := (others => '0');
        result(length - 1 downto length - value'LENGTH) := value;
        return result;
    end;

    function left_align(value : unsigned; length : natural)
        return unsigned
    is
        variable result : unsigned(length-1 downto 0);
    begin
        result := (others => '0');
        result(length - 1 downto length - value'LENGTH) := value;
        return result;
    end;


    function max_int(size : natural) return signed is
        variable result : std_ulogic_vector(size-1 downto 0) := (others => '1');
    begin
        result(size-1) := '0';
        return signed(result);
    end;

    function min_int(size : natural) return signed is
        variable result : std_ulogic_vector(size-1 downto 0) := (others => '0');
    begin
        result(size-1) := '1';
        return signed(result);
    end;


    function compute_strobe(
        index : natural; length : natural;
        value : std_ulogic := '1'; initial : std_ulogic := '0')
    return std_ulogic_vector
    is
        variable result : std_ulogic_vector(0 to length-1)
            := (others => initial);
    begin
        result(index) := value;
        return result;
    end;


    procedure compute_strobe(
        signal output : out std_ulogic_vector; index : natural;
        value : std_ulogic := '1'; initial : std_ulogic := '0') is
    begin
        for n in output'RANGE loop
            output(n) <= value when index = n else initial;
        end loop;
    end;


    function reverse(data : in std_ulogic_vector) return std_ulogic_vector
    is
        variable result : std_ulogic_vector(data'REVERSE_RANGE);
    begin
        for i in data'RANGE loop
            result(i) := data(i);
        end loop;
        return result;
    end;


    function choose(choice : boolean; if_true : string; if_false : string)
        return string is
    begin
        if choice then
            return if_true;
        else
            return if_false;
        end if;
    end function;


    function unsigned_to_gray(value : unsigned) return std_ulogic_vector is
    begin
        -- This is the easy direction!
        return std_ulogic_vector(shift_right(value, 1) xor value);
    end;

    function gray_to_unsigned(value : std_ulogic_vector) return unsigned
    is
        variable result : unsigned(value'RANGE) := unsigned(value);
    begin
        -- This direction requires generating a long carry chain
        for i in result'HIGH - 1 downto result'LOW loop
            result(i) := result(i + 1) xor result(i);
        end loop;
        return result;
    end;


    function up_down(
        value : unsigned; up : std_ulogic; down : std_ulogic) return unsigned is
    begin
        if up and not down then
            assert value < (value'RANGE => '1') severity failure;
            return value + 1;
        elsif not up and down then
            assert value > 0 severity failure;
            return value - 1;
        else
            return value;
        end if;
    end;
end;
