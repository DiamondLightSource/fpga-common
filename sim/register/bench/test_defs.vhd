-- Register definitions for test

package test_defs is
    subtype TEST_REGS_RANGE is natural range 0 to 5;

    -- Events capture
    constant TEST_EVENTS_REG_R : natural := 0;
    -- Pulsed commands
    constant TEST_COMMAND_REG_W : natural := 0;
    -- Two miscellaneous read/write control registers
    subtype TEST_CONTROL_REGS is natural range 1 to 2;
    constant TEST_CONTROL_A_REG : natural := 1;
    constant TEST_CONTROL_B_REG : natural := 2;
    -- Reading this counter auto-increments, writing sets value
    constant TEST_COUNTER_REG : natural := 3;
    -- Registers for sequential reading and writing a fixed array
    constant TEST_BLOCK_REG : natural := 4;
    -- Register for clock domain crossing
    constant TEST_CC_REG_W : natural := 5;
    -- Register for reading sequence
    constant TEST_READ_SEQ_REG_R : natural := 5;
end;
