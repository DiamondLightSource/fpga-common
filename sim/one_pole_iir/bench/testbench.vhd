library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

use work.stream_defs.all;

entity testbench is
end testbench;

architecture arch of testbench is
    signal clk : std_ulogic := '0';

    procedure clk_wait(count : in natural := 1) is
    begin
        for i in 0 to count-1 loop
            wait until rising_edge(clk);
        end loop;
    end procedure;

    constant CHANNELS : natural := 3;
    constant DATA_WIDTH : natural := 16;

    signal iir_shift : unsigned(2 downto 0);

    -- Multiplexed stream into and out of IIR under test
    signal test_stream_in : data_stream_t(data(DATA_WIDTH-1 downto 0));
    signal test_stream_out : data_stream_t(data(DATA_WIDTH-1 downto 0));

    signal test_enables_in : std_ulogic_vector(0 to CHANNELS-1)
        := (others => '0');
    signal test_enables_out : std_ulogic_vector(0 to CHANNELS-1);
    signal test_data_in : signed_array(0 to CHANNELS-1)(DATA_WIDTH-1 downto 0)
        := (others => (others => '0'));
    signal test_data_out : signed_array(0 to CHANNELS-1)(DATA_WIDTH-1 downto 0);

begin
    clk <= not clk after 1 ns;

    stream_mux : entity work.stream_mux generic map (
        WIDTH => DATA_WIDTH,
        WAYS => CHANNELS
    ) port map (
        clk_i => clk,
        enables_i => test_enables_in,
        data_i => vector_array(test_data_in),
        stream_o => test_stream_in
    );

    iir : entity work.one_pole_iir generic map (
        SHIFTS => (0, 2, 6),
        CHANNELS => CHANNELS
    ) port map (
        clk_i => clk,
        iir_shift_i => iir_shift,
        stream_i => test_stream_in,
        stream_o => test_stream_out
    );

    stream_demux : entity work.stream_demux generic map (
        WIDTH => DATA_WIDTH,
        WAYS => CHANNELS
    ) port map (
        clk_i => clk,
        stream_i => test_stream_out,
        enables_o => test_enables_out,
        signed_array(data_o) => test_data_out
    );


    process
        procedure push_data(data : signed) is
        begin
            for c in 0 to CHANNELS-1 loop
                if c mod 2 = 0 then
                    test_data_in(c) <= data;
                else
                    test_data_in(c) <= (others => '0');
                end if;
            end loop;
        end;

        procedure strobe_data(count : natural) is
        begin
            for n in 1 to count loop
                test_enables_in <= (others => '1');
                clk_wait;
                test_enables_in <= (others => '0');
                clk_wait(CHANNELS);
            end loop;
        end;

        procedure test_step(shift : unsigned; delay : natural) is
        begin
            iir_shift <= shift;

            push_data(X"7FFF");
            strobe_data(delay);
            push_data(X"8000");
            strobe_data(delay);
            push_data(X"0000");
            strobe_data(delay);
        end;

    begin
        clk_wait(5);

        test_step("000", 20);
        test_step("001", 200);
        test_step("010", 500);
    end process;
end;
