library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.axi_defs.all;

entity burst_generator is
    generic (
        BURST_PREFIX : natural;
        ADDRESS_WIDTH : natural := 16;
        LOG_DATA_BYTES : natural := 2;
        BURST_LENGTH : natural := 16;
        ADDRESS_DELAY : natural := 5;
        DATA_DELAY : natural := 10
    );
    port (
        clk_i : in std_ulogic;
        axi_o : out axi_write_t(
            address(ADDRESS_WIDTH-1 downto LOG_DATA_BYTES),
            data(8 * 2**LOG_DATA_BYTES - 1 downto 0));
        axi_i : in axi_write_ready_t
    );
end;

architecture arch of burst_generator is
    -- Outputs for axi_o.  These are gathered into axi_o at the bottom.
    signal axi_address_valid : std_ulogic := '0';
    signal axi_address : axi_o.address'SUBTYPE;
    signal axi_burst_length : unsigned(7 downto 0);
    signal axi_data_valid : std_ulogic := '0';
    signal axi_data_last : std_ulogic := '0';
    signal axi_data : axi_o.data'SUBTYPE;
    signal axi_data_enable : std_ulogic := '1';

    procedure clk_wait(count : natural := 1) is
    begin
        for i in 0 to count-1 loop
            wait until rising_edge(clk_i);
        end loop;
    end procedure;

    procedure wait_for_ready(signal ready : in std_ulogic) is
    begin
        clk_wait;
        while not ready loop
            clk_wait;
        end loop;
    end;

begin

    -- Address generator
    process
        variable address_counter : integer := 0;
    begin
        clk_wait(10);
        loop
            axi_address <=
                to_unsigned(BURST_PREFIX, 4) &
                to_unsigned(address_counter, axi_address'LENGTH - 4);
            axi_burst_length <= to_unsigned(BURST_LENGTH-1, 8);
            axi_address_valid <= '1';
            wait_for_ready(axi_i.address_ready);
            axi_address_valid <= '0';
            address_counter := address_counter + 1;
            clk_wait(ADDRESS_DELAY);
        end loop;
    end process;

    -- Burst generator
    process
        variable burst_counter : integer := 1;
    begin
        clk_wait(10);
        loop
            -- Generate data burst
            for i in 1 to BURST_LENGTH loop
                axi_data <=
                    to_std_ulogic_vector_u(BURST_PREFIX, 4) &
                    to_std_ulogic_vector_u(burst_counter, 16) &
                    to_std_ulogic_vector_u(i, axi_data'LENGTH - 20);
                axi_data_last <= to_std_ulogic(i = BURST_LENGTH);
                axi_data_valid <= '1';
                wait_for_ready(axi_i.data_ready);
            end loop;
            burst_counter := burst_counter + 1;
            axi_data_valid <= '0';

            clk_wait(DATA_DELAY);
        end loop;
    end process;

    axi_o <= (
        address_valid => axi_address_valid,
        address => axi_address,
        burst_length => axi_burst_length,
        data_valid => axi_data_valid,
        data_last => axi_data_last,
        data => axi_data,
        data_enable => axi_data_enable
    );
end;
