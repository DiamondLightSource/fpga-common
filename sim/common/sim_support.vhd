-- Shared simulation functions

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.support.all;
use work.register_defs.all;

package sim_support is
    procedure clk_wait(signal clk_i : in std_ulogic; count : in natural := 1);

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

    procedure write(message : string := "");

end package;

package body sim_support is

    procedure clk_wait(signal clk_i : in std_ulogic; count : in natural := 1) is
    begin
        for i in 1 to count loop
            wait until rising_edge(clk_i);
        end loop;
    end procedure;


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
        while ack_i(reg) = '0' loop
            clk_wait(clk_i);
            strobe_o <= (strobe_o'RANGE => '0');
        end loop;
        clk_wait(clk_i);
        strobe_o <= (strobe_o'RANGE => '0');
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
        result : out reg_data_t)
    is
    begin
        strobe_o <= (strobe_o'RANGE => '0');
        strobe_o(reg) <= '1';
        while ack_i(reg) = '0' loop
            clk_wait(clk_i);
            strobe_o <= (strobe_o'RANGE => '0');
        end loop;
        result := data_i(reg);
        clk_wait(clk_i);
        strobe_o <= (strobe_o'RANGE => '0');

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


    procedure write(message : string := "") is
        variable linebuffer : line;
    begin
        write(linebuffer, message);
        writeline(output, linebuffer);
    end;

end package body;
