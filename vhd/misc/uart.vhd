-- Simple UART

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity uart is
    generic (
        -- Number of bits in a byte
        BYTE_WIDTH : natural := 8;
        -- Fixed clock divisor for baud clock
        CLOCK_DIVISOR : natural;
        -- Overclocking ratio between baud clock and bit clock.  Defaults to 8,
        -- but can be as low as 3 or 4
        OVERCLOCK : natural := 8
    );
    port (
        clk_i : in std_ulogic;

        -- UART interface
        uart_tx_o : out std_ulogic := '1';
        uart_tx_enable_o : out std_ulogic := '0';
        uart_rx_i : in std_ulogic;

        -- Byte interface
        byte_out_i : in std_ulogic_vector(BYTE_WIDTH-1 downto 0);
        byte_out_valid_i : in std_ulogic;
        byte_out_ready_o : out std_ulogic;

        byte_in_o : out std_ulogic_vector(BYTE_WIDTH-1 downto 0);
        byte_in_valid_o : out std_ulogic
    );
end;

architecture arch of uart is
    signal clock_counter : natural range 0 to CLOCK_DIVISOR - 1;
    signal baud_clock : std_ulogic := '1';

begin
    tx : entity work.uart_tx generic map (
        BYTE_WIDTH => BYTE_WIDTH,
        OVERCLOCK => OVERCLOCK
    ) port map (
        clk_i => clk_i,
        baud_clock_i => baud_clock,

        uart_tx_o => uart_tx_o,
        uart_tx_enable_o => uart_tx_enable_o,

        byte_out_i => byte_out_i,
        byte_out_valid_i => byte_out_valid_i,
        byte_out_ready_o => byte_out_ready_o
    );


    rx : entity work.uart_rx generic map (
        BYTE_WIDTH => BYTE_WIDTH,
        OVERCLOCK => OVERCLOCK
    ) port map (
        clk_i => clk_i,
        baud_clock_i => baud_clock,

        uart_rx_i => uart_rx_i,

        byte_in_o => byte_in_o,
        byte_in_valid_o => byte_in_valid_o
    );


    process (clk_i) begin
        if rising_edge(clk_i) then
            -- Generate the "baud" clock.  In reality this is the "overclocked"
            -- version of the true bit clock, the true bit clock is generated
            -- by transmitter and receiver
            if clock_counter > 0 then
                clock_counter <= clock_counter - 1;
            else
                clock_counter <= CLOCK_DIVISOR - 1;
            end if;
            baud_clock <= to_std_ulogic(clock_counter = 0);
        end if;
    end process;
end;
