-- Taps for slow polyphase FIR

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity slow_poly_fir_taps is
    generic (
        READ_DELAY : natural;       -- Delay from tap_address_i to tap_o
        MEM_STYLE : string := ""
    );
    port (
        clk_i : in std_ulogic;

        -- Tap coefficent writing
        start_write_i : in std_ulogic;      -- Resets write counters
        write_tap_i : in std_ulogic;        -- Write value into tap
        tap_i : in signed;                  -- Value to write into tap

        -- Reading taps
        tap_address_i : unsigned;
        tap_o : out signed
    );
end;

architecture arch of slow_poly_fir_taps is
    constant ADDR_BITS : natural := tap_address_i'LENGTH;

    signal write_address : unsigned(ADDR_BITS-1 downto 0);

begin
    mem : entity work.memory_array generic map (
        ADDR_BITS => ADDR_BITS,
        DATA_BITS => tap_o'LENGTH,
        READ_DELAY => READ_DELAY,
        MEM_STYLE => MEM_STYLE
    ) port map (
        clk_i => clk_i,

        write_strobe_i => write_tap_i,
        write_addr_i => write_address,
        write_data_i => std_ulogic_vector(tap_i),

        read_addr_i => tap_address_i,
        signed(read_data_o) => tap_o
    );


    -- Writing to taps
    process (clk_i) begin
        if rising_edge(clk_i) then
            if start_write_i then
                write_address <= (others => '0');
            elsif write_tap_i then
                write_address <= write_address + 1;
            end if;
        end if;
    end process;
end;
