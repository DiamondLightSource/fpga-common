library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.support.all;
use work.axi_defs.all;

entity testbench is
end;

architecture arch of testbench is
    signal clk : std_ulogic := '0';

    procedure clk_wait(count : in natural := 1) is
    begin
        for i in 0 to count-1 loop
            wait until rising_edge(clk);
        end loop;
    end procedure;

    signal axi_out : axi_write_t(
        address(15 downto 2), data(31 downto 0));
    signal axi_in : axi_write_ready_t;
    signal unexpected_completion : std_ulogic;
    signal missing_completion : std_ulogic;

    -- Multiplexed capture
    constant MUX_CHANNEL_COUNT : natural := 3;
    signal mux_in : axi_write_array_t(0 to MUX_CHANNEL_COUNT-1) (
        address(15 downto 2), data(31 downto 0));
    signal mux_out : axi_write_ready_array_t(0 to MUX_CHANNEL_COUNT-1);

    constant BURST_LENGTHS : integer_array(0 to MUX_CHANNEL_COUNT-1)
        := (16, 8, 1);
    constant ADDRESS_DELAYS : integer_array(0 to MUX_CHANNEL_COUNT-1)
--         := (10, 5, 10);
        := (20, 50, 10);
    constant DATA_DELAYS : integer_array(0 to MUX_CHANNEL_COUNT-1)
        := (0, 0, 0);

begin
    clk <= not clk after 1 ns;

    -- Device under test: multiplexed capture
    stream_mux : entity work.axi_write_mux generic map (
        ADDRESS_WIDTH => 16,
        LOG_DATA_BYTES => 2,    -- 4 bytes, 32 bits
        MUX_CHANNEL_COUNT => MUX_CHANNEL_COUNT,
        LOG_COMPLETION_QUEUE => 3
    ) port map (
        clk_i => clk,
        mux_i => mux_in,
        mux_o => mux_out,
        axi_o => axi_out,
        axi_i => axi_in,
        unexpected_completion_o => unexpected_completion,
        missing_completion_o => missing_completion
    );

    bursts : for i in 0 to MUX_CHANNEL_COUNT-1 generate
        burst_gen : entity work.burst_generator generic map (
            BURST_PREFIX => i,
            BURST_LENGTH => BURST_LENGTHS(i),
            ADDRESS_DELAY => ADDRESS_DELAYS(i),
            DATA_DELAY => DATA_DELAYS(i)
        ) port map (
            clk_i => clk,
            axi_o => mux_in(i),
            axi_i => mux_out(i)
        );

        validate : entity work.axi_write_validate port map (
            clk_i => clk,
            axi_i => mux_in(i),
            axi_ready_i => mux_out(i)
        );
    end generate;

    slave : entity work.axi_write_slave generic map (
        COMPLETE_DELAY => 30,
        ADDRESS_FIFO_BITS => 1
    ) port map (
        clk_i => clk,
        axi_i => axi_out,
        axi_o => axi_in
    );

    validate : entity work.axi_write_validate generic map (
        FAIL_ACTION => error
    ) port map (
        clk_i => clk,
        axi_i => axi_out,
        axi_ready_i => axi_in
    );
end;
