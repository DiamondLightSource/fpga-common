-- Shared simulation functions

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.support.all;
use work.register_defs.all;

package sim_support is
    procedure clk_wait(signal clk_i : in std_ulogic; count : in natural := 1);

    -- Register access for strobed registers
    procedure write_reg(
        signal clk_i : in std_ulogic;
        signal data_o : out reg_data_array_t;
        signal strobe_o : out std_ulogic_vector;
        signal ack_i : in std_ulogic_vector;
        reg : natural; value : reg_data_t);
    procedure read_reg(
        signal clk_i : in std_ulogic;
        signal data_i : in reg_data_array_t;
        signal strobe_o : out std_ulogic_vector;
        signal ack_i : in std_ulogic_vector;
        reg : natural);
    -- Same as read_reg, but returns result into result variable
    procedure read_reg_result(
        signal clk_i : in std_ulogic;
        signal data_i : in reg_data_array_t;
        signal strobe_o : out std_ulogic_vector;
        signal ack_i : in std_ulogic_vector;
        reg : natural;
        result : out reg_data_t);


    -- Register access for addressed registers
    procedure write_reg(
        signal clk_i : in std_ulogic;
        signal data_o : out reg_data_t;
        signal address_o : out unsigned;
        signal strobe_o : out std_ulogic;
        signal ack_i : in std_ulogic;
        reg : natural; value : reg_data_t);
    procedure read_reg(
        signal clk_i : in std_ulogic;
        signal data_i : in reg_data_t;
        signal address_o : out unsigned;
        signal strobe_o : out std_ulogic;
        signal ack_i : in std_ulogic;
        reg : natural);
    procedure read_reg_result(
        signal clk_i : in std_ulogic;
        signal data_i : in reg_data_t;
        signal address_o : out unsigned;
        signal strobe_o : out std_ulogic;
        signal ack_i : in std_ulogic;
        reg : natural;
        result : out reg_data_t);


    procedure write(message : string := "");

end package;

package body sim_support is

    procedure clk_wait(signal clk_i : in std_ulogic; count : in natural := 1) is
    begin
        for i in 1 to count loop
            wait until rising_edge(clk_i);
        end loop;
    end procedure;


    -- -------------------------------------------------------------------------
    -- Decoded strobed registers

    procedure write_reg(
        signal clk_i : in std_ulogic;
        signal data_o : out reg_data_array_t;
        signal strobe_o : out std_ulogic_vector;
        signal ack_i : in std_ulogic_vector;
        reg : natural; value : reg_data_t) is
    begin
        data_o(reg) <= value;
        strobe_o <= (strobe_o'RANGE => '0');
        strobe_o(reg) <= '1';
        loop
            clk_wait(clk_i);
            strobe_o <= (strobe_o'RANGE => '0');
            exit when ack_i(reg);
        end loop;
        write(
            "@ " & to_string(now, unit => ns) &
            ": write_reg [" & natural'image(reg) & "] <= " & to_hstring(value));
    end procedure;


    procedure read_reg_result(
        signal clk_i : in std_ulogic;
        signal data_i : in reg_data_array_t;
        signal strobe_o : out std_ulogic_vector;
        signal ack_i : in std_ulogic_vector;
        reg : natural;
        result : out reg_data_t) is
    begin
        strobe_o <= (strobe_o'RANGE => '0');
        strobe_o(reg) <= '1';
        loop
            clk_wait(clk_i);
            strobe_o <= (strobe_o'RANGE => '0');
            exit when ack_i(reg);
        end loop;
        result := data_i(reg);

        write(
            "@ " & to_string(now, unit => ns) &
            ": read_reg [" & natural'image(reg) & "] => " & to_hstring(result));
    end procedure;

    procedure read_reg(
        signal clk_i : in std_ulogic;
        signal data_i : in reg_data_array_t;
        signal strobe_o : out std_ulogic_vector;
        signal ack_i : in std_ulogic_vector;
        reg : natural)
    is
        variable result : reg_data_t;
    begin
        read_reg_result(clk_i, data_i, strobe_o, ack_i, reg, result);
    end procedure;


    -- -------------------------------------------------------------------------
    -- Addressed registers

    procedure write_reg(
        signal clk_i : in std_ulogic;
        signal data_o : out reg_data_t;
        signal address_o : out unsigned;
        signal strobe_o : out std_ulogic;
        signal ack_i : in std_ulogic;
        reg : natural; value : reg_data_t) is
    begin
        data_o <= value;
        address_o <= to_unsigned(reg, address_o'LENGTH);
        strobe_o <= '1';
        loop
            clk_wait(clk_i);
            strobe_o <= '0';
            exit when ack_i;
        end loop;
        write(
            "@ " & to_string(now, unit => ns) &
            ": write_reg [" & natural'image(reg) & "] <= " & to_hstring(value));
    end procedure;


    procedure read_reg_result(
        signal clk_i : in std_ulogic;
        signal data_i : in reg_data_t;
        signal address_o : out unsigned;
        signal strobe_o : out std_ulogic;
        signal ack_i : in std_ulogic;
        reg : natural;
        result : out reg_data_t) is
    begin
        address_o <= to_unsigned(reg, address_o'LENGTH);
        strobe_o <= '1';
        loop
            clk_wait(clk_i);
            strobe_o <= '0';
            exit when ack_i;
        end loop;
        result := data_i;

        write(
            "@ " & to_string(now, unit => ns) &
            ": read_reg [" & natural'image(reg) & "] => " & to_hstring(result));
    end procedure;

    procedure read_reg(
        signal clk_i : in std_ulogic;
        signal data_i : in reg_data_t;
        signal address_o : out unsigned;
        signal strobe_o : out std_ulogic;
        signal ack_i : in std_ulogic;
        reg : natural)
    is
        variable result : reg_data_t;
    begin
        read_reg_result(clk_i, data_i, address_o, strobe_o, ack_i, reg, result);
    end procedure;


    procedure write(message : string := "") is
        variable linebuffer : line;
    begin
        write(linebuffer, message);
        writeline(output, linebuffer);
    end;

end package body;
