-- Output FIFOs for capture bursts

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.axi_defs.all;

entity stream_bursts_fifo is
    generic (
        LOG_BURST_LENGTH : natural;
        ADDRESS_FIFO_DEPTH : natural;
        LOG_DATA_FIFO_DEPTH : natural
    );
    port (
        clk_i : in std_ulogic;

        -- Address output
        -- Note that address_valid_i will not be asserted unless address_ready_o
        -- is already set.
        address_ready_o : out std_ulogic;
        address_valid_i : in std_ulogic;
        address_i : in unsigned;

        -- Data output
        data_ready_o : out std_ulogic;
        data_valid_i : in std_ulogic;
        data_last_i : in std_ulogic;
        data_i : in std_ulogic_vector;
        data_enable_i : in std_ulogic;

        -- Write interface to AXI slave
        axi_o : out axi_write_t;
        axi_i : in axi_write_ready_t
    );
end;

architecture arch of stream_bursts_fifo is
    -- Address handling: place address to left of result
    signal address_out : address_i'SUBTYPE;

    constant BURST_LENGTH : natural := 2**LOG_BURST_LENGTH;

    -- Data handling
    constant DATA_WIDTH : natural := data_i'LENGTH;
    signal data_fifo_in : std_ulogic_vector(DATA_WIDTH + 1 downto 0);
    signal data_fifo_out : std_ulogic_vector(DATA_WIDTH + 1 downto 0);

    -- Outputs for axi_o.  These are gathered into axi_o at the bottom.
    signal axi_address_valid : std_ulogic;
    signal axi_address : unsigned(axi_o.address'RANGE);
    signal axi_burst_length : unsigned(7 downto 0);
    signal axi_data_valid : std_ulogic := '0';
    signal axi_data_last : std_ulogic := '0';
    signal axi_data : std_ulogic_vector(axi_o.data'RANGE);
    signal axi_data_enable : std_ulogic := '0';

    -- Alas, at least with version 2019.2, the following declarations fail on
    -- Vivado with a complaint about unconstrained arrays:
    --     signal axi_address : axi_o.address'SUBTYPE;
    --     signal axi_data : axi_o.data'SUBTYPE;

begin
    -- Address FIFO for burst start address
    address_fifo : entity work.simple_fifo generic map (
        FIFO_DEPTH => ADDRESS_FIFO_DEPTH,
        DATA_WIDTH => address_i'LENGTH
    ) port map (
        clk_i => clk_i,

        write_valid_i => address_valid_i,
        write_ready_o => address_ready_o,
        write_data_i => std_ulogic_vector(address_i),

        read_valid_o => axi_address_valid,
        read_ready_i => axi_i.address_ready,
        unsigned(read_data_o) => address_out
    );
    -- Pad address with zeros at bottom for word addresses within burst
    axi_address <= left_align(address_out, axi_address'LENGTH);
    axi_burst_length <= to_unsigned(BURST_LENGTH-1, 8);


    -- Data FIFO, including data to send plus byte enables bit and end of burst
    -- indicator.
    data_fifo : entity work.fifo generic map (
        FIFO_BITS => LOG_BURST_LENGTH + LOG_DATA_FIFO_DEPTH,
        DATA_WIDTH => DATA_WIDTH + 2
    ) port map (
        clk_i => clk_i,

        write_valid_i => data_valid_i,
        write_ready_o => data_ready_o,
        write_data_i => data_fifo_in,

        read_valid_o => axi_data_valid,
        read_ready_i => axi_i.data_ready,
        read_data_o => data_fifo_out
    );
    data_fifo_in(DATA_WIDTH-1 downto 0) <= data_i;
    data_fifo_in(DATA_WIDTH) <= data_enable_i;
    data_fifo_in(DATA_WIDTH + 1) <= data_last_i;
    -- Pad undersized data with zeros at the bottom to fit the capture word size
    axi_data <= left_align(
        data_fifo_out(DATA_WIDTH-1 downto 0), axi_data'LENGTH);
    axi_data_enable <= data_fifo_out(DATA_WIDTH);
    axi_data_last <= data_fifo_out(DATA_WIDTH + 1) and axi_data_valid;


    -- Sanity check during synthesis
    validate : entity work.axi_write_validate port map (
        clk_i => clk_i,
        axi_i => axi_o,
        axi_ready_i => axi_i
    );

    -- We need to assign axi_o in a single process
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
