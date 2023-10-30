-- Array of OBUFDS
--
-- Double ended differential output buffers

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity obufds_array is
    generic (
        COUNT : natural := 1;
        IOSTANDARD : string := "DEFAULT";
        PIN_SWAPS : std_ulogic_vector(COUNT-1 downto 0) := (others => '0')
    );
    port (
        i_i : in  std_ulogic_vector(COUNT-1 downto 0);
        p_o : out std_ulogic_vector(COUNT-1 downto 0);
        n_o : out std_ulogic_vector(COUNT-1 downto 0)
    );
end;

architecture arch of obufds_array is
begin
    obufds_array : for i in 0 to COUNT-1 generate
        signal pin : std_ulogic;
        signal pin_b : std_ulogic;
    begin
        obufds_inst: OBUFDS generic map (
            IOSTANDARD => IOSTANDARD
        ) port map (
            I  => i_i(i),
            O  => pin,
            OB => pin_b
        );

        -- If pin swapping is required on this input assign O to n_o, otherwise
        -- assign to n_p, and similarly for OB.
        p_o(i) <= pin_b when PIN_SWAPS(i) else pin;
        n_o(i) <= pin when PIN_SWAPS(i) else pin_b;
    end generate;
end;
