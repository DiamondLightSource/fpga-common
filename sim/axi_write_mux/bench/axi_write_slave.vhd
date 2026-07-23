-- Simple AXI write slave

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.support.all;
use work.axi_defs.all;

entity axi_write_slave is
    generic (
        COMPLETE_DELAY : natural := 40;
        ADDRESS_FIFO_BITS : natural := 0
    );
    port (
        clk_i : in std_ulogic;

        axi_i : in axi_write_t;
        axi_o : out axi_write_ready_t := (others => '0')
    );
end;

architecture arch of axi_write_slave is
    signal address_valid : std_ulogic := '0';
    signal address_ready : std_ulogic := '1';
    signal address : axi_i.address'SUBTYPE;

    signal last_seen : std_ulogic := '1';

    -- Delay line for completion
    signal completion : std_ulogic_vector(0 to COMPLETE_DELAY)
        := (others => '0');

begin
    address_queue : entity work.fifo generic map (
        FIFO_BITS => ADDRESS_FIFO_BITS,
        DATA_WIDTH => axi_i.address'LENGTH
    ) port map (
        clk_i => clk_i,

        write_valid_i => axi_i.address_valid,
        write_ready_o => axi_o.address_ready,
        write_data_i => std_ulogic_vector(axi_i.address),

        read_valid_o => address_valid,
        read_ready_i => address_ready,
        unsigned(read_data_o) => address
    );


    process (clk_i)
        variable last : std_ulogic;
        variable linebuffer : line;

    begin
        if rising_edge(clk_i) then
            if axi_i.data_valid and axi_o.data_ready then
                last_seen <= axi_i.data_last;
                last := axi_i.data_last;
            else
                last := last_seen;
            end if;

            -- Alternate between sending data and accepting an address
            if address_ready then
                -- Look for an incoming address
                if address_valid then
                    write(linebuffer,
                        "@ " & to_string(now, unit => ns) &
                        " " & to_hstring(address & "00") & ":");
                    address_ready <= '0';
                end if;
            else
                -- Let data pass until end of burst
                if axi_i.data_valid and axi_o.data_ready then
                    write(linebuffer, " " & to_hstring(axi_i.data));
                    if last then
                        writeline(output, linebuffer);
                        address_ready <= '1';
                    end if;
                end if;
            end if;

            -- Completion handling
            completion <=
                completion(1 to completion'RIGHT) &
                (axi_i.data_valid and axi_o.data_ready and axi_i.data_last);
        end if;
    end process;

    axi_o.data_ready <= not address_ready;
    axi_o.write_complete <= completion(0);
end;
