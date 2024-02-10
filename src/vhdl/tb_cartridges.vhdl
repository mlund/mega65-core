library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use Std.TextIO.all;
use work.debugtools.all;
use work.cputypes.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity tb_cartridges is
  generic (runner_cfg : string);
end entity;

architecture test_arch of tb_cartridges is

  signal pixelclock : std_logic := '0';
  signal clock41 : std_logic := '0';
  
    ------------------------------------------------------------------------
    -- CPU side interface
    ------------------------------------------------------------------------
  signal reset : std_logic := '1';

    
    ------------------------------------------------------------------------
    -- Let cartridge try to do things
    ------------------------------------------------------------------------    
  signal nmi_out : std_logic;
  signal irq_out : std_logic;
  signal dma_out : std_logic;
    
    ------------------------------------------------------------------------
    -- Tell the CPU what the current cartridge state is
    ------------------------------------------------------------------------    
  signal cpu_exrom : std_logic;
  signal cpu_game : std_logic;

    ------------------------------------------------------------------------
    -- Expansion port can host special simplified 4-port joystick adapter
    ------------------------------------------------------------------------
  signal joya : std_logic_vector(4 downto 0);
  signal joyb : std_logic_vector(4 downto 0);
    
    ------------------------------------------------------------------------
    -- Suppress mapping of IO at $DE00-$DFFF if sector buffer mapped
    ------------------------------------------------------------------------
  signal sector_buffer_mapped : std_logic;

  signal cart_busy : std_logic;
  signal cart_access_count : unsigned(7 downto 0);
    
    ------------------------------------------------------------------------
    -- Access request from CPU
    ------------------------------------------------------------------------
    -- CPU asserts cart_access_request with _read flag, and _address and
    -- _wdata set as appropriate.  Interface indicates acceptance of job by
    -- asserting _accept_strobe for one pixelclock tick only.
  signal cart_access_request : std_logic;
  signal cart_access_read : std_logic;
  signal cart_access_address : unsigned(31 downto 0);
  signal cart_access_wdata : unsigned(7 downto 0);
  signal cart_access_accept_strobe : std_logic;
  signal cart_access_read_toggle: std_logic;
    
    ------------------------------------------------------------------------
    -- Strobe indicates when we have read data in response to a request
    ------------------------------------------------------------------------
    -- Strobe lasts one pixelclock tick only.
  signal cart_access_read_strobe : std_logic;
  signal cart_access_rdata : unsigned(7 downto 0);

    ------------------------------------------------------------------------
    -- Expansion port pins
    ------------------------------------------------------------------------
  signal cart_ctrl_dir : std_logic;
  signal cart_ctrl_en : std_logic;
  signal cart_haddr_dir : std_logic;
  signal cart_laddr_dir : std_logic;
  signal cart_addr_en : std_logic;

    -- These signals have inverted sense
  signal cart_data_dir : std_logic;
  signal cart_data_en : std_logic;

  signal cart_phi2 : std_logic;
  signal cart_dotclock : std_logic;
  signal cart_reset : std_logic;

  signal last_cart_phi2 : std_logic := '0';
  signal last_cart_dotclock : std_logic := '0';
  signal cart_phi2_ticks : integer := 0;
  signal cart_dotclock_ticks : integer := 0;


  -- Signals on the expansion port
  signal cart_nmi : std_logic := '1';
  signal cart_irq : std_logic := '1';
  signal cart_dma : std_logic := '1';
    
  signal cart_exrom : std_logic := '1';
  signal cart_ba : std_logic;
  signal cart_rw : std_logic;
  signal cart_roml : std_logic;
  signal cart_romh : std_logic;
  signal cart_io1 : std_logic;
  signal cart_game : std_logic := '1';
  signal cart_io2 : std_logic;
    
  signal cart_d_in : unsigned(7 downto 0);
  signal cart_d : unsigned(7 downto 0);
  signal cart_a : unsigned(15 downto 0);

  
