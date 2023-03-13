-- Wafer thin wrapper over AXI burst write interface
--
-- Defines defaults for the unused signals, renames the core signals of
-- interest, namely address, burst size, data, and data error.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.axi_defs.all;

entity axi_write_master_wrapper is
    generic (
        ADDRESS_WIDTH : natural;
        LOG_DATA_BYTES : natural
    );
    port (
        -- AXI write master interface
        awaddr_o : out std_ulogic_vector(ADDRESS_WIDTH-1 downto 0);
        awburst_o : out std_ulogic_vector(1 downto 0);
        awsize_o : out std_ulogic_vector(2 downto 0);
        awlen_o : out std_ulogic_vector(7 downto 0);
        awcache_o : out std_ulogic_vector(3 downto 0);
        awlock_o : out std_ulogic_vector(0 downto 0);
        awprot_o : out std_ulogic_vector(2 downto 0);
        awqos_o : out std_ulogic_vector(3 downto 0);
        awregion_o : out std_ulogic_vector(3 downto 0);
        awvalid_o : out std_ulogic;
        awready_i : in std_ulogic;
        --
        wdata_o : out std_ulogic_vector(8 * 2**LOG_DATA_BYTES - 1 downto 0);
        wlast_o : out std_ulogic;
        wstrb_o : out std_ulogic_vector(2**LOG_DATA_BYTES - 1 downto 0);
        wvalid_o : out std_ulogic;
        wready_i : in std_ulogic;
        --
        bresp_i : in std_ulogic_vector(1 downto 0);
        bvalid_i : in std_ulogic;
        bready_o : out std_ulogic;

        -- Wrapped interface
        axi_i : in axi_write_t(
            address(ADDRESS_WIDTH-1 downto LOG_DATA_BYTES),
            data(8 * 2**LOG_DATA_BYTES - 1 downto 0));
        axi_o : out axi_write_ready_t;

        -- This is set if a write error is reported
        write_error_o : out std_ulogic
    );
end;

architecture arch of axi_write_master_wrapper is
begin
    -- Assemble write address from incoming address
    awaddr_o <= (
        ADDRESS_WIDTH-1 downto LOG_DATA_BYTES =>
            std_ulogic_vector(axi_i.address),
        others => '0');
    awburst_o <= "01";                  -- Incrementing address bursts
    awsize_o <= to_std_ulogic_vector_u(LOG_DATA_BYTES, 3); -- Full data per beat
    awlen_o <= std_ulogic_vector(axi_i.burst_length);
    awcache_o <= "0110";                -- Write-through no-allocate caching
    awlock_o <= "0";                    -- No locking required
    awprot_o <= "010";                  -- Unprivileged non-secure data access
    awqos_o <= "0000";                  -- Default QoS
    awregion_o <= "0000";               -- Default region

    -- Copy handshake and burst length
    awvalid_o <= axi_i.address_valid;

    -- Data is mostly passed through
    wdata_o <= axi_i.data;
    wlast_o <= axi_i.data_last;
    wstrb_o <= (others => axi_i.data_enable);
    wvalid_o <= axi_i.data_valid;

    -- We can always accept a write response, report an error if appropriate
    bready_o <= '1';
    write_error_o <= to_std_ulogic(bvalid_i = '1' and bresp_i /= "00");

    axi_o <= (
        address_ready => awready_i,
        data_ready => wready_i,
        write_complete => bvalid_i
    );
end;
