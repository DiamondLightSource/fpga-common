-- Array of IBUFDS
--
-- Double ended input buffers

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity ibufds_array is
    generic (
        COUNT : natural := 1;
        IOSTANDARD : string := "DEFAULT";
        DIFF_TERM : boolean := true;
        PIN_SWAPS : std_ulogic_vector(COUNT-1 downto 0) := (others => '0')
    );
    port (
        p_i : in  std_ulogic_vector(COUNT-1 downto 0);
        n_i : in  std_ulogic_vector(COUNT-1 downto 0);
        o_o : out std_ulogic_vector(COUNT-1 downto 0)
    );
end;

architecture arch of ibufds_array is
begin
    ibufds_array : for i in 0 to COUNT-1 generate
        signal pin : std_ulogic;
        signal pin_b : std_ulogic;
    begin
        -- If pin swapping is required on this input assign n_i to I, otherwise
        -- assign p_i, and similarly for IB.
        pin   <= n_i(i) when PIN_SWAPS(i) else p_i(i);
        pin_b <= p_i(i) when PIN_SWAPS(i) else n_i(i);

        ibufds_inst: IBUFDS generic map (
            IOSTANDARD => IOSTANDARD,
            DIFF_TERM => DIFF_TERM
        ) port map (
            I  => pin,
            IB => pin_b,
            O  => o_o(i)
        );
    end generate;
end;
