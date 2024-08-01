-- Simple IO fifo based on matched input and output frequencies, sometimes
-- referred to as "mesochronous" clocks.  This allows the FIFO synchronisation
-- to be substantially simplified.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity in_fifo is
    generic (
        FIFO_WIDTH : natural
    );
    port (
        clk_in_i : in std_ulogic;
        data_i : in std_ulogic_vector(FIFO_WIDTH-1 downto 0);

        clk_out_i : in std_ulogic;
        data_o : out std_ulogic_vector(FIFO_WIDTH-1 downto 0)
            := (others => '0');
        -- reset_i must be strobed to establish normal operation.  error_o may
        -- be asserted for about 12 ticks until reset is complete
        reset_i : in std_ulogic;
        -- This error indication will detect gross errors in phase between
        -- clk_in_i and clk_out_i and may detect most other errors.
        error_o : out std_ulogic := '0'
    );
end;

architecture arch of in_fifo is
    constant FIFO_DEPTH : natural := 8;
    subtype FIFO_PTR is natural range 0 to FIFO_DEPTH-1;
    signal fifo : vector_array(FIFO_PTR)(FIFO_WIDTH-1 downto 0)
        := (others => (others => '0'));

    signal in_ptr : FIFO_PTR := 0;
    signal out_ptr : FIFO_PTR := 0;

    -- Stretched and synchronised resets
    signal in_reset : std_ulogic;
    signal out_reset : std_ulogic;

    -- If the input and output clocks are out of step there will be a
    -- discrepancy between the input and output phases
    signal phase_fifo : std_ulogic_vector(FIFO_PTR) := (others => '0');
    signal in_phase : std_ulogic := '0';
    signal out_phase : std_ulogic := '0';

    -- It will take one or two ticks of the common clock for reset to propagate
    -- from out to in, after which we want the in pointer to be around half the
    -- FIFO ahead.
    constant IN_PTR_RESET : FIFO_PTR := FIFO_DEPTH/2 + 2;
    constant OUT_PTR_RESET : FIFO_PTR := 0;

begin
    -- Stretch reset long enough to safely cross through sync_bit
    stretch : entity work.stretch_pulse generic map (
        DELAY => 4
    ) port map (
        clk_i => clk_out_i,
        pulse_i => reset_i,
        pulse_o => out_reset
    );

    -- Carry reset over to input clock domain
    sync : entity work.sync_bit port map (
        clk_i => clk_in_i,
        bit_i => out_reset,
        bit_o => in_reset
    );


    process (clk_in_i) begin
        if rising_edge(clk_in_i) then
            if in_reset then
                in_ptr <= IN_PTR_RESET;
                in_phase <= '0';
            else
                in_ptr <= (in_ptr + 1) mod FIFO_DEPTH;
                if in_ptr = FIFO_DEPTH - 1 then
                    in_phase <= not in_phase;
                end if;
            end if;
            fifo(in_ptr) <= data_i;
            phase_fifo(in_ptr) <= in_phase;
        end if;
    end process;


    process (clk_out_i) begin
        if rising_edge(clk_out_i) then
            if out_reset then
                out_ptr <= OUT_PTR_RESET;
                out_phase <= '0';
            else
                out_ptr <= (out_ptr + 1) mod FIFO_DEPTH;
                if out_ptr = FIFO_DEPTH - 1 then
                    out_phase <= not out_phase;
                end if;
            end if;
            data_o <= fifo(out_ptr);
            error_o <= to_std_ulogic(phase_fifo(out_ptr) /= out_phase);
        end if;
    end process;
end;
