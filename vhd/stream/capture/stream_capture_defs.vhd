-- Capture definitions

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

package stream_capture_defs is
    -- Control of capture_bursts
    type stream_capture_control_t is record
        start : std_ulogic;                 -- Request start
        stop : std_ulogic;                  -- Stop, triggers run-on
        abort : std_ulogic;                 -- Stop, abort run-on
        runout_count : unsigned;            -- Run-on counter
    end record;

    -- Status and readbacks from capture bursts
    type stream_capture_status_t is record
        capture_address : unsigned;         -- Capture address on trigger
        capture_busy : std_ulogic;          -- Capture in progress
        framing_error : std_ulogic;         -- Burst framing error
        data_error : std_ulogic;            -- Unable to send data
        triggered : std_ulogic;             -- Set if trigger seen
        -- Interrupts, triggered on rising edge
        complete : std_ulogic;              -- Interrupt when capture completes
        progress : std_ulogic;              -- Periodic interrupt during capture
    end record;
end;
