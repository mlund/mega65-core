-- XXX - Currently supports only accessing first 64KB of expansion port address
-- space, and does not set select lines based on address.

use WORK.ALL;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use Std.TextIO.all;
use work.debugtools.all;
use work.cputypes.all;

ENTITY expansion_port_controller IS
  generic (
    pixelclock_frequency : in integer;
    target : mega65_target_t
    );
  PORT (
    ------------------------------------------------------------------------
    -- CPU side interface
    ------------------------------------------------------------------------
    pixelclock : in std_logic;
    cpuclock : in std_logic;
    reset : in std_logic;

    
    ------------------------------------------------------------------------
    -- Let cartridge try to do things
    ------------------------------------------------------------------------    
    nmi_out : out std_logic;
    irq_out : out std_logic;
    dma_out : out std_logic;
    
    ------------------------------------------------------------------------
    -- Tell the CPU what the current cartridge state is
    ------------------------------------------------------------------------    
    cpu_exrom : out std_logic := '1';
    cpu_game : out std_logic := '1';

    ------------------------------------------------------------------------
    -- Expansion port can host special simplified 4-port joystick adapter
    ------------------------------------------------------------------------
    joya : out std_logic_vector(4 downto 0) := "11111";
    joyb : out std_logic_vector(4 downto 0) := "11111";
    
    cart_busy : out std_logic := '0';
    cart_access_count : out unsigned(7 downto 0);
    
    ------------------------------------------------------------------------
    -- Access request from CPU
    ------------------------------------------------------------------------
    -- CPU asserts cart_access_request with _read flag, and _address and
    -- _wdata set as appropriate.  Interface indicates acceptance of job by
    -- asserting _accept_strobe for one pixelclock tick only.
    cart_access_request : in std_logic;
    cart_access_read : in std_logic;
    cart_access_address : in unsigned(31 downto 0);
    cart_access_wdata : in unsigned(7 downto 0);
    cart_access_accept_strobe : out std_logic;
    cart_access_read_toggle: out std_logic := '0';
    
    ------------------------------------------------------------------------
    -- Strobe indicates when we have read data in response to a request
    ------------------------------------------------------------------------
    -- Strobe lasts one pixelclock tick only.
    cart_access_read_strobe : out std_logic := '0';
    cart_access_rdata : out unsigned(7 downto 0) := x"FF";

    ------------------------------------------------------------------------
    -- Expansion port pins
    ------------------------------------------------------------------------
    cart_ctrl_dir : out std_logic := '1';
    cart_ctrl_en : out std_logic := '0'; -- required for R4/R5/R6
    cart_haddr_dir : out std_logic := '1';
    cart_laddr_dir : out std_logic := '1';
    cart_addr_en : out std_logic := '0';

    -- These signals have inverted sense
    cart_data_dir : out std_logic := '0';
    cart_data_en : out std_logic := '0';

    cart_phi2 : out std_logic;
    cart_dotclock : out std_logic;
    cart_reset : out std_logic := '1';

    cart_nmi : in std_logic;
    cart_irq : in std_logic;
    cart_dma : in std_logic;
    
    cart_exrom : in std_logic;
    cart_ba : inout std_logic := 'H';
    cart_rw : inout std_logic := 'H';
    cart_roml : inout std_logic := 'H';
    cart_romh : inout std_logic := 'H';
    cart_io1 : inout std_logic := 'H';
    cart_game : in std_logic;
    cart_io2 : inout std_logic := 'H';
    
    cart_d_in : in unsigned(7 downto 0);
    cart_d : out unsigned(7 downto 0);
    cart_a : inout unsigned(15 downto 0)
);
end expansion_port_controller;

