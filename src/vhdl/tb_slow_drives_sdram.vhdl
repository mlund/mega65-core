library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use Std.TextIO.all;
use work.debugtools.all;
use work.cputypes.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity tb_sdram_controller is
  generic (runner_cfg : string);
end entity;

architecture test_arch of tb_sdram_controller is

  constant SDRAM_BANK_WIDTH : integer := 2;
  constant SDRAM_ROW_WIDTH : integer := 13;
  constant SDRAM_COL_WIDTH : integer := 10;
  constant SDRAM_DATA_WIDTH : integer := 16;
  constant SDRAM_ADDR_WIDTH : integer := sdram_row_width + sdram_col_width + sdram_bank_width;

  signal pixelclock : std_logic := '0';
  signal clock41 : std_logic := '0';
  signal clock162 : std_logic := '0';

  signal slow_access_write : std_logic := '0';
  signal slow_access_rdata : unsigned(7 downto 0);
  signal slow_access_wdata : unsigned(7 downto 0);
  signal slow_access_address : unsigned(27 downto 0) := to_unsigned(0,28);
  signal slow_access_request_toggle : std_logic := '0';
  signal slow_access_ready_toggle : std_logic := '0';
  signal desired_slow_access_ready_toggle : std_logic := '0';


  signal slow_prefetched_request_toggle : std_logic ;
  signal slow_prefetched_data : unsigned(7 downto 0);
  signal slow_prefetched_address : unsigned(26 downto 0);

  signal slow_read : std_logic;
  signal slow_write : std_logic;
  signal slow_address : unsigned(26 downto 0);
  signal slow_wdata : unsigned(7 downto 0);
  signal slow_wdata_hi : unsigned(7 downto 0) := x"00";
  signal slow_wen_hi : std_logic := '0';
  signal slow_wen_lo : std_logic := '1';
  signal slow_rdata_hi : unsigned(7 downto 0);
  signal slow_rdata_16en : std_logic := '0';
  signal slow_rdata : unsigned(7 downto 0);
  signal slow_busy : std_logic;
  signal slow_data_ready_strobe : std_logic := '0';
  signal slow_data_ready_toggle : std_logic;
  signal data_ready_toggle : std_logic := '0';
  signal last_data_ready_toggle : std_logic := '0';
  signal busy : std_logic;
  signal current_cache_line : cache_row_t := (others => (others => '0'));
  signal current_cache_line_address : unsigned(26 downto 3) := (others => '0');
  signal current_cache_line_valid : std_logic := '0';
  signal expansionram_current_cache_line_next_toggle : std_logic := '0';
  signal expansionram_current_cache_line_prev_toggle : std_logic := '0';
  signal viciv_addr : unsigned(18 downto 3) := (others => '0');
  signal viciv_request_toggle : std_logic := '0';
  signal viciv_data_out : unsigned(7 downto 0) := x"00";
  signal viciv_data_strobe : std_logic := '0';

  -- SDRAM chip pins
  signal sdram_a : unsigned(SDRAM_ROW_WIDTH-1 downto 0);
  signal sdram_ba : unsigned(SDRAM_BANK_WIDTH-1 downto 0);
  signal sdram_dq : unsigned(SDRAM_DATA_WIDTH-1 downto 0);
  signal sdram_cke : std_logic;
  signal sdram_cs_n : std_logic;
  signal sdram_ras_n : std_logic;
  signal sdram_cas_n : std_logic;
  signal sdram_we_n : std_logic;
  signal sdram_dqml : std_logic;
  signal sdram_dqmh : std_logic;
  signal ack : std_logic;
  signal valid : std_logic;

  signal req : std_logic;
  signal reset : std_logic;

  signal enforce_100usec_init : boolean := false;
  signal init_sequence_done : std_logic;

  signal data_seen : std_logic := '0';
  signal data_val : unsigned(15 downto 0);

  signal cpu_game : std_logic := '1';
  signal cpu_exrom : std_logic := '1';
  signal sector_buffer_mapped : std_logic := '0';
  signal in_simulation : boolean := true;
  
