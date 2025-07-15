-- Transmit UART

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity uart_tx is
    generic (
        BYTE_WIDTH : natural;
        OVERCLOCK : natural
    );
    port (
        clk_i : in std_ulogic;

        baud_clock_i : in std_ulogic;

        -- UART interface
        uart_tx_o : out std_ulogic;
        uart_tx_enable_o : out std_ulogic := '0';

        -- Byte interface
        byte_out_i : in std_ulogic_vector(BYTE_WIDTH-1 downto 0);
        byte_out_valid_i : in std_ulogic;
        byte_out_ready_o : out std_ulogic := '0'
    );
end;

architecture arch of uart_tx is
    signal clock_counter : natural range 0 to OVERCLOCK - 1;
    signal bit_clock : std_ulogic := '0';

    type tx_state_t is (TX_IDLE, TX_ACTIVE);
    signal tx_state : tx_state_t := TX_IDLE;

    signal bit_counter : natural range 0 to BYTE_WIDTH + 1;
    -- This word includes ALL bits to be sent including the
    signal byte_out : std_ulogic_vector(BYTE_WIDTH + 1 downto 0)
        := (others => '1');

begin
    process (clk_i) begin
        if rising_edge(clk_i) then
            -- The bit clock is the baud clock divided by OVERCLOCK, but is only
            -- started when byte transmission is requested
            if tx_state = TX_IDLE then
                clock_counter <= OVERCLOCK - 1;
            elsif baud_clock_i then
                if clock_counter > 0 then
                    clock_counter <= clock_counter - 1;
                else
                    clock_counter <= OVERCLOCK - 1;
                end if;
            end if;
            bit_clock <= to_std_ulogic(clock_counter = 0) and baud_clock_i;

            case tx_state is
                when TX_IDLE =>
                    -- Wait for transmission request, but only check on the baud
                    -- clock so that we properly synchronise our start
                    if byte_out_valid_i and baud_clock_i then
                        -- Acknowledge
                        byte_out_ready_o <= '1';
                        -- Assemble the entire packet to transmit: start bit,
                        -- byte to send (LSB first), and stop bit.
                        byte_out <= '1' & byte_out_i & '0';
                        -- Count off all the bits assembled above
                        bit_counter <= BYTE_WIDTH + 1;
                        tx_state <= TX_ACTIVE;
                    end if;
                when TX_ACTIVE =>
                    -- Advance on bit clock until all bits sent
                    byte_out_ready_o <= '0';
                    if bit_clock then
                        if bit_counter > 0 then
                            byte_out <= shift_right(byte_out, 1);
                            bit_counter <= bit_counter - 1;
                        else
                            tx_state <= TX_IDLE;
                        end if;
                    end if;
            end case;
        end if;
    end process;

    uart_tx_o <= byte_out(0);
    uart_tx_enable_o <= to_std_ulogic(tx_state /= TX_IDLE);
end;
