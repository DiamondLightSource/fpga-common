-- Memory array with dual clocked access.  This has much the same interface as
-- memory_array

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity memory_array_dual is
    generic (
        ADDR_BITS : natural;
        DATA_BITS : natural;
        -- The memory style can be one of
        --  ""              Use tool default, depends on memory size
        --  "DISTRIBUTED"   Use distributed RAM
        --  "BLOCK"         Use block RAM
        MEM_STYLE : string := "";   -- Default to unspecified

        -- Two output register options (for NONE use memory_array):
        --
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
        -- Read interface
        read_clk_i : in std_ulogic;
        read_strobe_i : in std_ulogic := '1';
        read_addr_i : in unsigned(ADDR_BITS-1 downto 0);
        read_data_o : out std_ulogic_vector(DATA_BITS-1 downto 0);

        -- Write interface
        write_clk_i : in std_ulogic;
        write_strobe_i : in std_ulogic := '1';
        write_addr_i : in unsigned(ADDR_BITS-1 downto 0);
        write_data_i : in std_ulogic_vector(DATA_BITS-1 downto 0)
    );
end;

architecture arch of memory_array_dual is
    subtype data_t is std_ulogic_vector(DATA_BITS-1 downto 0);
    type memory_t is array(0 to 2**ADDR_BITS-1) of data_t;
    signal memory : memory_t := (others => INITIAL);
    attribute ram_style : string;
    attribute ram_style of memory : signal is MEM_STYLE;

    signal read_data : std_ulogic_vector(DATA_BITS-1 downto 0) := INITIAL;
    signal read_data_out : std_ulogic_vector(DATA_BITS-1 downto 0) := INITIAL;

    -- Mark read_data for false path target, this is needed for timing closure
    -- when the source is distributed RAM
    attribute false_path_dram_to : string;
    attribute false_path_dram_to of read_data : signal is "TRUE";
    attribute DONT_TOUCH : string;
    attribute DONT_TOUCH of read_data : signal is "TRUE";

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

    process (write_clk_i) begin
        if rising_edge(write_clk_i) then
            if write_strobe_i = '1' then
                memory(to_integer(write_addr_i)) <= write_data_i;
            end if;
        end if;
    end process;

    process (read_clk_i) begin
        if rising_edge(read_clk_i) then
            if read_strobe_i = '1' then
                read_data <= memory(to_integer(read_addr_i));
            end if;
            read_data_out <= read_data;
        end if;
    end process;

    select_out :
    if OUTPUT_REG = "LATCHED" generate
        read_data_o <= read_data;
    elsif OUTPUT_REG = "REGISTER" generate
        read_data_o <= read_data_out;
    else generate
        assert false
            report "Invalid OUTPUT_REG: '" & OUTPUT_REG & "'"
            severity failure;
    end generate;
end;
