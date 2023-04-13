-- Top level control for Polyphase FIR

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity poly_fir_control is
    generic (
        TAP_COUNT : natural;
        DECIMATION : natural;
        WAYS : natural;
        FIR_PROCESS_DELAY : natural;
        ACCUM_PROCESS_DELAY : natural
    );
    port (
        clk_i : in std_ulogic;

        enable_i : in std_ulogic;           -- Single input strobe
        last_i : in std_ulogic;             -- Start of channel multiplex
        sync_i : in std_ulogic;             -- Resets cycle count

        start_taps_o : out std_ulogic;      -- Start of Poly FIR cycle for taps

        start_accum_o : out std_ulogic;     -- Start of cycle for accumulator
        enable_accum_o : out std_ulogic;    -- Data enable for accumulator

        last_o : out std_ulogic;            -- Start of output channel mux
        enable_o : out std_ulogic           -- Single output data point
    );
end;

architecture arch of poly_fir_control is
    signal sync_in : std_ulogic := '0';
    signal sync_request : std_ulogic := '0';

    signal cycle_count : natural range 0 to DECIMATION-1 := 0;
    signal last_cycle : std_ulogic := '0';
    signal first_cycle : std_ulogic := '0';
    signal second_cycle : std_ulogic := '0';

    signal enable_delay : std_ulogic;
    signal last_delay : std_ulogic;
    signal first_cycle_delay : std_ulogic;
    signal second_cycle_delay : std_ulogic;
    signal last_delay_out : std_ulogic;
    signal first_cycle_delay_out : std_ulogic;
    signal second_cycle_delay_out : std_ulogic;

begin
    -- Basic timed logic: decimation counter and end of cycle flags.  We have
    -- three end of cycle flags
    process (clk_i) begin
        if rising_edge(clk_i) then
            -- Register in_sync until end of input cycle
            sync_in <= sync_i;
            if sync_in then
                sync_request <= '1';
            elsif last_i then
                sync_request <= '0';
            end if;

            -- Cycle counter and state advances on end of input cycle
            if last_i then
                if cycle_count = 0 or sync_request = '1' then
                    cycle_count <= DECIMATION - 1;
                else
                    cycle_count <= cycle_count - 1;
                end if;

                last_cycle <= to_std_ulogic(cycle_count = 0);
                first_cycle <= last_cycle;
                second_cycle <= first_cycle;
            end if;
        end if;
    end process;


    -- We need two sets of delays to align accumulator and output to account for
    -- the two tick plus TAP_COUNT enable delay of the FIR.

    -- First the fixed ticks delay
    ticks_delay : entity work.fixed_delay generic map (
        DELAY => FIR_PROCESS_DELAY - 1,
        WIDTH => 4
    ) port map (
        clk_i => clk_i,
        data_i(0) => enable_i,
        data_i(1) => last_i,
        data_i(2) => first_cycle,
        data_i(3) => second_cycle,
        data_o(0) => enable_delay,
        data_o(1) => last_delay,
        data_o(2) => first_cycle_delay,
        data_o(3) => second_cycle_delay
    );

    -- Next the tap delay
    tap_delays : entity work.fixed_delay generic map (
        DELAY => TAP_COUNT,
        WIDTH => 3
    ) port map (
        clk_i => clk_i,
        enable_i => enable_delay,
        data_i(0) => last_delay,
        data_i(1) => first_cycle_delay,
        data_i(2) => second_cycle_delay,
        data_o(0) => last_delay_out,
        data_o(1) => first_cycle_delay_out,
        data_o(2) => second_cycle_delay_out
    );


    -- Output generation

    start_taps_o <= last_cycle and last_i;

    start_accum_o <= second_cycle_delay_out;
    enable_accum_o <= enable_delay;


    -- Take account of ACCUM process delay for final output control
    accum_delays : entity work.fixed_delay generic map (
        DELAY => ACCUM_PROCESS_DELAY,
        WIDTH => 2
    ) port map (
        clk_i => clk_i,
        data_i(0) => first_cycle_delay_out and enable_delay,
        data_i(1) => first_cycle_delay_out and enable_delay and last_delay_out,
        data_o(0) => enable_o,
        data_o(1) => last_o
    );
end;
