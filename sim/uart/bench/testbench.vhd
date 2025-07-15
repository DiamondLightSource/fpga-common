library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.sim_support.all;

entity testbench is
end testbench;

architecture arch of testbench is
    signal clk : std_ulogic := '1';

    procedure clk_wait(count : in natural := 1) is
    begin
        clk_wait(clk, count);
    end procedure;

    constant BYTE_WIDTH : natural := 8;
    constant CLOCK_DIVISOR : natural := 3;
    constant OVERCLOCK : natural := 3;

    signal uart_tx : std_ulogic;
    signal uart_tx_enable : std_ulogic;
    signal uart_rx : std_ulogic;
    signal byte_out : std_ulogic_vector(BYTE_WIDTH-1 downto 0);
    signal byte_out_valid : std_ulogic;
    signal byte_out_ready : std_ulogic;
    signal byte_in : std_ulogic_vector(BYTE_WIDTH-1 downto 0);
    signal byte_in_valid : std_ulogic;

begin
    clk <= not clk after 1 ns;

    uart : entity work.uart generic map (
        BYTE_WIDTH => BYTE_WIDTH,
        CLOCK_DIVISOR => CLOCK_DIVISOR,
        OVERCLOCK => OVERCLOCK
    ) port map (
        clk_i => clk,

        uart_tx_o => uart_tx,
        uart_tx_enable_o => uart_tx_enable,
        uart_rx_i => uart_rx,

        byte_out_i => byte_out,
        byte_out_valid_i => byte_out_valid,
        byte_out_ready_o => byte_out_ready,

        byte_in_o => byte_in,
        byte_in_valid_o => byte_in_valid
    );

    -- Loop YX back to RX
    uart_rx <= uart_tx;

    process
        procedure send(byte : std_ulogic_vector) is
        begin
            byte_out <= byte;
            byte_out_valid <= '1';
            loop
                clk_wait;
                exit when byte_out_ready;
            end loop;
            byte_out_valid <= '0';
            write("Sent " & to_hstring(byte));
        end;
    begin
        byte_out_valid <= '0';

        clk_wait(5);

        send(X"5A");
        send(X"A5");
        send(X"66");

        for i in 1 to 10 loop
            clk_wait(i);
            send(to_std_ulogic_vector_u(i, 8));
        end loop;

        wait;
    end process;

    process (clk) begin
        if rising_edge(clk) then
            if byte_in_valid then
                write("Received " & to_hstring(byte_in));
            end if;
        end if;
    end process;
end;
