-- UART receiver

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity uart_rx is
    generic (
        BYTE_WIDTH : natural;
        OVERCLOCK : natural
    );
    port (
        clk_i : in std_ulogic;

        baud_clock_i : in std_ulogic;

        uart_rx_i : in std_ulogic;

        byte_in_o : out std_ulogic_vector(BYTE_WIDTH-1 downto 0);
        byte_in_valid_o : out std_ulogic := '0'
    );
end;

architecture arch of uart_rx is
    constant SAMPLE_DELAY : natural := OVERCLOCK / 2 - 1;

    signal delay_counter : natural range 0 to SAMPLE_DELAY;

    signal clock_counter : natural range 0 to OVERCLOCK - 1 := OVERCLOCK - 1;
    signal bit_clock : std_ulogic := '0';

    type rx_state_t is (RX_IDLE, RX_START, RX_ACTIVE, RX_STOP);
    signal rx_state : rx_state_t := RX_IDLE;

    signal uart_rx : std_ulogic;
    signal bit_counter : natural range 0 to BYTE_WIDTH - 1;

begin
    sync : entity work.sync_bit generic map (
        INITIAL => '1'
    ) port map (
        clk_i => clk_i,
        bit_i => uart_rx_i,
        bit_o => uart_rx
    );

    process (clk_i) begin
        if rising_edge(clk_i) then
            -- Run the bit clock while we are capturing
            case rx_state is
                when RX_ACTIVE | RX_STOP =>
                    if baud_clock_i then
                        if clock_counter > 0 then
                            clock_counter <= clock_counter - 1;
                        else
                            clock_counter <= OVERCLOCK - 1;
                        end if;
                    end if;
                when others =>
                    clock_counter <= OVERCLOCK - 1;
            end case;
            bit_clock <= to_std_ulogic(clock_counter = 0) and baud_clock_i;

            -- Wait for a start bit and then delay for half a bit period before
            -- starting the bit clock, running for 8 bits, before finally
            -- re-enabling during the stop bit.
            case rx_state is
                when RX_IDLE =>
                    -- Wait for falling edge of signal
                    if uart_rx = '0' then
                        delay_counter <= SAMPLE_DELAY;
                        bit_counter <= BYTE_WIDTH - 1;
                        rx_state <= RX_START;
                    end if;
                when RX_START =>
                    if baud_clock_i then
                        if delay_counter > 0 then
                            delay_counter <= delay_counter - 1;
                        else
                            rx_state <= RX_ACTIVE;
                        end if;
                    end if;
                when RX_ACTIVE =>
                    if bit_clock then
                        byte_in_o <= shift_right(byte_in_o, 1, uart_rx);
                        if bit_counter > 0 then
                            bit_counter <= bit_counter - 1;
                        else
                            byte_in_valid_o <= '1';
                            rx_state <= RX_STOP;
                        end if;
                    end if;
                when RX_STOP =>
                    byte_in_valid_o <= '0';
                    if bit_clock then
                        rx_state <= RX_IDLE;
                    end if;
            end case;
        end if;
    end process;
end;
