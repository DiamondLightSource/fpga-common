-- Capture of SA data to application

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.stream_defs.all;

entity stream_capture_fifo is
    generic (
        READY_DEPTH : natural;
        LOG_FIFO_DEPTH : natural := 9
    );
    port (
        clk_i : in std_ulogic;

        -- SA data
        stream_i : in data_stream_t;

        -- Read interface
        read_strobe_i : in std_ulogic;          -- Read request from FIFO
        read_data_o : out std_ulogic_vector;    -- Data from FIFO
        read_ack_o : out std_ulogic := '0';     -- Data request acknowledge

        fifo_underrun_o : out std_ulogic := '0'; -- Set if reading empty FIFO
        fifo_overflow_o : out std_ulogic := '0'; -- Set if FIFO overflows

        fifo_ready_o : out std_ulogic := '0';   -- FIFO ready to read state
        fifo_reset_i : in std_ulogic            -- Force FIFO reset
    );
end;

architecture arch of stream_capture_fifo is
    type state_t is (RUNNING, OVERFLOW, RESET);
    signal state : state_t := RUNNING;

    -- FIFO interface
    signal write_ready : std_ulogic;
    signal read_valid : std_ulogic;
    signal reset_fifo : std_ulogic;
    signal fifo_depth : unsigned(LOG_FIFO_DEPTH downto 0);

    signal read_data_out : read_data_o'SUBTYPE;

begin
    assert stream_i.data'LENGTH = read_data_o'LENGTH 
        report "Input length " &
            to_string(stream_i.data'LENGTH) &
            " /= Output length " & to_string(read_data_o'LENGTH)
        severity failure;

    reset_fifo <= to_std_ulogic(state /= RUNNING);
    fifo : entity work.fifo generic map (
        FIFO_BITS => LOG_FIFO_DEPTH,
        DATA_WIDTH => stream_i.data'LENGTH
    ) port map (
        clk_i => clk_i,

        write_valid_i => stream_i.valid,
        write_ready_o => write_ready,
        write_data_i => std_ulogic_vector(stream_i.data),

        read_valid_o => read_valid,
        read_ready_i => read_strobe_i,
        read_data_o => read_data_out,

        reset_fifo_i => reset_fifo,
        fifo_depth_o => fifo_depth
    );


    process (clk_i) begin
        if rising_edge(clk_i) then
            case state is
                when RUNNING =>
                    if fifo_reset_i then
                        state <= RESET;
                    elsif stream_i.valid and not write_ready then
                        state <= OVERFLOW;
                    end if;
                when OVERFLOW =>
                    if fifo_reset_i then
                        state <= RESET;
                    end if;
                when RESET =>
                    -- Hold the FIFO in reset until after last write of packet.
                    -- This ensures FIFO will always contain a complete packet.
                    if stream_i.last and stream_i.valid then
                        state <= RUNNING;
                    end if;
            end case;

            -- Mark the FIFO ready so long as it's running normally and there is
            -- enough data for a full packet read.  For successful interrupt
            -- generation the FIFO must be read until this bit is reset.
            fifo_ready_o <= to_std_ulogic(
                fifo_depth >= READY_DEPTH and state = RUNNING);

            -- FIFO underflow event when attempting to read from empty FIFO
            fifo_underrun_o <= read_strobe_i and not read_valid;
            -- Report overflow status when overflow detected and not yet reset
            fifo_overflow_o <= to_std_ulogic(state = OVERFLOW);

            -- Always acknowledge the read request, even if no data available;
            -- the user needs to check the underrun flag
            read_ack_o <= read_strobe_i;
            -- Ensure read data is aligned with read acknowledge
            read_data_o <= read_data_out;
        end if;
    end process;
end;
