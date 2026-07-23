-- AXI write validator

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.axi_defs.all;

entity axi_write_validate is
    generic (
        -- This allows one outstanding data completion without an address
        DATA_DEPTH : natural := 1;
        -- Number of outstanding addresses
        ADDRESS_DEPTH : natural := 8;
        -- Max outstanding writes
        MAX_PENDING_BRESP : natural := 8;
        -- Action to take on failure
        FAIL_ACTION : severity_level := failure
    );
    port (
        clk_i : in std_ulogic;

        axi_i : in axi_write_t;
        axi_ready_i : in axi_write_ready_t
    );
end;

architecture arch of axi_write_validate is
    -- synthesis translate_off

    type fifo_t is record
        count : natural;
        fifo : unsigned_array(open)(7 downto 0);
    end record;

    procedure push(
        variable fifo : inout fifo_t; value : unsigned) is
    begin
        assert fifo.count < fifo.fifo'LENGTH
            report "FIFO overflow"
            severity failure;
        fifo.fifo(fifo.count) := value;
        fifo.count := fifo.count + 1;
    end;

    procedure pop(variable fifo : inout fifo_t) is
    begin
        assert fifo.count > 0
            report "FIFO underflow"
            severity failure;
        fifo.count := fifo.count - 1;
        fifo.fifo(0 to fifo.count - 1) := fifo.fifo(1 to fifo.count);
    end;

    subtype data_fifo_t is fifo_t(fifo(0 to DATA_DEPTH-1));
    subtype address_fifo_t is fifo_t(fifo(0 to ADDRESS_DEPTH-1));


    -- synthesis translate_on

begin
    -- synthesis translate_off

    check : process (clk_i)
        variable data_fifo : data_fifo_t;
        variable address_fifo : address_fifo_t;
        variable burst_count : unsigned(7 downto 0) := X"00";
        variable completions_pending : natural := 0;

    begin
        if rising_edge(clk_i) then
            -- Keep track of addresses for bursts
            if axi_i.address_valid and axi_ready_i.address_ready then
                push(address_fifo, axi_i.burst_length);
            end if;

            -- Keep track of the length of each burst
            if axi_i.data_valid and axi_ready_i.data_ready then
                if axi_i.data_last then
                    push(data_fifo, burst_count);
                    burst_count := X"00";
                    assert completions_pending < MAX_PENDING_BRESP
                        report "Too many outstanding completions"
                        severity FAIL_ACTION;
                    completions_pending := completions_pending + 1;
                else
                    burst_count := burst_count + 1;
                    assert burst_count > 0
                        report "Burst count overflow"
                        severity FAIL_ACTION;
                end if;
            end if;

            -- Match completed data bursts with addresses and ensure the burst
            -- lengths match
            if data_fifo.count > 0 and address_fifo.count > 0 then
                assert data_fifo.fifo(0) = address_fifo.fifo(0)
                    report "Burst length mismatch: " &
                        to_hstring(data_fifo.fifo(0)) & " " &
                        to_hstring(address_fifo.fifo(0))
                    severity FAIL_ACTION;
                pop(address_fifo);
                pop(data_fifo);
            end if;

            -- Count off completions
            if axi_ready_i.write_complete then
                assert completions_pending > 0
                    report "Completion response before data"
                    severity FAIL_ACTION;
                completions_pending := completions_pending - 1;
            end if;
        end if;
    end process;

    -- synthesis translate_on
end;
