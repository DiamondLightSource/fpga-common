-- Shared simulation functions

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.support.all;
use work.register_defs.all;

package sim_support is
    procedure clk_wait(signal clk_i : in std_ulogic; count : in natural := 1);

    -- Register access for single register
    procedure write_reg(
        signal clk_i : in std_ulogic;
        signal data_o : out reg_data_t;
        signal strobe_o : out std_ulogic;
        signal ack_i : in std_ulogic;
        value : reg_data_t; quiet : boolean := false);
    procedure read_reg(
        signal clk_i : in std_ulogic;
        signal data_i : in reg_data_t;
        signal strobe_o : out std_ulogic;
        signal ack_i : in std_ulogic;
        quiet : boolean := false);
    -- Same as read_reg, but returns result into result variable
    procedure read_reg_result(
        signal clk_i : in std_ulogic;
        signal data_i : in reg_data_t;
        signal strobe_o : out std_ulogic;
        signal ack_i : in std_ulogic;
        result : out reg_data_t; quiet : boolean := false);


    -- Register access for strobed registers
    procedure write_reg(
        signal clk_i : in std_ulogic;
        signal data_o : out reg_data_array_t;
        signal strobe_o : out std_ulogic_vector;
        signal ack_i : in std_ulogic_vector;
        reg : natural; value : reg_data_t; quiet : boolean := false);
    procedure read_reg(
        signal clk_i : in std_ulogic;
        signal data_i : in reg_data_array_t;
        signal strobe_o : out std_ulogic_vector;
        signal ack_i : in std_ulogic_vector;
        reg : natural; quiet : boolean := false);
    -- Same as read_reg, but returns result into result variable
    procedure read_reg_result(
        signal clk_i : in std_ulogic;
        signal data_i : in reg_data_array_t;
        signal strobe_o : out std_ulogic_vector;
        signal ack_i : in std_ulogic_vector;
        reg : natural;
        result : out reg_data_t; quiet : boolean := false);


    -- Register access for addressed registers
    procedure write_reg(
        signal clk_i : in std_ulogic;
        signal data_o : out reg_data_t;
        signal address_o : out unsigned;
        signal strobe_o : out std_ulogic;
        signal ack_i : in std_ulogic;
        reg : natural; value : reg_data_t; quiet : boolean := false);
    procedure read_reg(
        signal clk_i : in std_ulogic;
        signal data_i : in reg_data_t;
        signal address_o : out unsigned;
        signal strobe_o : out std_ulogic;
        signal ack_i : in std_ulogic;
        reg : natural; quiet : boolean := false);
    procedure read_reg_result(
        signal clk_i : in std_ulogic;
        signal data_i : in reg_data_t;
        signal address_o : out unsigned;
        signal strobe_o : out std_ulogic;
        signal ack_i : in std_ulogic;
        reg : natural;
        result : out reg_data_t; quiet : boolean := false);


    procedure write(message : string := ""; stamp : boolean := false);

end package;

