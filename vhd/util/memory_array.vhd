-- An array of memory.  This should be mapped to distributed RAM or block RAM,
-- either by setting RAM_STYLE or by relying on the tools default.
--
-- The delay from read_addr_i to read_data_o is 1 or 2 clock ticks depending on
-- whether the setting of OUTPUT_REG: the REGISTER option is used
-- to reduce the latency requirements on BRAM output.  The precise relationship
-- between read_addr_i, read_strobe_i, and read_data_o depends on OUTPUT_REG and
-- is shown below:
--
--  OUTPUT_REG = NONE
--      read_data_o is updates with read_addr_i, read_strobe_i is ignored
-- clk_i            /       /       /       /       /       /       /       /
-- read_addr_i    --X  A    X  B    X---------------X  C    X------------------
-- read_data_o    --X M[A]  X M[B]  X---------------X M[C]  X------------------
--
--  OUTPUT_REG = LATCHED
--      read_data_o is one tick after read_addr_i, read_strobe_i
-- clk_i            /       /       /       /       /       /       /       /
-- read_addr_i    --X  A    X  B    X---------------X  C    X------------------
-- read_strobe_i  __/^^^^^^^^^^^^^^^\_______________/^^^^^^^\__________________
-- read_data_o    ----------X M[A]  X M[B]                  X M[C]
--
--  OUTPUT_REG = REGISTER
--      read_data_o is two ticks after read_addr_i, read_strobe_i
-- clk_i            /       /       /       /       /       /       /       /
-- read_addr_i    --X  A    X  B    X---------------X  C    X------------------
-- read_strobe_i  __/^^^^^^^^^^^^^^^\_______________/^^^^^^^\__________________
-- read_data_o    ------------------X M[A]  X M[B]                  X M[C]
--
-- Note that properly pipelined operation, where the output only changes in step
-- with read_addr_i is not supported, as this does not appear to be supported by
-- the hardware we want to target.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity memory_array is
    generic (
        ADDR_BITS : natural;
        DATA_BITS : natural;
        -- The memory style can be one of
        --  ""              Use tool default, depends on memory size
        --  "DISTRIBUTED"   Use distributed RAM
        --  "BLOCK"         Use block RAM
        MEM_STYLE : string := "";   -- Default to unspecified

        -- There are three options for the memory output: no registering at all
        -- (only works for distributed RAM), internal latch, and output
        -- register:
        --
        --  NONE
        --      read_data_o is not registered and updates with read_addr_i,
        --      read_strobe_i is ignored
        --  LATCHED
        --      read_data_o updates one tick after read_addr_i and read_strobe_i
        --  REGISTER
        --      read_data_o updates two ticks after read_addr_i and
        --      read_strobe_i
        OUTPUT_REG : string := "LATCHED"; -- or REGISTER

        -- Initial value for memory array
        INITIAL : std_ulogic_vector(DATA_BITS-1 downto 0) := (others => '0');
        READ_DELAY : natural := 0   -- Validation parameter only
    );
    port (
        clk_i : in std_ulogic;

        -- Read interface
        read_strobe_i : in std_ulogic := '1';
        read_addr_i : in unsigned(ADDR_BITS-1 downto 0);
        read_data_o : out std_ulogic_vector(DATA_BITS-1 downto 0);

        -- Write interface
        write_strobe_i : in std_ulogic := '1';
        write_addr_i : in unsigned(ADDR_BITS-1 downto 0);
        write_data_i : in std_ulogic_vector(DATA_BITS-1 downto 0)
    );
end;

architecture arch of memory_array is
    subtype data_t is std_ulogic_vector(DATA_BITS-1 downto 0);
    type memory_t is array(0 to 2**ADDR_BITS-1) of data_t;
    signal memory : memory_t := (others => INITIAL);
    attribute ram_style : string;
    attribute ram_style of memory : signal is MEM_STYLE;

    signal memory_data : std_ulogic_vector(DATA_BITS-1 downto 0);
    signal read_data : std_ulogic_vector(DATA_BITS-1 downto 0)
        := (others => '0');
    signal read_data_out : std_ulogic_vector(DATA_BITS-1 downto 0)
        := (others => '0');

begin
    -- For callers to verify if required:
    --  read_addr_i
    --      => read_data        = read_data_o if OUTPUT_REG = "LATCHED"
    --      => read_data_out    = read_data_o if OUTPUT_REG = "REGISTER"
    assert READ_DELAY = 0 or
        (OUTPUT_REG = "LATCHED" and READ_DELAY = 1) or
        (OUTPUT_REG = "REGISTER" and READ_DELAY = 2)
        report "Invalid READ_DELAY and OUTPUT_REG: "
            & integer'image(READ_DELAY) & ", '" & OUTPUT_REG & "'"
        severity failure;

    memory_data <= memory(to_integer(read_addr_i));
    process (clk_i) begin
        if rising_edge(clk_i) then
            if write_strobe_i = '1' then
                memory(to_integer(write_addr_i)) <= write_data_i;
            end if;

            if read_strobe_i = '1' then
                read_data <= memory_data;
            end if;
            read_data_out <= read_data;
        end if;
    end process;

    select_out :
    if OUTPUT_REG = "NONE" generate
        read_data_o <= memory_data;
    elsif OUTPUT_REG = "LATCHED" generate
        read_data_o <= read_data;
    elsif OUTPUT_REG = "REGISTER" generate
        read_data_o <= read_data_out;
    else generate
        assert false
            report "Invalid OUTPUT_REG: '" & OUTPUT_REG & "'"
            severity failure;
    end generate;
end;
