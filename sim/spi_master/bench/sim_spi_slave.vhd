-- Simple simulation of SPI slave with readback

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sim_spi_slave is
    generic (
        ADDRESS_BITS : natural;
        DATA_BITS : natural
    );
    port (
        csn_i : in std_ulogic;
        sclk_i : in std_ulogic;
        mosi_i : in std_ulogic;
        miso_o : out std_ulogic := '0';
        miso_enable_o : out std_ulogic := '0'
    );
end;

architecture arch of sim_spi_slave is
    type spi_state_t is (SPI_STATE_START, SPI_STATE_ADDRESS, SPI_STATE_DATA);
    signal spi_state : spi_state_t := SPI_STATE_START;

    signal r_wn : std_ulogic := '0';
    signal spi_counter : natural := 0;
    signal spi_address : std_ulogic_vector(ADDRESS_BITS-1 downto 0);
    signal spi_data_in : std_ulogic_vector(DATA_BITS-1 downto 0);
    signal spi_data_out : std_ulogic_vector(DATA_BITS-1 downto 0);

    constant STORE_BITS : natural := minimum(ADDRESS_BITS, 6);
    type data_store_t is array(0 to 2**STORE_BITS-1) of
        std_ulogic_vector(DATA_BITS-1 downto 0);
    signal data_store : data_store_t := (others => (others => '0'));
    signal data_address : integer;

    procedure shift_in(
        signal value : inout std_ulogic_vector; bit_in : std_ulogic) is
    begin
        value <= value(value'LEFT-1 downto value'RIGHT) & bit_in;
    end;

begin
    data_address <= to_integer(unsigned(spi_address(STORE_BITS-1 downto 0)));

    process (csn_i, sclk_i) begin
        if falling_edge(csn_i) then
            -- Reset internal capture state on transaction start
            spi_state <= SPI_STATE_START;
            miso_enable_o <= '0';
        elsif rising_edge(csn_i) then
            -- Capture data to memory if approriate at end of transation
            if r_wn = '0' then
                data_store(data_address) <= spi_data_in;
            end if;
            miso_enable_o <= '0';
        elsif rising_edge(sclk_i) then
            -- Data capture on rising edge of sclk
            case spi_state is
                when SPI_STATE_START =>
                    r_wn <= mosi_i;
                when SPI_STATE_ADDRESS =>
                    shift_in(spi_address, mosi_i);
                when SPI_STATE_DATA =>
                    shift_in(spi_data_in, mosi_i);
            end case;
        elsif falling_edge(sclk_i) then
            -- Emit miso data on falling edge of clock and update state
            case spi_state is
                when SPI_STATE_START =>
                    spi_state <= SPI_STATE_ADDRESS;
                    spi_counter <= 0;
                when SPI_STATE_ADDRESS =>
                    if spi_counter = ADDRESS_BITS-1 then
                        spi_state <= SPI_STATE_DATA;
                        spi_data_out <= data_store(data_address);
                        miso_enable_o <= r_wn;
                    else
                        spi_counter <= spi_counter + 1;
                    end if;
                when SPI_STATE_DATA =>
                    shift_in(spi_data_out, '0');
            end case;
        end if;
    end process;
    miso_o <= spi_data_out(spi_data_out'LEFT);
end;
