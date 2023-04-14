-- Example register definitions

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;
use work.register_defs.all;

use work.register_defines.all;

entity test_registers is
    port (
        clk_i : in std_ulogic;

        -- Register control interface
        write_strobe_i : in std_ulogic_vector(TEST_REGS_RANGE);
        write_data_i : in reg_data_array_t(TEST_REGS_RANGE);
        write_ack_o : out std_ulogic_vector(TEST_REGS_RANGE);
        read_strobe_i : in std_ulogic_vector(TEST_REGS_RANGE);
        read_data_o : out reg_data_array_t(TEST_REGS_RANGE);
        read_ack_o : out std_ulogic_vector(TEST_REGS_RANGE);

        event_bits_i : in reg_data_t;
        command_bits_o : out reg_data_t;
        control_a_o : out reg_data_t;
        control_b_o : out reg_data_t;
        register_block_o : out reg_data_array_t;

        write_seq_i : in register_write_t;

        cc_clk_i : in std_ulogic;
        cc_data_o : out reg_data_t;
        cc_strobe_o : out std_ulogic
    );
end;

architecture arch of test_registers is
    signal control_bits : reg_data_array_t(TEST_CONTROL_REGS);
    signal write_start : std_ulogic;
    signal read_start : std_ulogic;

begin
    -- EVENTS register (transient pulse detection, clear on read)
    events : entity work.register_events port map (
        clk_i => clk_i,
        read_strobe_i => read_strobe_i(TEST_EVENTS_REG_R),
        read_data_o => read_data_o(TEST_EVENTS_REG_R),
        read_ack_o => read_ack_o(TEST_EVENTS_REG_R),
        pulsed_bits_i => event_bits_i
    );

    -- COMMAND register (one-shot triggered events)
    command : entity work.register_command port map (
        clk_i => clk_i,
        write_strobe_i => write_strobe_i(TEST_COMMAND_REG_W),
        write_data_i => write_data_i(TEST_COMMAND_REG_W),
        write_ack_o => write_ack_o(TEST_COMMAND_REG_W),
        strobed_bits_o => command_bits_o
    );

    -- CONTROL register block (static read-write)
    control : entity work.register_file_rw port map (
        clk_i => clk_i,
        write_strobe_i => write_strobe_i(TEST_CONTROL_REGS),
        write_data_i => write_data_i(TEST_CONTROL_REGS),
        write_ack_o => write_ack_o(TEST_CONTROL_REGS),
        read_strobe_i => read_strobe_i(TEST_CONTROL_REGS),
        read_data_o => read_data_o(TEST_CONTROL_REGS),
        read_ack_o => read_ack_o(TEST_CONTROL_REGS),
        register_data_o => control_bits
    );

    control_a_o <= control_bits(TEST_CONTROL_A_REG);
    control_b_o <= control_bits(TEST_CONTROL_B_REG);

    -- Register that updates every time it is read
    counter : entity work.test_counter port map (
        clk_i => clk_i,
        write_strobe_i => write_strobe_i(TEST_COUNTER_REG),
        write_data_i => write_data_i(TEST_COUNTER_REG),
        write_ack_o => write_ack_o(TEST_COUNTER_REG),
        read_strobe_i => read_strobe_i(TEST_COUNTER_REG),
        read_data_o => read_data_o(TEST_COUNTER_REG),
        read_ack_o => read_ack_o(TEST_COUNTER_REG)
    );


    -- Block writing and reading
    write_block : entity work.register_write_block port map (
        clk_i => clk_i,
        write_strobe_i => write_strobe_i(TEST_BLOCK_REG),
        write_data_i => write_data_i(TEST_BLOCK_REG),
        write_ack_o => write_ack_o(TEST_BLOCK_REG),
        write_start_i => write_start,
        registers_o => register_block_o
    );

    read_block : entity work.register_read_block port map (
        clk_i => clk_i,
        read_strobe_i => read_strobe_i(TEST_BLOCK_REG),
        read_data_o => read_data_o(TEST_BLOCK_REG),
        read_ack_o => read_ack_o(TEST_BLOCK_REG),
        read_start_i => read_start,
        registers_i => register_block_o
    );

    write_start <= command_bits_o(0);
    read_start <= command_bits_o(1);


    -- Register clock domain crossing
    file_cc : entity work.register_file_cc port map (
        clk_reg_i => clk_i,
        write_strobe_i(0) => write_strobe_i(TEST_CC_REG_W),
        write_data_i(0) => write_data_i(TEST_CC_REG_W),
        write_ack_o(0) => write_ack_o(TEST_CC_REG_W),
        clk_data_i => cc_clk_i,
        register_data_o(0) => cc_data_o,
        data_strobe_o(0) => cc_strobe_o
    );


    -- Register sequence
    read_sequence : entity work.register_read_sequence port map (
        clk_i => clk_i,
        write_i => write_seq_i,
        read_start_i => read_start,
        read_strobe_i => read_strobe_i(TEST_READ_SEQ_REG_R),
        read_data_o => read_data_o(TEST_READ_SEQ_REG_R),
        read_ack_o => read_ack_o(TEST_READ_SEQ_REG_R)
    );
end;