begin

  expport0: entity work.expansion_port_controller
    generic map (
      pixelclock_frequency => 81_000_000,
      target => mega65r6
      )
    port map (
      pixelclock => pixelclock,
      cpuclock => clock41,
      reset => reset,

      nmi_out => nmi_out,
      irq_out => irq_out,
      dma_out => dma_out,

      cpu_exrom => cpu_exrom,
      cpu_game => cpu_game,

      joya => joya,
      joyb => joyb,

      sector_buffer_mapped => sector_buffer_mapped,

      cart_busy => cart_busy,
      cart_access_count => cart_access_count,

      cart_access_request => cart_access_request,
      cart_access_read => cart_access_read,
      cart_access_address => cart_access_address,
      cart_access_wdata => cart_access_wdata,
      cart_access_accept_strobe => cart_access_accept_strobe,
      cart_access_read_toggle => cart_access_read_toggle,

      cart_access_read_strobe => cart_access_read_strobe,
      cart_access_rdata => cart_access_rdata,

      cart_ctrl_dir => cart_ctrl_dir,
      cart_ctrl_en => cart_ctrl_en,
      cart_haddr_dir => cart_haddr_dir,
      cart_laddr_dir => cart_laddr_dir,
      cart_addr_en => cart_addr_en,

      cart_data_dir => cart_data_dir,
      cart_data_en => cart_data_en,
      
      cart_phi2 => cart_phi2,
      cart_dotclock => cart_dotclock,
      cart_reset => cart_reset,

      cart_nmi => cart_nmi,
      cart_irq => cart_irq,
      cart_dma => cart_dma,

      cart_exrom => cart_exrom,
      cart_ba => cart_ba,
      cart_rw => cart_rw,
      cart_roml => cart_roml,
      cart_romh => cart_romh,
      cart_io1 => cart_io1,
      cart_game => cart_game,
      cart_io2 => cart_io2,

      cart_d_in => cart_d_in,
      cart_d => cart_d,
      cart_a => cart_a
      );
      
      
  main : process

    variable v : unsigned(15 downto 0);

    procedure clock_tick is
    begin
      pixelclock <= not pixelclock;
      if pixelclock='1' then
        clock41 <= not clock41;
      end if;
      wait for 6.173 ns;

      -- Watch for edges on cartridge clock lines
      if last_cart_phi2 = '0' and cart_phi2='1' then
        cart_phi2_ticks <= cart_phi2_ticks + 1;
      end if;
      last_cart_phi2 <= cart_phi2;

      if last_cart_dotclock = '0' and cart_dotclock='1' then
        cart_dotclock_ticks <= cart_dotclock_ticks + 1;
      end if;
      last_cart_dotclock <= cart_dotclock;
      
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop

      if run("Expansion port PHI2 ticks at ~1MHz") then
        -- Run for 10000 x 6.173 ns = 61730 ns = 61 -- 62 usec
        for i in 1 to 10000 loop
          clock_tick;
        end loop;
        report integer'image(cart_phi2_ticks) & " PHI2 ticks observed";
        if cart_phi2_ticks < 61 or cart_phi2_ticks > 62 then
          assert false report "Expected to see 61 or 62 PHI2 ticks in 61,730ns time-frame";
        end if;
      elsif run("Expansion port DOTCLOCK ticks at ~8MHz") then
        -- Run for 10000 x 6.173 ns = 61730 ns = 488 -- 496 8MHz ticks
        for i in 1 to 10000 loop
          clock_tick;
        end loop;
        report integer'image(cart_dotclock_ticks) & " DOTCLOCK ticks observed";
        if cart_dotclock_ticks < 488 or cart_dotclock_ticks > 496 then
          assert false report "Expected to see 488 to 496 DOTCLOCK ticks in 61,730ns time-frame";
        end if;
        
      end if;
    end loop;
    test_runner_cleanup(runner);
  end process;

end architecture;