package body sim_support is

    procedure clk_wait(signal clk_i : in std_ulogic; count : in natural := 1) is
    begin
        for i in 1 to count loop
            wait until rising_edge(clk_i);
        end loop;
    end procedure;


    -- -------------------------------------------------------------------------
    -- Single register

    procedure write_reg(
        signal clk_i : in std_ulogic;
        signal data_o : out reg_data_t;
        signal strobe_o : out std_ulogic;
        signal ack_i : in std_ulogic;
        value : reg_data_t; quiet : boolean := false) is
    begin
        data_o <= value;
        strobe_o <= '1';
        loop
            clk_wait(clk_i);
            strobe_o <= '0';
            exit when ack_i;
        end loop;
        data_o <= (others => 'U');
        if not quiet then
            write("write_reg <= " & to_hstring(value), true);
        end if;
    end procedure;

    procedure read_reg_result(
        signal clk_i : in std_ulogic;
        signal data_i : in reg_data_t;
        signal strobe_o : out std_ulogic;
        signal ack_i : in std_ulogic;
        result : out reg_data_t; quiet : boolean := false) is
    begin
        strobe_o <= '1';
        loop
            clk_wait(clk_i);
            strobe_o <= '0';
            exit when ack_i;
        end loop;
        result := data_i;

        if not quiet then
            write("read_reg => " & to_hstring(result), true);
        end if;
    end procedure;

    procedure read_reg(
        signal clk_i : in std_ulogic;
        signal data_i : in reg_data_t;
        signal strobe_o : out std_ulogic;
        signal ack_i : in std_ulogic;
        quiet : boolean := false)
    is
        variable result : reg_data_t;
    begin
        read_reg_result(clk_i, data_i, strobe_o, ack_i, result, quiet);
    end procedure;


    -- -------------------------------------------------------------------------
    -- Decoded strobed registers

    -- Annoyingly and disappointingly it isn't possible to reuse the
    -- implementations above, eg writing
    --
    --  write_reg(clk_i, data_o(reg), strobe_o(reg), ack_i(reg), value, true);
    --
    -- because VHDL simply doesn't allow dynamic indexing of an array here.

    procedure write_reg(
        signal clk_i : in std_ulogic;
        signal data_o : out reg_data_array_t;
        signal strobe_o : out std_ulogic_vector;
        signal ack_i : in std_ulogic_vector;
        reg : natural; value : reg_data_t; quiet : boolean := false) is
    begin
        data_o(reg) <= value;
        strobe_o <= (strobe_o'RANGE => '0');
        strobe_o(reg) <= '1';
        loop
            clk_wait(clk_i);
            strobe_o <= (strobe_o'RANGE => '0');
            exit when ack_i(reg);
        end loop;
        data_o(reg) <= (others => 'U');
        if not quiet then
            write(
                "write_reg [" & natural'image(reg) &
                "] <= " & to_hstring(value), true);
        end if;
    end procedure;


    procedure read_reg_result(
        signal clk_i : in std_ulogic;
        signal data_i : in reg_data_array_t;
        signal strobe_o : out std_ulogic_vector;
        signal ack_i : in std_ulogic_vector;
        reg : natural;
        result : out reg_data_t; quiet : boolean := false) is
    begin
        strobe_o <= (strobe_o'RANGE => '0');
        strobe_o(reg) <= '1';
        loop
            clk_wait(clk_i);
            strobe_o <= (strobe_o'RANGE => '0');
            exit when ack_i(reg);
        end loop;
        result := data_i(reg);

        if not quiet then
            write(
                "read_reg [" & natural'image(reg) &
                "] => " & to_hstring(result), true);
        end if;
    end procedure;

    procedure read_reg(
        signal clk_i : in std_ulogic;
        signal data_i : in reg_data_array_t;
        signal strobe_o : out std_ulogic_vector;
        signal ack_i : in std_ulogic_vector;
        reg : natural; quiet : boolean := false)
    is
        variable result : reg_data_t;
    begin
        read_reg_result(clk_i, data_i, strobe_o, ack_i, reg, result, quiet);
    end procedure;


    -- -------------------------------------------------------------------------
    -- Addressed registers

    procedure write_reg(
        signal clk_i : in std_ulogic;
        signal data_o : out reg_data_t;
        signal address_o : out unsigned;
        signal strobe_o : out std_ulogic;
        signal ack_i : in std_ulogic;
        reg : natural; value : reg_data_t; quiet : boolean := false) is
    begin
        data_o <= value;
        address_o <= to_unsigned(reg, address_o'LENGTH);
        strobe_o <= '1';
        loop
            clk_wait(clk_i);
            strobe_o <= '0';
            exit when ack_i;
        end loop;
        data_o <= (data_o'RANGE => 'U');
        address_o <= (address_o'RANGE => 'U');
        if not quiet then
            write(
                "write_reg [" & natural'image(reg) &
                "] <= " & to_hstring(value), true);
        end if;
    end procedure;


    procedure read_reg_result(
        signal clk_i : in std_ulogic;
        signal data_i : in reg_data_t;
        signal address_o : out unsigned;
        signal strobe_o : out std_ulogic;
        signal ack_i : in std_ulogic;
        reg : natural;
        result : out reg_data_t; quiet : boolean := false) is
    begin
        address_o <= to_unsigned(reg, address_o'LENGTH);
        strobe_o <= '1';
        loop
            clk_wait(clk_i);
            strobe_o <= '0';
            exit when ack_i;
        end loop;
        address_o <= (address_o'RANGE => 'U');
        result := data_i;

        if not quiet then
            write(
                "read_reg [" & natural'image(reg) &
                "] => " & to_hstring(result), true);
        end if;
    end procedure;

    procedure read_reg(
        signal clk_i : in std_ulogic;
        signal data_i : in reg_data_t;
        signal address_o : out unsigned;
        signal strobe_o : out std_ulogic;
        signal ack_i : in std_ulogic;
        reg : natural; quiet : boolean := false)
    is
        variable result : reg_data_t;
    begin
        read_reg_result(
            clk_i, data_i, address_o, strobe_o, ack_i, reg, result, quiet);
    end procedure;


    procedure write(message : string := ""; stamp : boolean := false) is
        variable linebuffer : line;
    begin
        if stamp then
            write(linebuffer, "@ " & to_string(now, unit => ns) & ": ");
        end if;
        write(linebuffer, message);
        writeline(output, linebuffer);
    end;

end package body;