architecture behavioural of expansion_port_controller is

  signal not_joystick_cartridge : std_logic := '0';
  signal disable_joystick_cartridge : std_logic := '1';
  signal force_joystick_cartridge : std_logic := '0';
  signal joy_read_toggle : std_logic := '0';
  signal invert_joystick : std_logic := '0';
  signal joy_counter : integer range 0 to 50 := 0;
  
  -- XXX - Allow varying the bus speed if we know we have a fast
  -- peripheral.
  -- But first, we just need this to work properly.
  -- The old calculation was 1M / pixelclock_frequency, which was 1/81,
  -- i.e., 0.
  -- What we really want to know is the ratio of the 8MHz pixel clock
  -- to the pixel clock, so that we know what fraction of the accumulator
  -- to add each pixelclock cycle.  We need two edges per dotclock cycle
  -- so we need two events per 8MHz cycle.
  -- Because the cartridge port on the MEGA65 is not closely coupled to
  -- the VIC-IV, we don't have to be too precise here: Just make sure that
  -- it is at least 8x NTSC C64 speed, so that it can service a 1MHz C64
  -- cartridge-based program, and not so fast that it causes problems.
  -- For the normal case, we have 81MHz pixelclock, and we want 8MHz out,
  -- we should be dividing by about 5 to get the 16 edges per micro-second
  -- that we need (remember two edges per clock cycle, thus 16/2 = 8 MHz,
  -- which is what we want).
  -- Thus we want (pixelclock in MHz)/4 x 2^16 to get the fraction of 2^16 to add to
  -- a 16-bit counter that we want to overflow whenever a new clock edge should
  -- occur.  But that requires >32 bits during the calculation.
  constant pixelclock_mhz : real := Real(pixelclock_frequency) / 1_000_000.0;
  constant dotclock_increment_real : real := 65536.0/(pixelclock_mhz/(8.0*2.0));
  constant dotclock_increment : unsigned(16 downto 0) := to_unsigned(Integer(dotclock_increment_real),17);

  signal ticker : unsigned(16 downto 0) := to_unsigned(0,17);
  signal phi2_ticker : unsigned(7 downto 0) := to_unsigned(0,8);
  signal reset_counter : integer range 0 to 15 := 0;

  -- Are we already servicing a read?
  signal read_in_progress : std_logic := '0';
  signal cart_access_read_toggle_internal : std_logic := '0';
  signal cart_access_count_internal : unsigned(7 downto 0) := x"00";
  
  -- Internal state
  signal cart_dotclock_internal : std_logic := '0';
  signal cart_phi2_internal : std_logic := '0';

  signal cart_flags : std_logic_vector(1 downto 0) := "00";

  signal cart_force_reset : std_logic := '0';

  signal fake_reset_sequence_phase : integer range 0 to 10 := 0;

  signal nmi_count : unsigned(7 downto 0) := x"00";
  signal irq_count : unsigned(7 downto 0) := x"00";
  signal dma_count : unsigned(7 downto 0) := x"00";
  signal exrom_count : unsigned(7 downto 0) := x"00";
  signal game_count : unsigned(7 downto 0) := x"00";

  signal last_cart_irq : std_logic := '1';
  signal last_cart_nmi : std_logic := '1';
  signal last_cart_dma : std_logic := '1';
  signal last_cart_exrom : std_logic := '1';
  signal last_cart_game : std_logic := '1';

  signal oride_enable : std_logic := '0';
  signal oride_ctrl_en : std_logic := '0';
  signal oride_ctrl_dir : std_logic := '0';
  signal oride_io1 : std_logic := '0';
  signal oride_io2 : std_logic := '0';
  signal oride_romh : std_logic := '0';
  signal oride_roml: std_logic := '0';

  signal next_rw : std_logic := '1';
  signal next_io1 : std_logic := '1';
  signal next_io2 : std_logic := '1';
  signal next_data_dir : std_logic := '1';
  signal next_data_en : std_logic := '1';
  signal next_d : unsigned(7 downto 0) := x"ff";
  signal next_ctrl_dir : std_logic := '1';

  signal cart_reset_int : std_logic := '1';
  
