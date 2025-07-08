library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.textio.all;

use work.support.all;
use work.register_defs.all;

use work.register_defines.all;

use work.sim_support.all;

entity testbench is
end testbench;

architecture arch of testbench is
    constant CLK_PERIOD : time := 2 ns;
    constant REG_CLK_PERIOD : time := 3.71 ns;
    constant CC_CLK_PERIOD : time := 1.45 ns;

    signal clk : std_ulogic := '0';

    -- Extra clocks for cross domain checks
    signal reg_clk : std_ulogic := '0';
    signal cc_clk : std_ulogic := '0';

    -- Should be controlled on clk domain
    signal reg_clk_ok : std_ulogic := '1';

    constant ADDRESS_WIDTH : natural := 12;
    subtype ADDRESS_RANGE is natural range ADDRESS_WIDTH-1 downto 0;

    -- Raw register interface with addresses on clk domain
    signal write_strobe : std_ulogic;
    signal write_address : unsigned(ADDRESS_RANGE);
    signal write_data : reg_data_t;
    signal write_ack : std_ulogic;
    signal read_strobe : std_ulogic;
    signal read_address : unsigned(ADDRESS_RANGE);
    signal read_data : reg_data_t;
    signal read_ack : std_ulogic;

    -- Register interface on reg_clk domain
    signal reg_write_strobe : std_ulogic;
    signal reg_write_address : unsigned(ADDRESS_RANGE);
    signal reg_write_data : reg_data_t;
    signal reg_write_ack : std_ulogic;
    signal reg_read_strobe : std_ulogic;
    signal reg_read_address : unsigned(ADDRESS_RANGE);
    signal reg_read_data : reg_data_t;
    signal reg_read_ack : std_ulogic;

    -- Decoded register interface
    signal test_write_strobe : std_ulogic_vector(TEST_REGS_RANGE);
    signal test_write_data : reg_data_array_t(TEST_REGS_RANGE);
    signal test_write_ack : std_ulogic_vector(TEST_REGS_RANGE);
    signal test_read_strobe : std_ulogic_vector(TEST_REGS_RANGE);
    signal test_read_data : reg_data_array_t(TEST_REGS_RANGE);
    signal test_read_ack : std_ulogic_vector(TEST_REGS_RANGE);

    signal event_bits : reg_data_t := (others => '0');
    signal command_bits : reg_data_t;
    signal control_a : reg_data_t;
    signal control_b : reg_data_t;
    signal register_block : reg_data_array_t(0 to 5);

    signal write_seq : register_write_t(address(1 downto 0));

    signal cc_data : reg_data_t;
    signal cc_strobe : std_ulogic;

