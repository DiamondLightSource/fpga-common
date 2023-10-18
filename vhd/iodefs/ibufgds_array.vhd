-- Array of IBUFGDS
--
-- Double ended clock capable input buffers

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity ibufgds_array is
    generic (
        COUNT : natural := 1;
        IOSTANDARD : string := "DEFAULT";
        DIFF_TERM : boolean := true
    );
    port (
        p_i : in  std_ulogic_vector(COUNT-1 downto 0);
        n_i : in  std_ulogic_vector(COUNT-1 downto 0);
        o_o : out std_ulogic_vector(COUNT-1 downto 0)
    );
end;

architecture arch of ibufgds_array is
begin
    ibufgds_array : for i in 0 to COUNT-1 generate
        ibufgds_inst: IBUFGDS generic map (
            IOSTANDARD => IOSTANDARD,
            DIFF_TERM => DIFF_TERM
        ) port map (
            I  => p_i(i),
            IB => n_i(i),
            O  => o_o(i)
        );
    end generate;
end;
