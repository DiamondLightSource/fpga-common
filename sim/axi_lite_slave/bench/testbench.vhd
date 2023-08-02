library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.support.all;

entity testbench is
end testbench;


architecture arch of testbench is
    signal clk : std_ulogic := '0';

    procedure clk_wait(count : in natural := 1) is
    begin
        for i in 1 to count loop
            wait until rising_edge(clk);
        end loop;
    end procedure;

    procedure write(message : string := "") is
        variable linebuffer : line;
    begin
        write(linebuffer, message);
        writeline(output, linebuffer);
    end;


    constant LOG_BYTES : natural := 2;
    constant ADDRESS_WIDTH : natural := 6;


    constant DATA_BYTES : natural := 2**LOG_BYTES;
    constant DATA_WIDTH : natural := 8 * DATA_BYTES;

    subtype AXI_ADDRESS_RANGE is natural range
        ADDRESS_WIDTH + LOG_BYTES - 1 downto LOG_BYTES;
    subtype REG_ADDRESS_RANGE is natural range ADDRESS_WIDTH - 1 downto 0;
    subtype DATA_RANGE is natural range DATA_WIDTH-1 downto 0;

    signal rstn : std_ulogic;

    signal araddr : std_ulogic_vector(AXI_ADDRESS_RANGE);
    signal arprot : std_ulogic_vector(2 downto 0);
    signal arready : std_ulogic;
    signal arvalid : std_ulogic;
    signal rdata : std_ulogic_vector(DATA_RANGE);
    signal rresp : std_ulogic_vector(1 downto 0);
    signal rready : std_ulogic;
    signal rvalid : std_ulogic;

    signal awaddr : std_ulogic_vector(AXI_ADDRESS_RANGE);
    signal awprot : std_ulogic_vector(2 downto 0);
    signal awready : std_ulogic;
    signal awvalid : std_ulogic;
    signal wdata : std_ulogic_vector(DATA_RANGE);
    signal wstrb : std_ulogic_vector(DATA_BYTES-1 downto 0);
    signal wready : std_ulogic;
    signal wvalid : std_ulogic;
    signal bresp : std_ulogic_vector(1 downto 0);
    signal bready : std_ulogic;
    signal bvalid : std_ulogic;

    signal read_strobe : std_ulogic;
    signal read_address : unsigned(REG_ADDRESS_RANGE);
    signal read_data : std_ulogic_vector(DATA_RANGE);
    signal read_ack : std_ulogic;
    signal write_strobe : std_ulogic;
    signal write_address : unsigned(REG_ADDRESS_RANGE);
    signal write_data : std_ulogic_vector(DATA_RANGE);
    signal write_ack : std_ulogic;

    signal register_array : vector_array(0 to 2**ADDRESS_WIDTH-1)(DATA_RANGE);

begin
    clk <= not clk after 2 ns;

    axi_slave : entity work.axi_lite_slave port map (
        clk_i => clk,
        rstn_i => rstn,

        araddr_i => araddr,
        arprot_i => arprot,
        arready_o => arready,
        arvalid_i => arvalid,
        rdata_o => rdata,
        rresp_o => rresp,
        rready_i => rready,
        rvalid_o => rvalid,

        awaddr_i => awaddr,
        awprot_i => awprot,
        awready_o => awready,
        awvalid_i => awvalid,
        wdata_i => wdata,
        wstrb_i => wstrb,
        wready_o => wready,
        wvalid_i => wvalid,
        bresp_o => bresp,
        bready_i => bready,
        bvalid_o => bvalid,

        read_strobe_o => read_strobe,
        read_address_o => read_address,
        read_data_i => read_data,
        read_ack_i => read_ack,

        write_strobe_o => write_strobe,
        write_address_o => write_address,
        write_data_o => write_data,
        write_ack_i => write_ack
    );

    -- Dummy values
    arprot <= "000";
    awprot <= "000";


    -- AXI generator
    process
        procedure axi_read(address : natural) is
        begin
            araddr <= to_std_ulogic_vector_u(address, araddr'LENGTH);
            rready <= '1';
            arvalid <= '1';
            clk_wait;

            -- Send the read address
            while not arready loop
                clk_wait;
            end loop;

            -- Wait for response
            while not rvalid loop
                clk_wait;
            end loop;
            arvalid <= '0';

            write(
                "@ " & to_string(now, unit => ns) &
                ": axi_read [" & natural'image(address) &
                "] => " & to_hstring(rdata));
        end;

        procedure axi_write(address : natural; data : std_ulogic_vector) is
        begin
            awaddr <= to_std_ulogic_vector_u(address, awaddr'LENGTH);
            wdata <= data;
            awvalid <= '1';
            wvalid <= '1';
            clk_wait;

            loop
                awvalid <= awvalid and not awready;
                wvalid <= wvalid and not wready;
                exit when (not awvalid or awready) and (not wvalid or wready);
                clk_wait;
            end loop;

            bready <= '1';
            clk_wait;
            while not bvalid loop
                clk_wait;
            end loop;
            bready <= '0';

            write(
                "@ " & to_string(now, unit => ns) &
                ": axi_write [" & natural'image(address) &
                "] <= " & to_hstring(data));
        end;

    begin
        rstn <= '0';
        arvalid <= '0';
        rready <= '0';
        awvalid <= '0';
        wvalid <= '0';
        bready <= '0';
        wstrb <= "0000";

        clk_wait(10);
        rstn <= '1';
        clk_wait;

        axi_write(123, X"12345678");
        wstrb <= "1111";

        axi_write(0, X"12345678");
        axi_write(1, X"9ABCDEF0");
        axi_write(2, X"DEADBEEF");

        axi_read(0);
        axi_read(1);
        axi_read(2);

        wait;
    end process;


    -- Register read response
    process begin
        read_ack <= '0';

        wait until read_strobe;

        -- Bottom bits of address program in delay
        clk_wait(to_integer(read_address(1 downto 0)));
        read_data <= register_array(to_integer(read_address));
        read_ack <= '1';
        clk_wait;
        read_data <= (others => 'U');

    end process;

    -- Register write response, similar behaviour to read
    process begin
        write_ack <= '0';

        wait until write_strobe;

        clk_wait(to_integer(write_address(1 downto 0)));
        register_array(to_integer(write_address)) <= write_data;
        write_ack <= '1';
        clk_wait;
    end process;
end;
