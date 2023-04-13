-- Implementation of dot product using a cascaded array of DSP units

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity multichannel_fir is
    generic (
        -- Number of concurrent channels of data
        CHANNELS : natural := 1;
        -- Can override default delay memory style
        DELAY_MEM_STYLE : string := "";
        -- Filter gain.  This is the log2 of any extra gain applied to the
        -- result of the filter.  This will almost certainly need to be set to a
        -- negative number to compensate for extra gain on the filter taps.
        --
        -- Gain is defined by treating all of tap_i, data_i, data_o as fixed
        -- point numbers each scaled to the range +-1 (or more precisely a half
        -- open range [-1..+1) where the upper limit is 1-2^-(N-1) for an N bit
        -- signed number).
        FILTER_GAIN : integer := 0;
        -- Delay from enable_i to enable_o
        PROCESS_DELAY : natural := 3    -- Used to validate the process delay
    );
    port (
        clk_i : in std_ulogic;

        taps_i : in signed_array;

        enable_i : in std_ulogic := '1';
        last_i : in std_ulogic := '1';
        data_i : in signed;

        enable_o : out std_ulogic;
        last_o : out std_ulogic;
        data_o : out signed;
        overflow_o : out std_ulogic
    );
end;

architecture arch of multichannel_fir is
    constant TAP_COUNT : natural := taps_i'LENGTH;
    constant TAP_WIDTH : natural := taps_i(taps_i'LEFT)'LENGTH;
    constant DATA_WIDTH : natural := data_i'LENGTH;
    constant RESULT_WIDTH : natural := data_o'LENGTH;

    -- Scale the final output so that the binary point is in the correct place.
    -- We start by treating the data and taps as signed values of size S1.D-1
    -- and S1.T-1 respectively, so the raw product is S2.D+T-2.  This is scaled
    -- to fit into a result of size S1.R-1 by discarding D+T-2-(R-1) bottom
    -- bits.  Finally the result is shifted by G bits to produce a result of
    -- size S1-G.R+G-1 to take account of the desired extra filter gain.
    constant OFFSET_OUT : natural :=
        TAP_WIDTH + DATA_WIDTH - RESULT_WIDTH - 1 - FILTER_GAIN;

    signal data_delays : signed_array(taps_i'RANGE)(DATA_WIDTH-1 downto 0);

begin
    -- Delay data between taps to allow for circulation of data through the
    -- incoming channels
    delays : for i in 1 to TAP_COUNT-1 generate
        data_delay : entity work.fixed_delay generic map (
            WIDTH => DATA_WIDTH,
            DELAY => CHANNELS - 1,
            MEM_STYLE => DELAY_MEM_STYLE
        ) port map (
            clk_i => clk_i,
            enable_i => enable_i,
            data_i => std_ulogic_vector(data_delays(i)),
            signed(data_o) => data_delays(i-1)
        );
    end generate;
    data_delays(TAP_COUNT-1) <= data_i;


    -- Align enable and last output signals with generated data
    control : entity work.fixed_delay generic map (
        WIDTH => 2,
        DELAY => PROCESS_DELAY,
        INITIAL => '1'              -- Should allow elision if not needed
    ) port map (
        clk_i => clk_i,
        data_i(0) => enable_i,
        data_i(1) => last_i,
        data_o(0) => enable_o,
        data_o(1) => last_o
    );


    -- Signal processing of core.  The carefully programmed data delays ensure
    -- incoming data is filtered in individual channels.
    dot_product : entity work.dot_product generic map (
        A_WIDTH => DATA_WIDTH,
        B_WIDTH => TAP_WIDTH,
        TAP_COUNT => TAP_COUNT,
        OFFSET_OUT => OFFSET_OUT,
        PROCESS_DELAY => PROCESS_DELAY
    ) port map (
        clk_i => clk_i,

        enable_i => enable_i,
        a_i => data_delays,
        b_i => taps_i,

        ab_o => data_o,
        ovf_o => overflow_o
    );
end;
