-- Array of IDELAY

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

use work.support.all;

entity idelay_array is
    generic (
        COUNT : natural := 1;
        PATTERN : string := "DATA"
    );
    port (
        clk_i : in std_ulogic;
        delay_i : in std_ulogic_vector(4 downto 0);
        delay_o : out vector_array(COUNT-1 downto 0)(4 downto 0);
        strobe_i : in std_ulogic_vector(COUNT-1 downto 0);
        data_i : in std_ulogic_vector(COUNT-1 downto 0);
        data_o : out std_ulogic_vector(COUNT-1 downto 0)
    );
end;

architecture arch of idelay_array is
begin
    idelay_array : for i in 0 to COUNT-1 generate
        idelay_inst : IDELAYE2 generic map (
            IDELAY_TYPE => "VAR_LOAD",
            DELAY_SRC => "IDATAIN",
            SIGNAL_PATTERN => PATTERN,
            REFCLK_FREQUENCY => 200.0,
            HIGH_PERFORMANCE_MODE => "TRUE"
        ) port map (
            C => clk_i,

            -- Value control
            LD => strobe_i(i),
            CNTVALUEIN => delay_i,
            CNTVALUEOUT => delay_o(i),
            CE => '0',
            INC => '0',

            -- Delayed clock
            IDATAIN => data_i(i),
            DATAOUT => data_o(i),

            -- Unused
            DATAIN => '0',
            CINVCTRL => '0',
            REGRST => '0',
            LDPIPEEN => '0'
        );
    end generate;
end;
