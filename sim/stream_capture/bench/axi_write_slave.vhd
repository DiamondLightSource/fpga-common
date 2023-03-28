-- Simple AXI write slave

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.support.all;
use work.axi_defs.all;

entity axi_write_slave is
    generic (
        COMPLETE_DELAY : natural := 0;
        ENABLE_LOGGING : boolean
    );
    port (
        clk_i : in std_ulogic;

        axi_i : in axi_write_t;
        axi_o : out axi_write_ready_t
    );
end;

architecture arch of axi_write_slave is
    signal data_ready : std_ulogic := '0';
    signal write_complete : std_ulogic := '0';
    signal address_valid : std_ulogic := '0';
    signal address_ready : std_ulogic := '0';

    -- Completion count used to manage write completion delay
    signal complete_count : natural := 0;

    procedure write(message : string := "") is
        variable linebuffer : line;
    begin
        write(linebuffer, message);
        writeline(output, linebuffer);
    end;

begin
    process (clk_i)
        variable last : std_ulogic;

        variable linebuffer : line;

    begin
        last := axi_i.data_valid and axi_i.data_last;

        if rising_edge(clk_i) then
            -- Simulate buffering one address
            if address_valid then
                address_valid <= not address_ready;
            else
                address_valid <= axi_i.address_valid;
            end if;

            -- Pick up next burst at end of current burst or when idle
            if not data_ready or last then
                address_ready <= '1';
                data_ready <= address_valid;
            elsif data_ready then
                address_ready <= '0';
            end if;

            -- For simplicity, just acknowledge each burst immediately.  To help
            -- with testing we optionally wait a number of bursts before
            -- starting to generate completions.
            if complete_count < COMPLETE_DELAY then
                if last then
                    complete_count <= complete_count + 1;
                end if;
            else
                write_complete <= last;
            end if;

            if ENABLE_LOGGING then
                if axi_i.address_valid and axi_o.address_ready then
                    write(linebuffer,
                        "@ " & to_string(now, unit => ns) &
                        " " & to_hstring(axi_i.address) & ":");
                end if;
                if axi_i.data_valid and axi_o.data_ready then
                    write(linebuffer, " " & to_hstring(axi_i.data));
                    if last then
                        writeline(output, linebuffer);
                    end if;
                end if;
            end if;
        end if;
    end process;

    validate : entity work.axi_write_validate port map (
        clk_i => clk_i,
        axi_i => axi_i,
        axi_ready_i => axi_o
    );

    axi_o <= (
        address_ready => not address_valid,
        data_ready => data_ready,
        write_complete => write_complete
    );
end;
