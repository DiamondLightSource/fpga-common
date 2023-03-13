-- AXI write validator

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.axi_defs.all;

entity axi_write_validate is
    generic (
        -- Default to high enough not to matter.  Slave should be in charge.
        FIFO_DEPTH : natural := 8;
        -- Max outstanding writes
        MAX_PENDING_BRESP : natural := 8
    );
    port (
        clk_i : in std_ulogic;

        axi_i : in axi_write_t;
        axi_ready_i : in axi_write_ready_t
    );
end;

architecture arch of axi_write_validate is
    -- synthesis translate_off

    -- Queue of burst lengths, pushed when fresh address presented, popped when
    -- associated data burst has completed
    signal fifo : unsigned_array(0 to FIFO_DEPTH-1)(7 downto 0);
    signal fifo_count : natural range 0 to FIFO_DEPTH := 0;

    -- Set while expecting data burst
    signal counter_valid : boolean := false;
    -- Number of beats outstanding in current burst
    signal burst_counter : unsigned(7 downto 0);

    -- Number of write_complete acknowledge events outstanding.  Increment on
    -- last beat of data burst, decrement on write_complete signal
    signal complete_pending : natural := 0;

    -- synthesis translate_on

begin
    -- synthesis translate_off

    process (clk_i)
        -- Set on presentation of burst address
        variable address : boolean;
        -- Set on presentation of data beat
        variable data : boolean;
        -- Set on last data beat of burst
        variable last : boolean;
        -- Set when ready to read next burst count from fifo
        variable take_fifo : boolean;
        -- Set if next value will be written directly into burst_counter and
        -- will bypass the fifo.  This is needed to allow data immediately after
        -- a valid address.
        variable bypass_fifo : boolean;

    begin
        data := axi_i.data_valid = '1' and axi_ready_i.data_ready = '1';
        address :=
            axi_i.address_valid = '1' and axi_ready_i.address_ready = '1';
        last := data and axi_i.data_last = '1';
        -- Take address from fifo at end of burst if possible
        take_fifo := fifo_count > 0 and last;
        -- Use incoming address when fifo is empty, when incoming address is
        -- valid, and when counter can be updated
        bypass_fifo :=
            fifo_count = 0 and address and (last or not counter_valid);

        if rising_edge(clk_i) then
            if take_fifo then
                counter_valid <= true;
                burst_counter <= fifo(0);
            elsif bypass_fifo then
                counter_valid <= true;
                burst_counter <= axi_i.burst_length;
            elsif last then
                counter_valid <= false;
            elsif data then
                burst_counter <= burst_counter - 1;
            end if;


            if address and not take_fifo then
                -- Check the address isn't bypassing the fifo
                if not bypass_fifo then
                    assert fifo_count < FIFO_DEPTH
                        report "Address FIFO overrun"
                        severity failure;
                    fifo(fifo_count) <= axi_i.burst_length;
                    fifo_count <= fifo_count + 1;
                end if;
            elsif take_fifo then
                if not address then
                    assert fifo_count > 0
                        report "Address FIFO underrun"
                        severity failure;
                    fifo_count <= fifo_count - 1;
                end if;
                for i in 1 to fifo_count-1 loop
                    fifo(i-1) <= fifo(i);
                end loop;
            end if;

            if data then
                assert counter_valid
                    report "Data without associated address"
                    severity failure;
                assert last = (burst_counter = 0)
                    report "Badly framed data burst"
                    severity failure;
            end if;

            if axi_ready_i.write_complete then
                assert complete_pending > 0 or last
                    report "Data complete without data"
                    severity failure;
                if not last then
                    complete_pending <= complete_pending - 1;
                end if;
            elsif last then
                complete_pending <= complete_pending + 1;
                assert complete_pending < MAX_PENDING_BRESP
                    report "Too many unacknowledged bursts"
                    severity failure;
            end if;
        end if;
    end process;

    -- synthesis translate_on
end;
