-- Clock Crossing FIFO address management with optional read and write
-- reservation

-- For both read and write ports there is the option of supporting reservation
-- which provides access to a range of readable or writeable areas in the FIFO
-- address space.  If ENABLE_{READ,WRITE}_RESERVE is set then follow this access
-- pattern:
--
-- {read,write}_reserve_i must be successful (presented on the same cycle as the
-- corresponding write_ready_o,ready_valid_o signal on the same tick as or
-- before {read,write}_access_i.  In other words enable MUST NOT be asserted
-- without a corresponding enable and ready.  {read,write}_access_address_o will
-- unconditionally increment when the corresponding enable is asserted, whereas
-- {read,write}_reserve_address_o only increments on a successful reserve/ready
-- handshake.
--
-- If ENABLE_{READ,WRITE}_RESERVE is not set then {read,write}_reserve_i and
-- {read,write}_reserve_address_o should not be used and instead the access
-- address will advance on a successful ready/access exchange.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.support.all;

entity async_fifo_address is
    generic (
        ADDRESS_WIDTH : natural;
        ENABLE_READ_RESERVE : boolean;
        ENABLE_WRITE_RESERVE : boolean;
        MAX_DELAY : real := 4.0
    );
    port (
        write_clk_i : in std_ulogic;
        write_reset_i : in std_ulogic := '0';
        write_reserve_i : in std_ulogic := '0';
        write_access_i : in std_ulogic;
        write_ready_o : out std_ulogic := '1';
        write_reserve_address_o : out unsigned(ADDRESS_WIDTH-1 downto 0);
        write_access_address_o : out unsigned(ADDRESS_WIDTH-1 downto 0);

        read_clk_i : in std_ulogic;
        read_reset_i : in std_ulogic := '0';
        read_reserve_i : in std_ulogic := '0';
        read_access_i : in std_ulogic;
        read_valid_o : out std_ulogic := '0';
        read_reserve_address_o : out unsigned(ADDRESS_WIDTH-1 downto 0);
        read_access_address_o : out unsigned(ADDRESS_WIDTH-1 downto 0)
    );
end;

architecture arch of async_fifo_address is
    -- We use an extra bit on the address so that we can distinguish between
    -- empty and full by comparing addresses.
    subtype ADDRESS_RANGE is natural range ADDRESS_WIDTH downto 0;
    signal write_address : unsigned(ADDRESS_RANGE) := (others => '0');
    signal write_reserve : unsigned(ADDRESS_RANGE) := (others => '0');
    signal read_address : unsigned(ADDRESS_RANGE) := (others => '0');
    signal read_reserve : unsigned(ADDRESS_RANGE) := (others => '0');

    signal gray_write_address : std_ulogic_vector(ADDRESS_RANGE)
        := (others => '0');
    signal gray_read_address : std_ulogic_vector(ADDRESS_RANGE)
        := (others => '0');
    signal sync_write_address : std_ulogic_vector(ADDRESS_RANGE);
    signal sync_read_address : std_ulogic_vector(ADDRESS_RANGE);

    -- See comment below against write_ready_o calculation for this mask
    --
    -- This is a bit irritating, would like to simply write
    --
    --     constant COMPARE_MASK : std_ulogic_vector(ADDRESS_RANGE) := (
    --         ADDRESS_WIDTH downto ADDRESS_WIDTH-1 => '1', others => '0');
    --
    -- and this is accepted by both ModelSim and Vivado (though ModelSim does
    -- generate a warning).  However, GHDL doesn't like this, so we work around
    -- with the function below.
    function COMPARE_MASK return std_ulogic_vector
    is
        variable result : std_ulogic_vector(ADDRESS_RANGE);
    begin
        result := (others => '0');
        result(ADDRESS_WIDTH downto ADDRESS_WIDTH-1) := "11";
        return result;
    end;

    -- It is essential that the transfer from gray to sync does not see more
    -- than one bit change on any clock tick.  This *can* be constrained by use
    -- of the set_bus_skew constraint, but I don't see a clean way to pass the
    -- bus definitions through to the constraints file.  Instead we here use a
    -- custom attribute together with the following entry in the constraints
    -- file:
    --  set_max_delay 4 -datapath_only \
    --      -to [get_cells -hierarchical -filter { max_delay_from == "TRUE" }]
    -- Note that two Vivado limitiations prevent this from being pushed into the
    -- sync_bit entity: 1/ we must use -datapath_only which forces the attribute
    -- onto the source bit; and 2/ we cannot set DONT_TOUCH on input ports (and
    -- this is required).
    attribute max_delay_from : string;
    attribute max_delay_from of gray_write_address :
        signal is to_string(MAX_DELAY);
    attribute max_delay_from of gray_read_address :
        signal is to_string(MAX_DELAY);
    --
    -- The attribute values above need to be replaced with to_string(MAX_DELAY)
    -- and the constraints file entry needs to be replaced with a special
    -- constraints script of the form:
    --
    -- foreach cell [get_cells -hierarchical -filter { max_delay_from != "" }] {
    -- set_max_delay [get_property max_delay_from $cell] \
    --     -datapath_only -from $cell
    -- }

    attribute DONT_TOUCH : string;
    attribute DONT_TOUCH of gray_write_address : signal is "TRUE";
    attribute DONT_TOUCH of gray_read_address : signal is "TRUE";


    -- Shared address advance for read and write.  The access address is
    -- advanced unconditionally, whereas the reserve address is guarded; see
    -- notes at top of this file for application notes.
    procedure advance(
        enable_reserve : boolean;
        reset : std_ulogic; ready : std_ulogic;
        do_reserve : std_ulogic; do_access : std_ulogic;
        access_address : unsigned; reserve_address : unsigned;
        variable next_access_address : out unsigned(ADDRESS_RANGE);
        variable next_reserve_address : out unsigned(ADDRESS_RANGE)) is
    begin
        if reset then
            next_access_address := (others => '0');
            next_reserve_address := (others => '0');
        elsif enable_reserve then
            -- Maintain reserve and access addresses separately.  Access address
            -- advances without guard, relies on prior reservation.
            if do_access then
                next_access_address := access_address + 1;
            else
                next_access_address := access_address;
            end if;
            if do_reserve and ready then
                next_reserve_address := reserve_address + 1;
            else
                next_reserve_address := reserve_address;
            end if;
        else
            assert not do_reserve
                report "Reservation not enabled in this mode"
                severity failure;

            -- Simplified access pattern when reserve disabled, do_reserve is
            -- ignored, advance both addresses together.
            if do_access and ready then
                next_access_address := access_address + 1;
                next_reserve_address := access_address + 1;
            else
                next_access_address := access_address;
                next_reserve_address := access_address;
            end if;
        end if;
    end;

begin
    -- Synchronise each bit individually.  It is essential that at most one bit
    -- is uncertain after this synchronisation, this is achieved with a max
    -- delay constraint on each bit.
    gen_sync : for i in ADDRESS_RANGE generate
        sync_to_read : entity work.sync_bit generic map (
            FALSE_PATH => false
        ) port map (
            clk_i => read_clk_i,
            bit_i => gray_write_address(i),
            bit_o => sync_write_address(i)
        );

        sync_to_write : entity work.sync_bit generic map (
            FALSE_PATH => false
        ) port map (
            clk_i => write_clk_i,
            bit_i => gray_read_address(i),
            bit_o => sync_read_address(i)
        );
    end generate;


    -- Write
    process (write_clk_i)
        variable next_reserve_address : unsigned(ADDRESS_RANGE);
        variable next_write_address : unsigned(ADDRESS_RANGE);
    begin
        if rising_edge(write_clk_i) then
            advance(
                ENABLE_WRITE_RESERVE,
                write_reset_i, write_ready_o,
                write_reserve_i, write_access_i,
                write_address, write_reserve,
                next_write_address, next_reserve_address);

            write_address <= next_write_address;
            write_reserve <= next_reserve_address;
            gray_write_address <= unsigned_to_gray(next_write_address);

            -- The FULL comparision is a bit more tricky than for EMPTY.  First
            -- of all, we need the top bits to be unequal, because the FIFO is
            -- full when the pointers are in opposite halves of the cycle.  More
            -- tricky, we also require the second from top bits to be unequal
            -- because, as explained in Clifford Cummings, "Simulation and
            -- Synthesis Techniques for Asynchronous FIFO Design", the top bit
            -- of the Gray code is back to front.  Other bits must simply agree.
            write_ready_o <= not write_reset_i and to_std_ulogic(
                unsigned_to_gray(next_reserve_address) /=
                    (sync_read_address xor COMPARE_MASK));
        end if;
    end process;
    write_reserve_address_o <= write_reserve(ADDRESS_WIDTH-1 downto 0);
    write_access_address_o <= write_address(ADDRESS_WIDTH-1 downto 0);


    -- Read
    process (read_clk_i)
        variable next_reserve_address : unsigned(ADDRESS_RANGE);
        variable next_read_address : unsigned(ADDRESS_RANGE);
    begin
        if rising_edge(read_clk_i) then
            advance(
                ENABLE_READ_RESERVE,
                read_reset_i, read_valid_o,
                read_reserve_i, read_access_i,
                read_address, read_reserve,
                next_read_address, next_reserve_address);

            read_address <= next_read_address;
            read_reserve <= next_reserve_address;
            gray_read_address <= unsigned_to_gray(next_read_address);

            -- FIFO is empty when read reserve has caught up with write address
            read_valid_o <= to_std_ulogic(
                unsigned_to_gray(next_reserve_address) /= sync_write_address);
        end if;
    end process;
    read_reserve_address_o <= read_reserve(ADDRESS_WIDTH-1 downto 0);
    read_access_address_o <= read_address(ADDRESS_WIDTH-1 downto 0);
end;
