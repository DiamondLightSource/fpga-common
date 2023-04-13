-- Sequencing and address counting for slow polyphase FIR

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity slow_poly_fir_control is
    generic (
        DECIMATION : natural;
        OVERLAPS : natural;
        WAYS : natural
    );
    port (
        clk_i : in std_ulogic;

        -- Signals from FIFO
        valid_i : in std_ulogic;
        last_i : in std_ulogic;
        ready_o : out std_ulogic := '0';

        sync_i : in std_ulogic;

        -- Tap address
        tap_address_o : out unsigned;

        -- Accumulator control, address and last tap marker
        accum_address_o : out unsigned;
        accum_end_o : out std_ulogic := '0'
    );
end;

architecture arch of slow_poly_fir_control is
    constant ACCUM_COUNT : natural := DECIMATION * WAYS;
    constant TAPS_COUNT : natural := DECIMATION * OVERLAPS;

    signal overlap_counter : natural range 0 to OVERLAPS - 1;
    signal base_tap_address : natural range 0 to TAPS_COUNT - 1;
    signal tap_address : natural range 0 to TAPS_COUNT - 1;
    signal accum_address : natural range 0 to ACCUM_COUNT - 1;

    signal sync_request : boolean := false;

begin
    process (clk_i)
        variable next_overlap_counter : overlap_counter'SUBTYPE;
        variable next_base_tap_address : base_tap_address'SUBTYPE;
        variable end_of_samples : std_ulogic;
        variable next_tap_address : tap_address'SUBTYPE;

    begin
        if rising_edge(clk_i) then
            -- Overlap counter increments normally
            if overlap_counter = OVERLAPS - 1 then
                next_overlap_counter := 0;
            else
                next_overlap_counter := overlap_counter + 1;
            end if;

            -- The base tap address increments normally on completion of a
            -- complete burst
            if base_tap_address = TAPS_COUNT - 1 then
                next_base_tap_address := 0;
            else
                next_base_tap_address := base_tap_address + 1;
            end if;

            -- Marks the end of an input data burst.
            -- Can advance state for next burst
            end_of_samples := last_i and ready_o;

            -- The tap address computation is surprisingly complex, and we need
            -- this early to help detect the last tap
            if end_of_samples then
                next_tap_address := next_base_tap_address;
            elsif ready_o then
                next_tap_address := base_tap_address;
            else
                if tap_address >= TAPS_COUNT - DECIMATION then
                    next_tap_address := tap_address - (TAPS_COUNT - DECIMATION);
                else
                    next_tap_address := tap_address + DECIMATION;
                end if;
            end if;


            if valid_i then
                -- First advance the overlp counter.  This is used to generate
                -- the ready_o signal after processing OVERLAPS copies of input
                overlap_counter <= next_overlap_counter;
                ready_o <= to_std_ulogic(next_overlap_counter = OVERLAPS - 1);

                -- Advance the accumulator address on each valid datum in, reset
                -- on last processed datum in each sample
                if end_of_samples then
                    accum_address <= 0;
                else
                    accum_address <= accum_address + 1;
                end if;

                -- Reset the base tap address on sync, otherwise advance as
                -- computed above to get to the next tap.
                if end_of_samples then
                    if sync_request then
                        base_tap_address <= 0;
                    else
                        base_tap_address <= next_base_tap_address;
                    end if;
                end if;

                -- Next we compute the tap address by advancing the base address
                -- by the decimation count for each group of overlaps
                tap_address <= next_tap_address;
                accum_end_o <= to_std_ulogic(next_tap_address = TAPS_COUNT - 1);

                -- Sync request
                if sync_i then
                    sync_request <= true;
                elsif end_of_samples then
                    sync_request <= false;
                end if;
            else
                ready_o <= '0';
            end if;
        end if;
    end process;

    accum_address_o <= to_unsigned(accum_address, accum_address_o'LENGTH);
    tap_address_o <= to_unsigned(tap_address, tap_address_o'LENGTH);
end;
