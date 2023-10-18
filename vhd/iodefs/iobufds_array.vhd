-- Array of IOBUFDS
--
-- Double ended input output buffers

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity iobufds_array is
    generic (
        COUNT : natural := 1;
        IOSTANDARD : string := "DEFAULT";
        DIFF_TERM : boolean := true
    );
    port (
        p_io : inout std_ulogic_vector(COUNT-1 downto 0);
        n_io : inout std_ulogic_vector(COUNT-1 downto 0);
        t_i : in std_ulogic_vector(COUNT-1 downto 0);
        i_i : in std_ulogic_vector(COUNT-1 downto 0);
        o_o : out std_ulogic_vector(COUNT-1 downto 0)
    );
end;

architecture arch of iobufds_array is
begin
    iobufds_array : for i in 0 to COUNT-1 generate
        iobufds_inst : IOBUFDS generic map (
            IOSTANDARD => IOSTANDARD,
            DIFF_TERM => DIFF_TERM
        ) port map (
            IO  => p_io(i),
            IOB => n_io(i),
            T  => t_i(i),
            I  => i_i(i),
            O  => o_o(i)
        );
    end generate;
end;
