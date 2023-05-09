-- SPI master for controlling PLL, ADC and DAC on FMC500 card.
--
-- Fortunately all three devices seem to use very similar styles of SPI control
-- interface.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity spi_master is
    generic (
        LOG_SCLK_DIVISOR : natural;
        ADDRESS_BITS : natural;
        DATA_BITS : natural
    );
    port (
        clk_i : in std_ulogic;

        -- SPI interface
        csn_o : out std_ulogic := '1';   -- SPI slave chip select
        sclk_o : out std_ulogic := '0';  -- SPI clock
        mosi_o : out std_ulogic;         -- SPI data to slave
        moen_o : out std_ulogic := '0';  -- Output enable for mosi_o
        miso_i : in std_ulogic;          -- SPI data from slave

        -- Command interface
        start_i : in std_ulogic;         -- Triggers start of SPI
        r_wn_i : in std_ulogic;          -- Read/Write selection
        command_i : in std_ulogic_vector(ADDRESS_BITS-1 downto 0);
        data_i : in std_ulogic_vector(DATA_BITS-1 downto 0);
        busy_o : out std_ulogic := '0';  -- Set until SPI command complete
        response_o : out std_ulogic_vector(DATA_BITS-1 downto 0)
    );
end;

architecture arch of spi_master is
    constant OUT_BITS : natural := 1 + ADDRESS_BITS + DATA_BITS;

    -- Clock generator
    signal divisor : unsigned(LOG_SCLK_DIVISOR downto 0) := (others => '0');
    signal sclk : std_ulogic;
    signal last_sclk : std_ulogic;
    signal sclk_rising : boolean;
    signal sclk_falling : boolean;

    signal data_out : std_ulogic_vector(OUT_BITS-1 downto 0) := (others => '0');
    signal data_in : std_ulogic_vector(DATA_BITS-1 downto 0);
    signal read : boolean;

    type spi_state is (IDLE, STARTING, COMMAND, DATA, ENDING);
    signal state : spi_state := IDLE;
    signal cmd_counter : unsigned(bits(ADDRESS_BITS)-1 downto 0);
    signal data_counter : unsigned(bits(DATA_BITS-1)-1 downto 0);
    signal transmit : boolean;

begin
    sclk <= divisor(LOG_SCLK_DIVISOR);
    sclk_rising  <= sclk = '1' and last_sclk = '0';
    sclk_falling <= sclk = '0' and last_sclk = '1';
    transmit <= state = COMMAND or state = DATA;

    process (clk_i) begin
        if rising_edge(clk_i) then
            divisor <= divisor + 1;
            last_sclk <= sclk;

            case state is
                when IDLE =>
                    if start_i = '1' then
                        cmd_counter <=
                            to_unsigned(ADDRESS_BITS, bits(ADDRESS_BITS));
                        data_counter <=
                            to_unsigned(DATA_BITS-1, bits(DATA_BITS-1));
                        state <= STARTING;
                    end if;
                when STARTING =>
                    if sclk_falling then
                        csn_o <= '0';
                        moen_o <= '1';
                        state <= COMMAND;
                    end if;
                when COMMAND =>
                    if sclk_falling then
                        cmd_counter <= cmd_counter - 1;
                        if cmd_counter = 0 then
                            moen_o <= to_std_ulogic(not read);
                            state <= DATA;
                        end if;
                    end if;
                when DATA =>
                    if sclk_falling then
                        data_counter <= data_counter - 1;
                        if data_counter = 0 then
                            moen_o <= '0';
                            state <= ENDING;
                        end if;
                    end if;
                when ENDING =>
                    if sclk_rising then
                        csn_o <= '1';
                    end if;
                    if sclk_falling then
                        state <= IDLE;
                    end if;
            end case;

            if state = IDLE and start_i = '1' then
                -- Load data and read control line on start command
                data_out <= r_wn_i & command_i & data_i;
                read <= r_wn_i = '1';
            elsif sclk_falling and transmit then
                -- Shift data out on falling edge
                data_out <= data_out(OUT_BITS-2 downto 0) & '0';
            end if;

            -- Shift data in on falling edge.
            if sclk_falling and state = DATA then
                data_in <= data_in(DATA_BITS-2 downto 0) & miso_i;
            end if;

            -- Generate SCLK from our rising/falling edge events to ensure clock
            -- is in sync with our data outputs.
            if transmit then
                sclk_o <= sclk;
            else
                sclk_o <= '0';
            end if;
        end if;
    end process;

    mosi_o <= data_out(OUT_BITS-1);
    busy_o <= to_std_ulogic(state /= IDLE);
    response_o <= data_in;
end;