begin

  process (pixelclock)
  begin
    if rising_edge(pixelclock) then

      ----------------------------------------------------------------------
      -- Allow cartridges to cause interrupts or DMA
      ----------------------------------------------------------------------      
      -- (note DMA is not really implemented)
      
      nmi_out <= cart_nmi;
      irq_out <= cart_irq;
      dma_out <= cart_dma;
      
      last_cart_nmi <= cart_nmi;
      last_cart_irq <= cart_irq;
      last_cart_dma <= cart_dma;
      last_cart_exrom <= cart_exrom;
      last_cart_game <= cart_game;
      
      if cart_nmi = '0' and last_cart_nmi = '1' then
        nmi_count <= nmi_count + 1;
      end if;
      if cart_irq = '0' and last_cart_irq = '1' then
        irq_count <= irq_count + 1;
      end if;
      if cart_dma = '0' and last_cart_dma = '1' then
        dma_count <= dma_count + 1;
      end if;
      if cart_exrom = '0' and last_cart_exrom = '1' then
        exrom_count <= exrom_count + 1;
      end if;
      if cart_game = '0' and last_cart_game = '1' then
        game_count <= game_count + 1;
      end if;
      
      
      ----------------------------------------------------------------------
      -- Support for simple passive cartridge with 3rd and 4th joystick ports
      ----------------------------------------------------------------------      

      -- If DMA line is ever high, then it is not the joystick cartridge.
      -- Put another way: The joystick cartridge works by tying DMA to GND.
      if cart_dma='1' then
        not_joystick_cartridge <= '1';
      end if;

      if (not_joystick_cartridge = '0' or force_joystick_cartridge='1') and (disable_joystick_cartridge='0') then
        -- Set data lines to input
        next_data_en <= '0'; -- negative sense on these lines: low = enable
        cart_addr_en <= '0'; -- negative sense on these lines: low = enable
        cart_a <= (others => 'Z');

        -- Pull /RESET low on cartridge port, so that it can be the source of
        -- GND for the joysticks.  Without this, the joysticks will effectively
        -- be unpowered. We just have to take care that the joysticks don't
        -- draw more power than /RESET can sink.  This might be a problem for joysticks
        -- with auto-fire (like many on the market) or lights (like the ones I built at
        -- home). 
        cart_reset <= '0';
        cart_reset_int <= '0';
        
        if joy_counter = 50 then
          joy_counter <= 0;
          joy_read_toggle <= not joy_read_toggle;
        else
          joy_counter <= joy_counter + 1;
        end if;

        if joy_counter = 0 then
          if invert_joystick='0' then
            if cart_d_in(4 downto 0) /= "00000" then
              joya <= std_logic_vector(cart_d_in(4 downto 0));
            else
              joya <= "11111";
            end if;
            if cart_a(4 downto 0) /= "00000" then
              joyb <= std_logic_vector(cart_a(4 downto 0));
            else
              joyb <= "11111";
            end if;
          else
            if cart_d_in(4 downto 0) /= "11111" then
              joya <= std_logic_vector(cart_d_in(4 downto 0)) xor "11111";
            else
              joya <= "11111";
            end if;
            if cart_a(4 downto 0) /= "11111" then
              joyb <= std_logic_vector(cart_a(4 downto 0)) xor "11111";
            else
              joyb <= "11111";
            end if;
          end if;
          next_d <= (others => 'Z');
          next_data_dir <= '1';
          cart_laddr_dir <= '1';
          next_d(7 downto 0) <= (others => '1');
          cart_a(7 downto 0) <= (others => '1');
        end if;
        if joy_counter = 5 then
          -- Tristate lines to allow time for them to be pulled low again if
          -- required
          next_data_dir <= '0';
          next_d <= (others => 'Z');
          cart_laddr_dir <= '0';
          cart_a(7 downto 0) <= (others => 'Z');
        end if;
        
      ----------------------------------------------------------------------
      -- Normal cartridge port functions
      ----------------------------------------------------------------------      
      
      -- Generate phi2 and dotclock signals at 1Mhz and 8MHz respectively.
      -- We approximate these based on the pixel clock
      elsif reset = '0' then
        report "Asserting RESET on cartridge port";
        cart_reset <= '0';
        cart_reset_int <= '0';
        reset_counter <= 15;
        cpu_exrom <= '1';
        cpu_game <= '1';
      end if;

      cpu_exrom <= cart_exrom;
      cpu_game <= cart_game;

      ticker <= ('0'&ticker(15 downto 0)) + dotclock_increment;
      if ticker(16) = '0' then
        cart_access_read_strobe <= '0';
        cart_access_accept_strobe <= '0';
      else
        -- Tick dot clock
        report "dotclock tick";

        -- Ensure /RW, /IO1, /IO2 and DATA lines are held for
        -- long enough after rising clock edge.
        -- In theory, 60ns should be long enough, but I'm not
        -- convinced that that is long enough.
        -- Tiny Quest on a HUCKY 1.03 64K cart is somewhat
        -- unreliable with this configuration.
        -- So instead we delay for 1 complete clock at 8MHz
        -- = 125ns, which is less than the 6502's maximum rated
        -- 150ns.
        if cart_dotclock_internal='1' and phi2_ticker = 1 then
          report "Propagating next cycle values to expansion port lines";
          cart_rw <= next_rw;
          cart_io1 <= next_io1;
          cart_io2 <= next_io2;
          if next_data_dir='1' then
            cart_d <= (others => 'Z');
            report "PORT: cart_d: TRi-state";
          else
            cart_d <= next_d;
            report "PORT: cart_d: set to " & to_01UXstring(next_d);
          end if;
          cart_data_dir <= next_data_dir;
          cart_data_en <= next_data_en;
          cart_ctrl_dir <= next_ctrl_dir;
        end if;
        
        
        cart_dotclock <= not cart_dotclock_internal;
        cart_dotclock_internal <= not cart_dotclock_internal;
        if phi2_ticker /= 7 then
          phi2_ticker <= phi2_ticker + 1;
          cart_access_read_strobe <= '0';
          cart_access_accept_strobe <= '0';
        else
          -- Tick phi2
          report "phi2 tick";

          -- We assert reset on cartridge port for 15 phi2 cycles to give
          -- cartridge time to reset.
          if (reset_counter = 1) and (reset='1') then
            reset_counter <= 0;
          elsif reset_counter /= 0 then
            reset_counter <= reset_counter - 1;
          elsif reset_counter = 0 then
            if (not_joystick_cartridge = '1' and force_joystick_cartridge='0') or (disable_joystick_cartridge='1') then
              cart_reset <= reset and (not cart_force_reset);
              cart_reset_int <= reset and (not cart_force_reset);
              if cart_reset_int = '0' then
                report "Releasing RESET on cartridge port";
              end if;
            end if;
          end if;
          
            
          phi2_ticker <= (others => '0');
          cart_phi2 <= not cart_phi2_internal;
          cart_phi2_internal <= not cart_phi2_internal;

          -- Record data from bus if we are waiting on it
          if read_in_progress='1' then
            -- XXX Debug: show stats on probing cartridge flags
            case cart_access_address(15 downto 0) is
              when x"0000" =>
                -- @IO:GS $7010000.7 - Read cartridge /EXROM flag
                -- @IO:GS $7010000.6 - Read cartridge /GAME flag
                cart_access_rdata(7 downto 6) <= unsigned(cart_flags);
                -- @IO:GS $7010000.5 - Read cartridge force reset (1=reset)
                cart_access_rdata(5) <= cart_force_reset;
                -- @IO:GS $7010000.4-0 - UNUSUED (was R1 probe count)
                cart_access_rdata(4 downto 0) <= (others => '0');
              when x"0001" =>
                -- @IO:GS $7010001.7 - Expansion port mode: 1=normal mode, 0=joystick expansion mode
                cart_access_rdata(7) <= not_joystick_cartridge;
                -- @IO:GS $7010001.6 - 1=force joystick expansion mode.
                cart_access_rdata(6) <= force_joystick_cartridge;
                -- @IO:GS $7010001.5 - Joystick read toggle flag DEBUG
                cart_access_rdata(5) <= joy_read_toggle;
                cart_access_rdata(0) <= invert_joystick;
              when x"0002" =>
                -- @IO:GS $7010002 - Counter of /IRQ triggers from cartridge
                cart_access_rdata <= irq_count;
              when x"0003" =>
                -- @IO:GS $7010003 - Counter of /NMI triggers from cartridge
                cart_access_rdata <= nmi_count;
              when x"0004" =>
                -- @IO:GS $7010004 - Counter of /DMA triggers from cartridge
                cart_access_rdata <= dma_count;
              when x"0005" =>
                -- @IO:GS $7010005 - Counter of /GAME triggers from cartridge
                cart_access_rdata <= game_count;
              when x"0006" =>
                -- @IO:GS $7010006 - Counter of /EXROM triggers from cartridge
                cart_access_rdata <= exrom_count;
              when x"0007" =>
                -- @IO:GS $7010007 - Directly read cartridge port data lines.
                cart_access_rdata <= cart_d_in;
              when x"0008" =>
                -- @IO:GS $7010008 - Directly read lower 8 cartridge address data lines.
                cart_access_rdata <= cart_a(7 downto 0);
              when x"0009" =>
                -- @IO:GS $7010009 - Directly read upper 8 cartridge address data lines.
                cart_access_rdata <= cart_a(15 downto 8);
              when others =>                
                cart_access_rdata <= cart_d_in;
                report "Setting cart_access_rdata to %" & to_01UXstring(cart_d_in) & " from cart_d_in";
            end case;
            cart_access_read_strobe <= '1';
            cart_access_read_toggle <= not cart_access_read_toggle_internal;
            cart_access_read_toggle_internal <= not cart_access_read_toggle_internal;
            report "Read data from expansion port data pins = $" & to_hexstring(cart_d_in);
          else
            cart_access_read_strobe <= '0';
          end if;         

          -- Tri-state the bus when not active
          next_data_en <= '1';
          cart_addr_en <= '1';

          -- Present next bus request if we have one
          if (fake_reset_sequence_phase < 8 ) and (cart_phi2_internal='0') then

            report "FAKERESET: Progressing fake reset sequence #" & integer'image(fake_reset_sequence_phase);
            
            -- Provide fake power-on reset
            -- Sequence from: https://www.pagetable.com/?p=410
            case fake_reset_sequence_phase is
              when 0 | 1 | 2 => cart_a(15 downto 0) <= x"00FF";
              when 3 => cart_a(15 downto 0) <= x"0100";
              when 4 => cart_a(15 downto 0) <= x"01FF";
              when 5 => cart_a(15 downto 0) <= x"01FE";
              when 6 => cart_a(15 downto 0) <= x"FFFC";
              when 7 => cart_a(15 downto 0) <= x"FFFD";
              when others => null;
            end case;
            fake_reset_sequence_phase <= fake_reset_sequence_phase + 1;

            cart_busy <= '1';
            cart_a <= cart_access_address(15 downto 0);
            cart_ctrl_dir <= '1'; -- make R/W, /IO1, /IO2 etc output
            next_rw <= '1';
            next_data_dir <= not '1';
            next_data_en <= '0'; -- negative sense on these lines: low = enable
            cart_addr_en <= '0'; -- negative sense on these lines: low = enable

            -- Count number of cartridge accesses to aid debugging
            cart_access_count <= cart_access_count_internal + 1;
            cart_access_count_internal <= cart_access_count_internal + 1;
            
          elsif (cart_access_request='1') and (reset_counter = 0)
            -- Check that clock will be high during this request, i.e.,
            -- currently low.
            and (cart_phi2_internal='0') then            
            report "Presenting legacy C64 expansion port access request to port, address=$"
              & to_hexstring(cart_access_address)
              & " rw=" & std_logic'image(cart_access_read)
              & " wdata=$" & to_hexstring(cart_access_wdata);

            if cart_access_read='0' then
              if cart_access_address(15 downto 0) = x"0000" then
                -- @ IO:GS $7010000.5 - Force assertion of /RESET on cartridge port
                cart_force_reset <= cart_access_wdata(5);
                if cart_force_reset <= '1' and cart_access_wdata(5) = '0' then
                  -- Release of reset
                  -- Some cartridges need to see the CPU do a reset sequence,
                  -- before they will work.  So we will now schedule a fake
                  -- reset sequence.
                  fake_reset_sequence_phase <= 0;
                end if;
              elsif cart_access_address(15 downto 0) = x"0001" then
                -- @ IO:GS $7010001.4 - Force disabling of joystick expander cartridge
                -- @ IO:GS $7010001.6 - Force enabling of joystick expander cartridge
                -- @ IO:GS $7010001.0 - Invert joystick line polarity for joystick expander cartridge
                force_joystick_cartridge <= cart_access_wdata(6);
                disable_joystick_cartridge <= cart_access_wdata(4);
                invert_joystick <= cart_access_wdata(0);
              elsif cart_access_address(15 downto 0) = x"0002" then
                oride_ctrl_en <= cart_access_wdata(0);
                oride_ctrl_dir <= cart_access_wdata(1);
                oride_io1 <= cart_access_wdata(2);
                oride_io2 <= cart_access_wdata(3);
                oride_romh <= cart_access_wdata(4);
                oride_roml <= cart_access_wdata(5);
                oride_enable <= cart_access_wdata(7);
              end if;
            end if;
            cart_busy <= '1';

            -- Count number of cartridge accesses to aid debugging
            cart_access_count <= cart_access_count_internal + 1;
            cart_access_count_internal <= cart_access_count_internal + 1;

            report "Asserting cart_access_accept_strobe";
            cart_access_accept_strobe <= '1';
                  
            if (not_joystick_cartridge = '1' and force_joystick_cartridge='0') or (disable_joystick_cartridge='1') then
            
              cart_ctrl_dir <= '1'; -- make R/W, /IO1, /IO2 etc output
              cart_a <= cart_access_address(15 downto 0);
              next_rw <= cart_access_read;
              next_data_dir <= not cart_access_read;
              next_data_en <= cart_access_read; -- negative sense on these lines: low = enable
              cart_addr_en <= '0'; -- negative sense on these lines: low = enable
              if cart_access_address(15 downto 8) = x"DE" then
                next_io1 <= '0';
              else
                next_io1 <= '1';
              end if;
              if cart_access_address(15 downto 8) = x"DF" then
                next_io2 <= '0';
              else
                next_io2 <= '1';
              end if;

              -- Drive ROML and ROMH
              -- (Note here we are operating after the CPU has decided if something
              -- is mapped, therefore we assert /ROML and /ROMH based on address
              -- requested).
              if (cart_access_address(15 downto 12) = x"8")
                or (cart_access_address(15 downto 12) = x"9") then
                cart_roml <= '0';
              else
                cart_roml <= '1';
              end if;
              if (cart_access_address(15 downto 12) = x"A")
                or (cart_access_address(15 downto 12) = x"B") 
                or (cart_access_address(15 downto 12) = x"E")
                or (cart_access_address(15 downto 12) = x"F") then
                cart_romh <= '0';
              else
                cart_romh <= '1';
              end if;
            end if;
              
            if cart_access_read='1' then
              read_in_progress <= '1';
              if (not_joystick_cartridge = '1' and force_joystick_cartridge='0') or (disable_joystick_cartridge='1') then
                -- Tri-state with pull-up
                report "Tristating cartridge port data lines.";
                next_d <= (others => 'Z');
                next_data_en <= '1';
                next_data_dir <= '0'; -- set data lines to input
              end if;
            else
              read_in_progress <= '0';
              if (not_joystick_cartridge = '1' and force_joystick_cartridge='0') or (disable_joystick_cartridge='1') then
                next_d <= cart_access_wdata;
                next_data_dir <= '1'; -- set data lines to output
                report "Write data is $" & to_hexstring(cart_access_wdata);
              end if;
            end if;
          else
            if (not_joystick_cartridge = '1' and force_joystick_cartridge='0') or (disable_joystick_cartridge='1') then
              cart_access_accept_strobe <= '0';
              cart_a <= (others => 'Z');
              cart_roml <= '1';
              cart_romh <= '1';
              next_io1 <= '1';
              next_io2 <= '1';
              next_rw <= '1';
              next_ctrl_dir <= '1'; -- make R/W, /IO1, /IO2 etc output
            end if;
            read_in_progress <= '0';
            cart_busy <= '0';            
          end if;      
        end if;
      end if;

      if oride_enable='1' then
        cart_ctrl_en <= oride_ctrl_en;
        cart_ctrl_dir <= oride_ctrl_dir;
        cart_io2 <= oride_io1;
        cart_io1 <= oride_io2;
        cart_roml <= oride_roml;
        cart_romh <= oride_romh;
      end if;
      
    end if;
    
  end process;

  
end behavioural;