begin

  sdram_model0: entity work.is42s16320f_model
  generic map (
    clock_frequency => 162_000_000
  )
  port map (
    clk => clock162,
    reset => reset,
    addr => sdram_a,
    ba => sdram_ba,
    dq => sdram_dq,
    clk_en => sdram_cke,
    cs => sdram_cs_n,
    ras => sdram_ras_n,
    cas => sdram_cas_n,
    we => sdram_we_n,
    ldqm => sdram_dqml,
    udqm => sdram_dqmh,
    enforce_100usec_init => enforce_100usec_init,
    init_sequence_done => init_sequence_done
  );

  slow0 : entity work.slow_devices
    port map (
    ------------------------------------------------------------------------
    -- CPU side interface
    ------------------------------------------------------------------------
    pixelclock => pixelclock,
    cpuclock => clock41,
    reset => reset,
    cpu_exrom => cpu_exrom,
    cpu_game => cpu_game,
    sector_buffer_mapped => sector_buffer_mapped,
    
    slow_access_request_toggle => slow_access_request_toggle,
    slow_access_ready_toggle => slow_access_ready_toggle,
    slow_access_write => slow_access_write,
    slow_access_address => slow_access_address,
    slow_access_wdata => slow_access_wdata,
    slow_access_rdata => slow_access_rdata,
    
    -- Fast read interface for slow devices linear reading
    -- (only hyperram)
    slow_prefetched_request_toggle => slow_prefetched_request_toggle,
    slow_prefetched_data => slow_prefetched_data,
    slow_prefetched_address => slow_prefetched_address,
    
    ------------------------------------------------------------------------
    -- Expansion RAM (upto 128MB)
    ------------------------------------------------------------------------
    expansionram_read => slow_read,
    expansionram_write => slow_write,
    expansionram_rdata => slow_rdata,
    expansionram_wdata => slow_wdata,
    expansionram_address => slow_address,
    expansionram_data_ready_strobe => slow_data_ready_strobe,
    expansionram_data_ready_toggle => slow_data_ready_toggle,
    expansionram_busy => slow_busy,
    
    -- Improve read speed by saving us from having to even enquire of
    -- the HyperRAM controller for the most recently accessed cache line.
    expansionram_current_cache_line => current_cache_line,
    expansionram_current_cache_line_address => current_cache_line_address,
    expansionram_current_cache_line_valid => current_cache_line_valid,
    expansionram_current_cache_line_next_toggle => expansionram_current_cache_line_next_toggle,
    
    cart_nmi => '1',
    cart_irq => '1',
    cart_dma => '1',
    
    cart_exrom => '1',
    cart_game => '1',
    
    cart_d_in => (others => '1')

      );

  
  sdram_controller0 : entity work.sdram_controller
    generic map (
        in_simulation => true
    )
    port map (
        pixelclock => pixelclock,
        clock162 => clock162,
        clock162r => not clock162,
        identical_clocks => '1',   -- Assumes SDRAM at 162MHz and thus requires
                                   -- one extra wait state on row read start.

        enforce_100us_delay => enforce_100usec_init,

        request_counter => open,
        read_request => slow_read,
        write_request => slow_write,
        address => slow_address,
        wdata => slow_wdata,
        wdata_hi => slow_wdata_hi,
        wen_hi => slow_wen_hi,
        wen_lo => slow_wen_lo,
        rdata_hi => slow_rdata_hi,
        rdata_16en => slow_rdata_16en,
        rdata => slow_rdata,
        data_ready_toggle => slow_data_ready_toggle,
        busy => slow_busy,
        current_cache_line => current_cache_line,
        current_cache_line_address => current_cache_line_address,
        current_cache_line_valid => current_cache_line_valid,
        expansionram_current_cache_line_next_toggle => expansionram_current_cache_line_next_toggle,
        expansionram_current_cache_line_prev_toggle => expansionram_current_cache_line_prev_toggle,
        viciv_addr => viciv_addr,
        viciv_request_toggle => viciv_request_toggle,
        viciv_data_out => viciv_data_out,
        viciv_data_strobe => viciv_data_strobe,

        sdram_a => sdram_a,
        sdram_ba => sdram_ba,
        sdram_dq => sdram_dq,
        sdram_cke => sdram_cke,
        sdram_cs_n => sdram_cs_n,
        sdram_ras_n => sdram_ras_n,
        sdram_cas_n => sdram_cas_n,
        sdram_we_n => sdram_we_n,
        sdram_dqml => sdram_dqml,
        sdram_dqmh => sdram_dqmh

    );


  main : process

    variable v : unsigned(15 downto 0);

    procedure clock_tick is
    begin
      clock162 <= not clock162;
      if clock162 = '1' then
        pixelclock <= not pixelclock;
        if pixelclock='1' then
          clock41 <= not clock41;
        end if;
      end if;
      wait for 6.173 ns;
      -- report "SDRAMDQ: sdram_dq = $" & to_hexstring(sdram_dq);

    end procedure;

    procedure wait_for_sdram_ready is
    begin
      clock_tick;
      for i in 1 to 1000 loop
        clock_tick;
        if init_sequence_done='1' then
          report "SDRAM ready after " & integer'image(i) & " cycles.";
          -- Now allow some more cycles for the SDRAM to do any initial reads
          -- etc it wants
          for i in 1 to 50 loop
            clock_tick;
          end loop;
          report "SDRAM: Ready or not, here we come!";
          return;
        end if;
      end loop;
      assert false report "SDRAM did not become ready";
    end procedure;

    
    procedure slowdev_write( addr : integer; val : unsigned(7 downto 0)) is
    begin
      report "SLOWWRITE: $" & to_hexstring(to_unsigned(addr,28)) & " <- $" & to_hexstring(val);
      slow_access_write <= '1';
      slow_access_address <= to_unsigned(addr,28);
      slow_access_address(27) <= '1'; -- force access into expansion RAM area
      slow_access_wdata <= val;
      slow_access_request_toggle <= not slow_access_request_toggle;
      desired_slow_access_ready_toggle <= not slow_access_ready_toggle;
      for i in 1 to 100 loop
        clock_tick;
        if slow_access_ready_toggle = desired_slow_access_ready_toggle then
          slow_access_write <= '0';
          -- Now make sure no further toggles occur on the access ready toggle
          -- after
          for i in 1 to 20 loop
            clock_tick;
            if slow_access_ready_toggle /= desired_slow_access_ready_toggle then
              assert false report "SLOWREADYTOGGLE: slow_access_ready_toggle toggled again after completion of write";
            end if;
          end loop;
          return;
        end if;
      end loop;

      assert false report "SLOWWRITE: Write timed out after 100 cycles";

    end procedure;

    procedure slowdev_read( addr : integer; expected_val : unsigned(7 downto 0); post_wait : boolean) is
    begin

      slow_access_write <= '0';
      slow_access_address <= to_unsigned(addr,28);
      slow_access_address(27) <= '1'; -- force access into expansion RAM area
      slow_access_request_toggle <= not slow_access_request_toggle;
      desired_slow_access_ready_toggle <= not slow_access_ready_toggle;
      report "SLOWREADTOGGLE: slow_access_ready_toggle = " & std_logic'image(slow_access_ready_toggle);

      report "SLOWREAD: $" & to_hexstring(to_unsigned(addr,28)) & " (looking for $" & to_hexstring(expected_val) & ").";

      for i in 1 to 100 loop
        clock_tick;
        if slow_access_ready_toggle = desired_slow_access_ready_toggle then
          report "SLOWREADTOGGLE: slow_access_ready_toggle = " & std_logic'image(slow_access_ready_toggle);
          if slow_access_rdata /= expected_val then
            assert false report "SLOWREAD: Read $" & to_hexstring(data_val) & ", but expected $" & to_hexstring(expected_val);
          else
            report "SLOWREAD: Read correct value.";
            if post_wait then
              -- Now make sure no further toggles occur on the access ready toggle
              -- after
              for i in 1 to 20 loop
                clock_tick;
                if slow_access_ready_toggle /= desired_slow_access_ready_toggle then
                  assert false report "SLOWREADYTOGGLE: slow_access_ready_toggle toggled again after completion of write";
                end if;
              end loop;
            end if;
          end if;          
          return;
        end if;
      end loop;
      assert false report "SLOWREAD: Failed to read value after 100 cycles.";
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop

      if run("Write and read back single bytes") then
        wait_for_sdram_ready;
        slowdev_write(0,x"12");
        slowdev_write(1,x"34");
        slowdev_write(2,x"56");
        slowdev_write(3,x"78");
        slowdev_write(4,x"9a");
        slowdev_write(5,x"bc");
        slowdev_write(6,x"de");
        slowdev_write(7,x"f0");
        slowdev_read(0,x"12",false);
        slowdev_read(1,x"34",false);
        slowdev_read(2,x"56",true);
        slowdev_read(3,x"78",true);
        slowdev_read(4,x"9a",true);
        slowdev_read(5,x"bc",true);
      elsif run("Write and read back single bytes from different cache lines") then
        wait_for_sdram_ready;
        slowdev_write(0,x"12");
        slowdev_write(101,x"34");
        slowdev_write(202,x"56");
        slowdev_write(303,x"78");
        slowdev_write(404,x"9a");
        slowdev_write(505,x"bc");
        slowdev_write(606,x"de");
        slowdev_write(707,x"f0");
        slowdev_read(0,x"12",false);
        slowdev_read(101,x"34",false);
        slowdev_read(202,x"56",true);
        slowdev_read(303,x"78",true);
        slowdev_read(404,x"9a",true);
        slowdev_read(505,x"bc",true);

      end if;
    end loop;
    test_runner_cleanup(runner);
  end process;

end architecture;