begin
    clk <= not clk after CLK_PERIOD;
    reg_clk <= not reg_clk after REG_CLK_PERIOD;
    cc_clk <= not cc_clk after CC_CLK_PERIOD;


    -- Transfer register control over to reg_clk to test clock crossing
    register_cc : entity work.register_bank_cc port map (
        clk_in_i => clk,
        clk_out_i => reg_clk,
        clk_out_ok_i => reg_clk_ok,

        write_address_i => write_address,
        write_data_i => write_data,
        write_strobe_i => write_strobe,
        write_ack_o => write_ack,

        read_address_i => read_address,
        read_data_o => read_data,
        read_strobe_i => read_strobe,
        read_ack_o => read_ack,

        write_address_o => reg_write_address,
        write_data_o => reg_write_data,
        write_strobe_o => reg_write_strobe,
        write_ack_i => reg_write_ack,

        read_address_o => reg_read_address,
        read_data_i => reg_read_data,
        read_strobe_o => reg_read_strobe,
        read_ack_i => reg_read_ack
    );


    -- Decode register addresses
    register_mux : entity work.register_mux generic map (
        BUFFER_DEPTH => 1
    ) port map (
        clk_i => reg_clk,

        -- Raw registers
        write_strobe_i => reg_write_strobe,
        write_address_i => reg_write_address,
        write_data_i => reg_write_data,
        write_ack_o => reg_write_ack,
        read_strobe_i => reg_read_strobe,
        read_address_i => reg_read_address,
        read_data_o => reg_read_data,
        read_ack_o => reg_read_ack,

        -- Decoded registers
        write_strobe_o => test_write_strobe,
        write_data_o => test_write_data,
        write_ack_i => test_write_ack,
        read_strobe_o => test_read_strobe,
        read_data_i => test_read_data,
        read_ack_i => test_read_ack
    );


    -- Register destination
    test_registers : entity work.test_registers port map (
        clk_i => reg_clk,

        write_strobe_i => test_write_strobe,
        write_data_i => test_write_data,
        write_ack_o => test_write_ack,
        read_strobe_i => test_read_strobe,
        read_data_o => test_read_data,
        read_ack_o => test_read_ack,

        event_bits_i => event_bits,
        command_bits_o => command_bits,
        control_a_o => control_a,
        control_b_o => control_b,
        register_block_o => register_block,

        write_seq_i => write_seq,

        cc_clk_i => cc_clk,
        cc_data_o => cc_data,
        cc_strobe_o => cc_strobe
    );


    -- Loop the command bits back as event bits
    event_bits <= command_bits;


    -- Testbench
    process
        procedure clk_wait(count : in natural := 1) is
        begin
            clk_wait(clk, count);
        end procedure;

        procedure write_reg(address : natural; data : reg_data_t) is
        begin
            write_reg(
                clk, write_data, write_address, write_strobe, write_ack,
                address, data);
        end;

        procedure read_reg(address : ADDRESS_RANGE) is
        begin
            read_reg(
                clk, read_data, read_address, read_strobe, read_ack,
                address);
        end;

    begin
        write_strobe <= '0';
        read_strobe <= '0';

        clk_wait(10);

        write_reg(TEST_COMMAND_REG_W, X"01234560");
        read_reg(TEST_EVENTS_REG_R);
        read_reg(TEST_EVENTS_REG_R);

        read_reg(TEST_CONTROL_A_REG);
        write_reg(TEST_CONTROL_A_REG, X"89ABCDEF");
        read_reg(TEST_CONTROL_A_REG);
        write_reg(TEST_CONTROL_B_REG, X"DEADBEEF");
        read_reg(TEST_CONTROL_B_REG);

        read_reg(TEST_COUNTER_REG);
        read_reg(TEST_COUNTER_REG);
        read_reg(TEST_COUNTER_REG);
        write_reg(TEST_COUNTER_REG, X"76543210");
        read_reg(TEST_COUNTER_REG);
        read_reg(TEST_COUNTER_REG);
        read_reg(TEST_COUNTER_REG);

        write_reg(TEST_COMMAND_REG_W, X"00000001");
        write_reg(TEST_BLOCK_REG, X"00000000");
        write_reg(TEST_BLOCK_REG, X"00000001");
        write_reg(TEST_BLOCK_REG, X"00000002");
        write_reg(TEST_BLOCK_REG, X"00000003");

        write_reg(TEST_COMMAND_REG_W, X"00000002");
        read_reg(TEST_BLOCK_REG);
        read_reg(TEST_BLOCK_REG);
        read_reg(TEST_BLOCK_REG);
        read_reg(TEST_BLOCK_REG);
        read_reg(TEST_BLOCK_REG);

        write_reg(TEST_CC_REG_W, X"12345678");

        write_reg(TEST_COMMAND_REG_W, X"00000002");
        read_reg(TEST_READ_SEQ_REG_R);
        read_reg(TEST_READ_SEQ_REG_R);
        read_reg(TEST_READ_SEQ_REG_R);
        read_reg(TEST_READ_SEQ_REG_R);

        write("Test complete", true);

        wait;
    end process;


    -- Sequence writer
    process
        procedure clk_wait(count : in natural := 1) is
        begin
            clk_wait(reg_clk, count);
        end procedure;

        procedure write_data(value : reg_data_t) is
        begin
            write_seq.strobe <= '1';
            write_seq.data <= value;
            clk_wait;

            write_seq <= (
                strobe => '0',
                data => (others => 'U'),
                address => write_seq.address + 1);
            clk_wait;
        end;
    begin
        write_seq <= (strobe => '0', address => "00", data => (others => 'U'));

        clk_wait(100);
        write_data(X"01020304");
        write_data(X"98765432");
        write_data(X"55555555");

        wait;
    end process;
end;
