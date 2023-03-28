-- Simple AXI write slave

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.axi_defs.all;

entity axi_write_slave is
    generic (
        -- Allow limited number of outstanding addresses
        MAX_ADDRESS_COUNT : natural;
        ADDRESS_READY_DELAY : natural := 2
    );
    port (
        clk_i : in std_ulogic;

        axi_i : in axi_write_t;
        axi_o : out axi_write_ready_t;

        -- This can be used to block acceptance of addresses and data during
        -- testing
        block_address_i : in std_ulogic;
        block_data_i : in std_ulogic
    );
end;

architecture arch of axi_write_slave is
    signal address_count : natural := 0;
    signal address_ready : std_ulogic := '0';
    signal data_ready : std_ulogic := '0';
    signal write_complete : std_ulogic := '0';

    signal address_valid_age : natural := ADDRESS_READY_DELAY;

begin
    process (clk_i)
        variable last : std_ulogic;
        variable next_address_count : natural;

    begin
        last := axi_i.data_valid and axi_i.data_last and data_ready;

        next_address_count := address_count;
        if axi_i.address_valid and address_ready then
            next_address_count := next_address_count + 1;
        end if;
        if axi_i.data_valid and axi_i.data_last and data_ready then
            next_address_count := next_address_count - 1;
        end if;

        if rising_edge(clk_i) then
            if axi_i.address_valid then
                if address_valid_age > 0 then
                    address_valid_age <= address_valid_age - 1;
                elsif address_ready then
                    address_valid_age <= ADDRESS_READY_DELAY;
                end if;
            end if;
            address_count <= next_address_count;

            -- Acknowledge address when seen and address count is ok
            if address_ready then
                address_ready <= '0';
            else
                address_ready <=
                    to_std_ulogic(address_valid_age = 0) and
                    to_std_ulogic(next_address_count <= MAX_ADDRESS_COUNT) and
                    axi_i.address_valid and not block_address_i;
            end if;

            data_ready <=
                to_std_ulogic(next_address_count > 0) and not block_data_i;
            write_complete <= last;
        end if;
    end process;

    axi_o <= (
        address_ready => address_ready,
        data_ready => data_ready,
        write_complete => write_complete
    );

    validate : entity work.axi_write_validate port map (
        clk_i => clk_i,
        axi_i => axi_i,
        axi_ready_i => axi_o
    );
end;
