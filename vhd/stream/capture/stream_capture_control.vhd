-- Capture control for single source and target

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity stream_capture_control is
    port (
        clk_i : in std_ulogic;

        -- Register interface
        start_i : in std_ulogic;                -- Request start
        stop_i : in std_ulogic;                 -- Stop, triggers run-on
        abort_i : in std_ulogic;                -- Abort, skips run-on
        runout_count_i : in unsigned;           -- Run-on counter
        capture_address_o : out unsigned;       -- Capture address on trigger
        capture_busy_o : out std_ulogic;        -- Capture in progress
        triggered_o : out std_ulogic;           -- Trigger seen

        -- Interface to capture engine
        capture_enable_o : out std_ulogic;      -- Enable capture engine
        capture_ready_i : in std_ulogic;        -- Capture engine running
        capture_address_i : in unsigned;        -- Current capture address
        count_sent_i : in std_ulogic;           -- Counts data sent

        -- Trigger to stop capture
        trigger_i : in std_ulogic               -- Trigger input
    );
end;

architecture arch of stream_capture_control is
    type state_t is (IDLE, RUNNING, RUNOUT, STOPPING);
    signal state : state_t := IDLE;

    signal runout_count : runout_count_i'SUBTYPE;
    -- We do a slightly tricksy address remap to pull out just the bottom bits
    -- of the captured address
    signal capture_address_out : unsigned(capture_address_i'LENGTH-1 downto 0);
    signal triggered_out : std_ulogic := '0';

begin
    process (clk_i) begin
        if rising_edge(clk_i) then
            case state is
                when IDLE =>
                    if start_i then
                        runout_count <= runout_count_i;
                        -- If start and stop fired together go straight into
                        -- runout to capture selected count
                        state <= RUNOUT when stop_i else RUNNING;
                        triggered_out <= '0';
                    end if;

                when RUNNING =>
                    if count_sent_i then
                        capture_address_out <= capture_address_i;
                    end if;

                    if abort_i then
                        state <= STOPPING;
                    elsif stop_i or trigger_i then
                        state <= RUNOUT when runout_count > 0 else STOPPING;
                        triggered_out <= trigger_i;
                    end if;

                when RUNOUT =>
                    if abort_i then
                        state <= STOPPING;
                        -- On abort we capture the final address and reset the
                        -- triggered flag
                        capture_address_out <= capture_address_i;
                        triggered_out <= '0';
                    elsif count_sent_i then
                        if runout_count > 0 then
                            runout_count <= runout_count - 1;
                        else
                            state <= STOPPING;
                        end if;
                    end if;

                when STOPPING =>
                    if not capture_ready_i then
                        state <= IDLE;
                    end if;
            end case;
        end if;
    end process;

    capture_address_o <=
        capture_address_out(capture_address_o'LENGTH-1 downto 0);
    capture_enable_o <= to_std_ulogic(state = RUNNING or state = RUNOUT);
    capture_busy_o <= to_std_ulogic(state /= IDLE);
    triggered_o <= triggered_out;
end;
