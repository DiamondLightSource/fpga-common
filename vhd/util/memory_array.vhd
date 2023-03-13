-- An array of memory.  This should be mapped to distributed RAM or block RAM,
-- either by setting RAM_STYLE or by relying on the tools default.
--
-- The delay from read_addr_i to read_data_o is 1 or 2 clock ticks depending on
-- whether the setting of OUTPUT_REG: the REGISTER and PIPELINE options are used
-- to reduce the latency requirements on BRAM output.  The precise relationship
-- between read_addr_i, read_strobe_i, and read_data_o depends on OUTPUT_REG and
-- is shown below:
--
--  OUTPUT_REG = BYPASS
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
--  OUTPUT_REG = PIPELINE
--      read_data_o is one tick after read_addr_i, read_strobe_i, but is for
--      the previously strobed address (here Z is the previous strobed address)
-- clk_i            /       /       /       /       /       /       /       /
-- read_addr_i    --X  A    X  B    X---------------X  C    X------------------
-- read_strobe_i  __/^^^^^^^^^^^^^^^\_______________/^^^^^^^\__________________
-- read_data_o    ----------X M[Z]  X M[A]                  X M[B]

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

        -- There are three options for the BRAM output register: bypass it,
        -- register, and pipeline.  These options have the following meaning:
        --
        --  BYPASS
        --      read_data_o updates one tick after read_addr_i and read_strobe_i
        --  REGISTER
        --      read_data_o updates two ticks after read_addr_i and
        --      read_strobe_i
        --  PIPELINE
        --      read_data_o updates one tick after read_strobe_i but reflects
        --      the value from the previous read_addr_i value.
        OUTPUT_REG : string := "BYPASS"; -- or REGISTER or PIPELINE

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

    signal read_data : std_ulogic_vector(DATA_BITS-1 downto 0)
        := (others => '0');
    signal read_data_out : std_ulogic_vector(DATA_BITS-1 downto 0)
        := (others => '0');

    constant DOUBLE_REG : boolean :=
        OUTPUT_REG = "REGISTER" or OUTPUT_REG = "PIPELINE";
    constant PIPELINE_REG : boolean := OUTPUT_REG = "PIPELINE";

begin
    assert DOUBLE_REG or OUTPUT_REG = "BYPASS"
        report "Invalid OUTPUT_REG: '" & OUTPUT_REG & "'"
        severity failure;
    -- For callers to verify if required:
    --  read_addr_i
    --      => read_data        = read_data_o if not DOUBLE_REG
    --      => read_data_out    = read_data_o if DOUBLE_REG
    assert READ_DELAY = 0 or
        (not DOUBLE_REG and READ_DELAY = 1) or
        (DOUBLE_REG and READ_DELAY = 2)
        report "Invalid READ_DELAY and DOUBLE_REG: "
            & integer'image(READ_DELAY) & ", " & to_string(DOUBLE_REG)
        severity failure;

    process (clk_i) begin
        if rising_edge(clk_i) then
            if write_strobe_i = '1' then
                memory(to_integer(write_addr_i)) <= write_data_i;
            end if;

            if read_strobe_i = '1' then
                read_data <= memory(to_integer(read_addr_i));
            end if;

            if read_strobe_i = '1' or not PIPELINE_REG then
                read_data_out <= read_data;
            end if;
        end if;
    end process;

    gen_reg: if DOUBLE_REG generate
        read_data_o <= read_data_out;
    else generate
        read_data_o <= read_data;
    end generate;
end;
