-- Implements register interface to MBF system

-- This is an AXI-Lite slave which only accepts full 32-bit writes.  The
-- incoming address is split into three parts, where ADDR_WIDTH is determined
-- by the size of read_address_o (and write_address_o):
--
--  +----------+-------------------------------+------+
--  | Ignored  | Outgoing address              | Byte |
--  +----------+-------------------------------+------+
--              ADDR_WIDTH                      BYTE_BITS
--
-- The internal write interface is quite simple: write_strobe_o is pulsed for
-- one clock cycle after the write_address and write_data outputs are valid.
-- The write data and address will be held valid until write_ack_i is high:
--
--  State           | IDLE  |WRITING| DONE  |
--                          _________________
--  write_data_o,   XXXXXXXX_________________
--  write_address_o
--                            _______
--  write_strobe_o  _________/       \_______
--
-- This means that modules can implement a simple one-cycle write interface by
-- holding write_ack_i high.
--
-- Inevitably, the read interface is a little more involved, and completion can
-- be stretched by the module using the module specific read_ack signal.  For
-- single cycle reads which don't depend on read_strobe, read_ack can be
-- permanently high as shown here:
--
--  State           | IDLE  |READING| DONE  |
--                          _________________
--  read_address_o  XXXXXXXX_________________
--                            _______
--  read_strobe_o   _________/       \_______
--                           ________
--  read_data_i     XXXXXXXXX________XXXXXXXX
--                  _________________________
--  read_ack_i                                          (permanently high)
--
-- Alternatively read_ack can be generated some delay after read_strobe if it is
-- necessary to delay the generation of read_data:
--
--  State           | IDLE  |READING|READING|READING| DONE  |
--                          _________________________________
--  read_address_o  XXXXXXXX_________________________________
--                            _______
--  read_strobe_o   _________/       \_______________________
--                                           ________
--  read_data_i     XXXXXXXXXXXXXXXXXXXXXXXXX________XXXXXXXX
--                                            _______
--  read_ack_i      _________________________/       \_______
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity axi_lite_slave is
    port (
        clk_i : in std_ulogic;
        rstn_i : in std_ulogic;

        -- AXI-Lite read interface
        araddr_i : in std_ulogic_vector;
        arprot_i : in std_ulogic_vector(2 downto 0);                 -- Ignored
        arready_o : out std_ulogic;
        arvalid_i : in std_ulogic;
        --
        rdata_o : out std_ulogic_vector;
        rresp_o : out std_ulogic_vector(1 downto 0);
        rready_i : in std_ulogic;
        rvalid_o : out std_ulogic;

        -- AXI-Lite write interface
        awaddr_i : in std_ulogic_vector;
        awprot_i : in std_ulogic_vector(2 downto 0);                 -- Ignored
        awready_o : out std_ulogic;
        awvalid_i : in std_ulogic;
        --
        wdata_i : in std_ulogic_vector;
        wstrb_i : in std_ulogic_vector;
        wready_o : out std_ulogic;
        wvalid_i : in std_ulogic;
        --
        bresp_o : out std_ulogic_vector(1 downto 0);
        bready_i : in std_ulogic;
        bvalid_o : out std_ulogic;

        -- Internal read interface
        read_strobe_o : out std_ulogic;          -- Read request strobe
        read_address_o : out unsigned;
        read_data_i : in std_ulogic_vector;
        read_ack_i : in std_ulogic;              -- Read data valid acknowledge

        -- Internal write interface
        write_strobe_o : out std_ulogic;         -- Write request strobe
        write_address_o : out unsigned;
        write_data_o : out std_ulogic_vector;
        write_ack_i : in std_ulogic              -- Write complete acknowledge
    );
end;

architecture arch of axi_lite_slave is
    constant BYTE_BITS : natural := bits(wstrb_i'LENGTH-1);
    constant ADDR_WIDTH : natural := read_address_o'LENGTH;

    -- Reading state
    type read_state_t is (READ_IDLE, READ_READING, READ_DONE);
    signal read_state : read_state_t;

    -- Writing state
    -- The data and address for writes can come separately.
    type write_state_t is (WRITE_IDLE, WRITE_WRITING, WRITE_DONE);
    signal write_state : write_state_t;
    signal ready_out : std_ulogic := '0';

    -- Extracts register address from AXI address
    function register_address(addr : std_ulogic_vector) return unsigned
    is begin
        return unsigned(addr(ADDR_WIDTH + BYTE_BITS - 1 downto BYTE_BITS));
    end;

begin
    assert read_address_o'LENGTH = write_address_o'LENGTH
        report "Read and write addresses must be same length"
        severity failure;

    -- ------------------------------------------------------------------------
    -- Read interface.

    process (rstn_i, clk_i) begin
        if rstn_i = '0' then
            read_state <= READ_IDLE;
            read_strobe_o <= '0';
        elsif rising_edge(clk_i) then
            case read_state is
                when READ_IDLE =>
                    -- On valid read request latch read address
                    if arvalid_i = '1' then
                        read_strobe_o <= '1';
                        read_address_o <= register_address(araddr_i);
                        read_state <= READ_READING;
                    end if;
                when READ_READING =>
                    -- Wait for read acknowledge from module
                    read_strobe_o <= '0';
                    if read_ack_i = '1' then
                        rdata_o <= read_data_i;
                        read_state <= READ_DONE;
                    end if;
                when READ_DONE =>
                    -- Waiting for master to acknowledge our data.
                    if rready_i = '1' then
                        read_state <= READ_IDLE;
                    end if;
            end case;
        end if;
    end process;
    arready_o <= to_std_ulogic(read_state = READ_IDLE);
    rvalid_o  <= to_std_ulogic(read_state = READ_DONE);
    rresp_o <= "00";


    -- ------------------------------------------------------------------------
    -- Write interface.

    process (rstn_i, clk_i) begin
        if rstn_i = '0' then
            write_state <= WRITE_IDLE;
            write_strobe_o <= '0';
            ready_out <= '0';
        elsif rising_edge(clk_i) then
            case write_state is
                when WRITE_IDLE =>
                    -- Wait for valid read and write data
                    if awvalid_i = '1' and wvalid_i = '1' then
                        ready_out <= '1';
                        write_address_o <= register_address(awaddr_i);
                        write_data_o <= wdata_i;
                        if vector_and(wstrb_i) then
                            -- Generate write strobe for valid cycle
                            write_strobe_o <= '1';
                            write_state <= WRITE_WRITING;
                        else
                            -- For invalid write go straight to completion
                            write_state <= WRITE_DONE;
                        end if;
                    end if;

                when WRITE_WRITING =>
                    write_strobe_o <= '0';
                    ready_out <= '0';
                    if write_ack_i = '1' then
                        write_state <= WRITE_DONE;
                    end if;

                when WRITE_DONE =>
                    ready_out <= '0';
                    -- Wait for master to accept our response
                    if bready_i = '1' then
                        write_state <= WRITE_IDLE;
                    end if;
            end case;
        end if;
    end process;
    awready_o <= ready_out;
    wready_o  <= ready_out;
    bvalid_o  <= to_std_ulogic(write_state = WRITE_DONE);
    bresp_o <= "00";
end;
