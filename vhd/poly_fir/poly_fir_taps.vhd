-- Taps for multi-channel Polyphase FIR

-- Timing the taps out is rather tricky.  Pacing is controlled by three signals:
--
--  enable_i
--      This is set for each incoming data point, and is used to pace the
--      stepping of tap outputs
--  next_i
--      This is used to synchronise advancing taps to the next desired filter.
--  last_i
--      This is used to synchronise the cycle of filters.
--
-- The set of taps is advanced to the next filter in sync with next_i, but each
-- tap needs to be advanced one enabled tick after the other: this ensures that
-- the computed filter sees the right taps at the right time.
--
--              /   /   /   /   /   /   /   /   /   /   /   /   /
--               ___                     ___
--  next_i   ___/   \___________________/   \______________________
--               ___     ___     ___     ___        ________
--  enable_i ___/   \___/   \___/   \___/   \______/        \______
--           _______ _______________________ ______________________
--  bank_ix  __ N __X__ N+1 ________________X__ N+2 _______________
--            ______ _______________________ ______________________
--  taps_o(0) ______X__ A0(N) ______________X__ A0(N+1) ___________
--            ______________ ___________________________ __________
--  taps_o(1) ___ A1(N-1) __X__ A1(N) __________________X__ A1(N+1)
--
-- Note that there is a one tick delay from next_i to the tap output.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity poly_fir_taps is
    generic (
        TAP_COUNT : natural;
        DECIMATION : natural;
        MEM_STYLE : string := "";
        PIPELINE_WRITE_TAPS : boolean := false
    );
    port (
        clk_i : in std_ulogic;

        -- Tap coefficent writing
        start_write_i : in std_ulogic;      -- Resets write counters
        write_tap_i : in std_ulogic;        -- Write value into tap
        tap_i : in signed;                  -- Value to write into tap

        -- Tap output
        next_i : in std_ulogic;             -- Steps to next phase
        last_i : in std_ulogic;             -- Resets cycle
        enable_i : in std_ulogic;           -- Indicates taps will be consumed
        taps_o : out signed_array(0 to TAP_COUNT-1)
    );
end;

architecture arch of poly_fir_taps is
    constant TAP_LENGTH : natural := tap_i'LENGTH;
    constant TAP_COUNT_LENGTH : natural := bits(TAP_COUNT-1);
    constant DECIMATION_BITS : natural := bits(DECIMATION-1);

    subtype decimation_t is unsigned(DECIMATION_BITS-1 downto 0);
    signal write_bank_ix : decimation_t;
    signal write_bank_addr : decimation_t;
    signal write_tap_ix : natural range 0 to TAP_COUNT-1 := 0;
    signal write_tap_strobe : std_ulogic_vector(0 to TAP_COUNT-1)
        := (others => '0');
    signal tap_in : tap_i'SUBTYPE;

    signal read_bank_ix : decimation_t := (others => '0');
    signal read_bank_addr :
        unsigned_array(0 to TAP_COUNT-1)(decimation_t'RANGE)
        := (others => (others => '0'));

    signal taps_out : signed_array(0 to TAP_COUNT-1)(tap_i'RANGE);

begin
    gen_mem : for i in 0 to TAP_COUNT-1 generate
        signal read_tap_strobe : std_ulogic;
        signal read_address : decimation_t;

        signal write_strobe : std_ulogic;
        signal write_addr : decimation_t;
        signal write_data : std_ulogic_vector(TAP_LENGTH-1 downto 0);

    begin
        read : if i = 0 generate
            read_tap_strobe <= next_i;
            read_address <= read_bank_ix;
        else generate
            read_tap_strobe <= enable_i;
            read_address <= read_bank_addr(i-1);
        end generate;

        -- Pipeline tap writing if requested to help with timing pressure
        gen_write_taps : if PIPELINE_WRITE_TAPS generate
            process (clk_i) begin
                if rising_edge(clk_i) then
                    write_strobe <= write_tap_strobe(i);
                    write_addr <= write_bank_addr;
                    write_data <= std_ulogic_vector(tap_in);
                end if;
            end process;
        else generate
            write_strobe <= write_tap_strobe(i);
            write_addr <= write_bank_addr;
            write_data <= std_ulogic_vector(tap_in);
        end generate;

        mem : entity work.memory_array generic map (
            ADDR_BITS => DECIMATION_BITS,
            DATA_BITS => TAP_LENGTH,
            MEM_STYLE => MEM_STYLE,
            READ_DELAY => 1
        ) port map (
            clk_i => clk_i,
            read_strobe_i => read_tap_strobe,
            read_addr_i => read_address,
            signed(read_data_o) => taps_out(i),
            write_strobe_i => write_strobe,
            write_addr_i => write_addr,
            write_data_i => write_data
        );
    end generate;

    -- Writing to taps
    process (clk_i) begin
        if rising_edge(clk_i) then
            if start_write_i then
                write_bank_ix <= (others => '0');
                write_tap_ix <= 0;
            elsif write_tap_i then
                if to_integer(write_bank_ix) = DECIMATION-1 then
                    write_bank_ix <= (others => '0');
                    if write_tap_ix /= TAP_COUNT-1 then
                        write_tap_ix <= write_tap_ix + 1;
                    else
                        write_tap_ix <= 0;
                    end if;
                else
                    write_bank_ix <= write_bank_ix + 1;
                end if;
            end if;

            -- Ensure data in and the write strobe are synchronous
            tap_in <= tap_i;
            write_bank_addr <= write_bank_ix;
            -- Write the taps backwards to align taps with the data.
            if write_tap_i then
                write_tap_strobe <=
                    reverse(compute_strobe(write_tap_ix, TAP_COUNT));
            else
                write_tap_strobe <= (others => '0');
            end if;
        end if;
    end process;


    -- Reading from taps
    process (clk_i) begin
        if rising_edge(clk_i) then
            if last_i then
                read_bank_ix <= (others => '0');
            elsif next_i then
                read_bank_ix <= read_bank_ix + 1;
            end if;

            if next_i then
                read_bank_addr(0) <= read_bank_ix;
            end if;

            if enable_i then
                for i in 1 to TAP_COUNT-1 loop
                    read_bank_addr(i) <= read_bank_addr(i - 1);
                end loop;
            end if;
        end if;
    end process;

    taps_o <= taps_out;
end;
