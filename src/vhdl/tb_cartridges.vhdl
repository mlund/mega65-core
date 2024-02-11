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


  signal saw_signal : std_logic := '0';
  signal last_cart_access_read_toggle : std_logic := '0';

  signal cm_last_phi2 : std_logic := '0';
  
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

    procedure model_64k_cart is
    begin
      cm_last_phi2 <= cart_phi2;
      if cm_last_phi2='0' and cart_phi2='1' then
        if cart_rw='1' then
          report "CART64K: PHI2 rising edge: READ $" & to_hexstring(cart_a);
          if cart_roml='0' then
            cart_d <= cart_a(7 downto 0);
          else
            cart_d <= (others => 'Z');
          end if;            
        else
          report "CART64K: PHI2 rising edge: WRITE $" & to_hexstring(cart_a) & " <- $" & to_hexstring(cart_d_in);
          cart_d <= (others => 'Z');
        end if;          
      end if;
      
    end procedure;    
      
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

      -- And model a simple 64KB cartridge
      model_64k_cart;
      
    end procedure;

    procedure expansion_port_init  is
    begin
      -- Allow enough time for reset counter to go to zero
      -- in expansion_port_controller, and then for it do do
      -- the simulated C64 reset sequence
      for i in 1 to 1400 loop
        clock_tick;
      end loop;

      if cart_ctrl_dir /= '1' then
        assert false report "cart_ctrl_dir=" & std_logic'image(cart_ctrl_dir) & " instead of 1.";
      end if;
      if cart_ctrl_en /= '0' then
        assert false report "cart_ctrl_en=" & std_logic'image(cart_ctrl_en) & " instead of 0.";
      end if;
    
    end procedure;

    procedure request_cart_read(addr : unsigned(31 downto 0)) is
    begin

      report "request_cart_read($" & to_hexstring(addr)& ") called";
      
      -- Don't send request until request accept strobe has cleared
      for i in 1 to 100 loop
        if cart_access_accept_strobe = '0' then
          report "cart_access_accept_strobe low: Request can proceed";
          exit;
        else
          clock_tick;
        end if;
      end loop;
      if cart_access_accept_strobe = '1' then
        assert false report "cart_access_accept_strobe did not clear within 6.1 usec";
      end if;

      -- Build request
      cart_access_request <= '1';
      cart_access_read <= '1';
      cart_access_address <= addr;

      -- Wait for request to be accepted
      for i in 1 to 1000 loop
        if cart_access_accept_strobe = '1' then
          exit;
        else
          clock_tick;
        end if;
      end loop;
      if cart_access_accept_strobe = '0' then
        assert false report "cart_access_accept_strobe did not assert within 6.1 usec";
      end if;

      -- Now release request signal
      cart_access_request <= '0';      
          
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

      elsif run("/ROML, /ROMH, /IO1 and /IO2 are high by default") then
        for i in 1 to 1000 loop
          clock_tick;
          if cart_roml='0' then
            assert false report "Expected to see /ROML stay high, but it was low";
          end if;
          if cart_romh='0' then
            assert false report "Expected to see /ROMH stay high, but it was low";
          end if;
          if cart_io1='0' then
            assert false report "Expected to see /IO1 stay high, but it was low";
          end if;
          if cart_io2='0' then
            assert false report "Expected to see /IO2 stay high, but it was low";
          end if;
        end loop;
      elsif run("Expansion port controller signals busy during requests") then
        expansion_port_init;
        request_cart_read(to_unsigned(0,32));
        if cart_busy='0' then
          assert false report "cart_busy did not go high to indicate busy status";
        end if;
      elsif run("/ROML is pulled low when accessing $8000-$9FFF") then
        expansion_port_init;
        for addr in 16#8000# to 16#9fff# loop
          request_cart_read(to_unsigned(addr,32));
          saw_signal <= '0';
          -- Each clock_tick is 1/2 a pixelclock tick. This means we need
          -- at least 2x pixelclock (in Mhz) ticks for a single cart port
          -- transaction to happen. But we might be part way through a 1MHz
          -- cycle at that point, so should allow double again, i.e.,
          -- 81MHz x 4 = 324 cycles
          for i in 1 to 324 loop
            if cart_roml = '0' and saw_signal='0' then
              report "Saw /ROML go low after " & integer'image(i) & " half-ticks.";
              saw_signal <= '1';
            end if;
            if cart_romh = '0' or cart_io1 = '0' or cart_io2 = '0' then
              assert false report "Saw unexpected activity for address $" & to_hexstring(to_unsigned(addr,32))
                & ": /ROML=" & std_logic'image(cart_roml)
                & ", /ROMH=" & std_logic'image(cart_romh)
                & ", /IO1=" & std_logic'image(cart_io1)
                & ", /IO2=" & std_logic'image(cart_io2);
            end if;
            if last_cart_access_read_toggle /= cart_access_read_toggle then
              last_cart_access_read_toggle <= cart_access_read_toggle;
              report "cart_access_read_toggle changed from " & std_logic'image(last_cart_access_read_toggle)
                & " to " & std_logic'image(cart_access_read_toggle)
                & " after " & integer'image(i) & " ticks.";
              exit;
            else
              clock_tick;
            end if;
          end loop;
          if saw_signal='0' then
            assert false report "/ROML did not go low when accessing address $" & to_hexstring(to_unsigned(addr,32));
          end if;
            
        end loop;    
      elsif run("/ROMH is pulled low when accessing $A000-$BFFF") then
        expansion_port_init;
        for addr in 16#a000# to 16#bfff# loop
          request_cart_read(to_unsigned(addr,32));
          saw_signal <= '0';
          -- Each clock_tick is 1/2 a pixelclock tick. This means we need
          -- at least 2x pixelclock (in Mhz) ticks for a single cart port
          -- transaction to happen. But we might be part way through a 1MHz
          -- cycle at that point, so should allow double again, i.e.,
          -- 81MHz x 4 = 324 cycles
          for i in 1 to 324 loop
            if cart_romh = '0' and saw_signal='0' then
              report "Saw /ROMH go low after " & integer'image(i) & " half-ticks.";
              saw_signal <= '1';
            end if;
            if cart_roml = '0' or cart_io1 = '0' or cart_io2 = '0' then
              assert false report "Saw unexpected activity for address $" & to_hexstring(to_unsigned(addr,32))
                & ": /ROML=" & std_logic'image(cart_roml)
                & ", /ROMH=" & std_logic'image(cart_romh)
                & ", /IO1=" & std_logic'image(cart_io1)
                & ", /IO2=" & std_logic'image(cart_io2);
            end if;
            if last_cart_access_read_toggle /= cart_access_read_toggle then
              last_cart_access_read_toggle <= cart_access_read_toggle;
              report "cart_access_read_toggle changed from " & std_logic'image(last_cart_access_read_toggle)
                & " to " & std_logic'image(cart_access_read_toggle)
                & " after " & integer'image(i) & " ticks.";
              exit;
            else
              clock_tick;
            end if;
          end loop;
          if saw_signal='0' then
            assert false report "/ROMH did not go low when accessing address $" & to_hexstring(to_unsigned(addr,32));
          end if;
            
        end loop;    
      elsif run("/IO1 is pulled low when accessing $DE00-$DEFF") then
        expansion_port_init;
        for addr in 16#de00# to 16#deff# loop
          request_cart_read(to_unsigned(addr,32));
          saw_signal <= '0';
          -- Each clock_tick is 1/2 a pixelclock tick. This means we need
          -- at least 2x pixelclock (in Mhz) ticks for a single cart port
          -- transaction to happen. But we might be part way through a 1MHz
          -- cycle at that point, so should allow double again, i.e.,
          -- 81MHz x 4 = 324 cycles
          for i in 1 to 324 loop

            -- Make sure that data direction and output enable for /IO1 are set
            -- correctly
            if cart_ctrl_dir /= '1' then
              assert false report "cart_ctrl_dir=" & std_logic'image(cart_ctrl_dir) & " instead of 1.";
            end if;
            if cart_ctrl_en /= '0' then
              assert false report "cart_ctrl_en=" & std_logic'image(cart_ctrl_en) & " instead of 0.";
            end if;
            
            if cart_io1 = '0' and saw_signal='0' then
              report "Saw /IO1 go low after " & integer'image(i) & " half-ticks.";
              saw_signal <= '1';
            end if;
            if cart_roml = '0' or cart_romh = '0' or cart_io2 = '0' then
              assert false report "Saw unexpected activity for address $" & to_hexstring(to_unsigned(addr,32))
                & ": /ROML=" & std_logic'image(cart_roml)
                & ", /ROMH=" & std_logic'image(cart_romh)
                & ", /IO1=" & std_logic'image(cart_io1)
                & ", /IO2=" & std_logic'image(cart_io2);
            end if;
            if last_cart_access_read_toggle /= cart_access_read_toggle then
              last_cart_access_read_toggle <= cart_access_read_toggle;
              report "cart_access_read_toggle changed from " & std_logic'image(last_cart_access_read_toggle)
                & " to " & std_logic'image(cart_access_read_toggle)
                & " after " & integer'image(i) & " ticks.";
              exit;
            else
              clock_tick;
            end if;
          end loop;
          if saw_signal='0' then
            assert false report "/IO1 did not go low when accessing address $" & to_hexstring(to_unsigned(addr,32));
          end if;
            
        end loop;    
      elsif run("/IO2 is pulled low when accessing $DE00-$DEFF") then
        expansion_port_init;
        for addr in 16#df00# to 16#dfff# loop
          request_cart_read(to_unsigned(addr,32));
          saw_signal <= '0';
          -- Each clock_tick is 1/2 a pixelclock tick. This means we need
          -- at least 2x pixelclock (in Mhz) ticks for a single cart port
          -- transaction to happen. But we might be part way through a 1MHz
          -- cycle at that point, so should allow double again, i.e.,
          -- 81MHz x 4 = 324 cycles
          for i in 1 to 324 loop

            -- Make sure that data direction and output enable for /IO1 are set
            -- correctly
            if cart_ctrl_dir /= '1' then
              assert false report "cart_ctrl_dir=" & std_logic'image(cart_ctrl_dir) & " instead of 1.";
            end if;
            if cart_ctrl_en /= '0' then
              assert false report "cart_ctrl_en=" & std_logic'image(cart_ctrl_en) & " instead of 0.";
            end if;            
            
            if cart_io2 = '0' and saw_signal='0' then
              report "Saw /IO2 go low after " & integer'image(i) & " half-ticks.";
              saw_signal <= '1';
            end if;
            if cart_roml = '0' or cart_romh = '0' or cart_io1 = '0' then
              assert false report "Saw unexpected activity for address $" & to_hexstring(to_unsigned(addr,32))
                & ": /ROML=" & std_logic'image(cart_roml)
                & ", /ROMH=" & std_logic'image(cart_romh)
                & ", /IO1=" & std_logic'image(cart_io1)
                & ", /IO2=" & std_logic'image(cart_io2);
            end if;
            if last_cart_access_read_toggle /= cart_access_read_toggle then
              last_cart_access_read_toggle <= cart_access_read_toggle;
              report "cart_access_read_toggle changed from " & std_logic'image(last_cart_access_read_toggle)
                & " to " & std_logic'image(cart_access_read_toggle)
                & " after " & integer'image(i) & " ticks.";
              exit;
            else
              clock_tick;
            end if;
          end loop;
          if saw_signal='0' then
            assert false report "/IO2 did not go low when accessing address $" & to_hexstring(to_unsigned(addr,32));
          end if;
            
        end loop;    
            
      elsif run("Reading ROML region reads correct values") then
        expansion_port_init;
        for addr in 16#8000# to 16#9fff# loop
          request_cart_read(to_unsigned(addr,32));
          saw_signal <= '0';
          -- Each clock_tick is 1/2 a pixelclock tick. This means we need
          -- at least 2x pixelclock (in Mhz) ticks for a single cart port
          -- transaction to happen. But we might be part way through a 1MHz
          -- cycle at that point, so should allow double again, i.e.,
          -- 81MHz x 4 = 324 cycles
          for i in 1 to 324 loop
            if cart_roml = '0' and saw_signal='0' then
              report "Saw /ROML go low after " & integer'image(i) & " half-ticks.";
              saw_signal <= '1';
            end if;
            if cart_romh = '0' or cart_io1 = '0' or cart_io2 = '0' then
              assert false report "Saw unexpected activity for address $" & to_hexstring(to_unsigned(addr,32))
                & ": /ROML=" & std_logic'image(cart_roml)
                & ", /ROMH=" & std_logic'image(cart_romh)
                & ", /IO1=" & std_logic'image(cart_io1)
                & ", /IO2=" & std_logic'image(cart_io2);
            end if;
            if last_cart_access_read_toggle /= cart_access_read_toggle then
              last_cart_access_read_toggle <= cart_access_read_toggle;
              report "cart_access_read_toggle changed from " & std_logic'image(last_cart_access_read_toggle)
                & " to " & std_logic'image(cart_access_read_toggle)
                & " after " & integer'image(i) & " ticks.";
              exit;
            else
              clock_tick;
            end if;
          end loop;          
          if saw_signal='0' then
            assert false report "/ROML did not go low when accessing address $" & to_hexstring(to_unsigned(addr,32));
          end if;

          report "Reading $" & to_hexstring(to_unsigned(addr,32)) & ". Value read = $" & to_hexstring(cart_d)
            & " (" & to_01UXstring(std_logic_vector(cart_d)) & ").";
          
          if cart_d /= to_unsigned(addr,8) then
            assert false report "Expected to read $" & to_hexstring(to_unsigned(addr,8));
          end if;
            
        end loop;    
      end if;
    end loop;
    test_runner_cleanup(runner);
  end process;

end architecture;
