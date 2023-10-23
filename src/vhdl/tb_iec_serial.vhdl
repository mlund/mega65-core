library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use Std.TextIO.all;
use work.debugtools.all;
use work.cputypes.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity tb_iec_serial is
  generic (runner_cfg : string);
end entity;

architecture test_arch of tb_iec_serial is

  signal pixelclock : std_logic := '0';
  signal clock41 : std_logic := '0';

  signal fastio_addr : unsigned(19 downto 0) := x"d3690";
  signal fastio_write : std_logic := '0';
  signal fastio_read : std_logic := '0';
  signal fastio_wdata : unsigned(7 downto 0);
  signal fastio_rdata : unsigned(7 downto 0);
  
  signal debug_state : unsigned(11 downto 0);
  signal debug_usec : unsigned(7 downto 0);
  signal debug_msec : unsigned(7 downto 0);
  signal iec_state_reached : unsigned(11 downto 0);

  signal drive_cycle_countdown : integer := 0;

  signal iec_reset : std_logic;
  signal iec_atn : std_logic;
  signal iec_clk_en_n : std_logic;
  signal iec_data_en_n : std_logic;
  signal iec_srq_en_n : std_logic;
  signal iec_clk_o : std_logic;
  signal iec_data_o : std_logic;
  signal iec_srq_o : std_logic;
  signal iec_clk_i : std_logic := '1';
  signal iec_data_i : std_logic := '1';
  signal iec_srq_i : std_logic := '1';
    
  signal atn_state : integer := 0;

  signal dummy_iec_data : std_logic := '1';
  
  signal f1541_pc : unsigned(15 downto 0);
  signal f1541_reset_n : std_logic := '1';
  signal f1541_cycle_strobe : std_logic := '0';
  signal f1541_clk : std_logic;
  signal f1541_data : std_logic;
  signal f1541_srq : std_logic;

  signal dummy_iec_data_last : std_logic := '1';
  signal f1541_data_last : std_logic := '1';
  signal f1541_clk_last : std_logic := '1';
  signal iec_clk_en_n_last : std_logic := '1';
  signal iec_data_en_n_last : std_logic := '1';
  signal iec_atn_last : std_logic := '1';
  signal power_up : boolean := true;
  
begin

  iec0: entity work.iec_serial generic map (
    cpu_frequency => 40_500_500,
    with_debug => true
    )
    port map (
    clock => clock41,
    clock81 => pixelclock,

    fastio_addr => fastio_addr,
    fastio_write => fastio_write,
    fastio_read => fastio_read,
    fastio_wdata => fastio_wdata,
    fastio_rdata => fastio_rdata,

    debug_state => debug_state,
    debug_usec => debug_usec,
    debug_msec => debug_msec,

    iec_state_reached => iec_state_reached,

    iec_reset => iec_reset,
    iec_atn => iec_atn,
    iec_clk_en_n => iec_clk_en_n,
    iec_data_en_n => iec_data_en_n,
    iec_srq_en_n => iec_srq_en_n,
    iec_clk_o => iec_clk_o,
    iec_data_o => iec_data_o,
    iec_srq_o => iec_srq_o,
    iec_clk_i => iec_clk_i,
    iec_data_i => iec_data_i,
    iec_srq_i => iec_srq_i
    
    );

  c1541: entity work.internal1541
    port map (
      clock => clock41,

      fastio_read => '0',
      fastio_write => '0',
      fastio_address => to_unsigned(0,20),
      fastio_wdata => x"00",
      cs_driverom => '0',
      cs_driveram => '0',

      address_next => f1541_pc,

      drive_clock_cycle_strobe => f1541_cycle_strobe,
      drive_reset_n => f1541_reset_n,
      drive_suspend => '0',

      -- A bit of a simplification for the IEC lines:
      -- If the IEC controller is driving the lines, we assume
      -- it is driving them low, not high (which it never does).
      -- Ideally we would have <= (iec_clk_en_n and iec_clk_out)
      -- etc.
      iec_atn_i => iec_atn,
      iec_clk_i => iec_clk_en_n,
      iec_data_i => iec_data_en_n,
      iec_srq_i => iec_srq_en_n,

      iec_clk_o => f1541_clk,
      iec_data_o => f1541_data,
      iec_srq_o => f1541_srq,
      
      sd_data_byte => x"00",
      sd_data_ready_toggle => '0'
      
      );

  process (clock41) is
    variable show_update : boolean := false;
  begin
    if rising_edge(clock41) then
            
      -- Compute effective IEC line voltages
      iec_data_i <= dummy_iec_data and f1541_data and iec_data_en_n;
      iec_clk_i <= f1541_clk and iec_clk_en_n;

      -- Do we need to show an update to the IEC bus state?
      show_update := false;
      if power_up then
        power_up <= false;
        show_update := true;
      end if;
      f1541_data_last <= f1541_data;
      f1541_clk_last <= f1541_clk;
      iec_clk_en_n_last <= iec_clk_en_n;
      iec_data_en_n_last <= iec_data_en_n;
      iec_atn_last <= iec_atn;
      dummy_iec_data_last <= dummy_iec_data;
      if f1541_clk /= f1541_clk_last then
        show_update := true;
      end if;
      if f1541_data /= f1541_data_last then
        show_update := true;
      end if;
      if iec_clk_en_n /= iec_clk_en_n_last then
        show_update := true;
      end if;
      if iec_data_en_n /= iec_data_en_n_last then
        show_update := true;
      end if;
      if iec_atn /= iec_atn_last then
        show_update := true;
      end if;
      if dummy_iec_data /= dummy_iec_data_last then
        show_update := true;
      end if;
      if show_update then
        report "IECBUSSTATE: "
          & "ATN=" & std_logic'image(iec_atn)
          & ", CLK(c64)=" & std_logic'image(iec_clk_en_n)
          & ", CLK(1541)=" & std_logic'image(f1541_clk)
          & ", DATA(c64)=" & std_logic'image(iec_data_en_n)
          & ", DATA(1541)=" & std_logic'image(f1541_data)
          & ", DATA(dummy)=" & std_logic'image(dummy_iec_data)
          ;
      end if;
    end if;
  end process;
  
  
  main : process

    procedure clock_tick is
    begin
      pixelclock <= not pixelclock;
      if pixelclock='1' then
        clock41 <= not clock41;
        if clock41 = '1' then
          if drive_cycle_countdown /= 0 then
            drive_cycle_countdown <= drive_cycle_countdown - 1;
            f1541_cycle_strobe <= '0';
          else
            drive_cycle_countdown <= 40;
            f1541_cycle_strobe <= '1';
          end if;
        end if;
      end if;
      wait for 6.173 ns;
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);    
    
    while test_suite loop

      if run("Simulated 1541 runs") then
        -- 3x10^6 x 81MHz ticks = ~20msec. Plenty enough for getting to main loop
        -- of drive. (Needs >3x10^6 to get to $73 in DOS error code table).
        for i in 1 to 3_000_000 loop
          clock_tick;
        end loop;
      elsif run("ATN Sequence with no device gets DEVICE NOT PRESENT") then
        fastio_addr(3 downto 0) <= x"9"; -- set write data
        fastio_wdata <= x"28"; -- Access device 8
        fastio_write <= '1';
        for i in 1 to 4 loop
          clock_tick;
        end loop;
        fastio_addr(3 downto 0) <= x"8";
        fastio_wdata <= x"30"; -- Trigger ATN write
        for i in 1 to 4 loop
          clock_tick;
        end loop;
        fastio_write <= '0';
        
        for i in 1 to 400000 loop
          clock_tick;
        end loop;
        fastio_addr(3 downto 0) <= x"8";
        fastio_read <= '1';
        for i in 1 to 8 loop
          clock_tick;
        end loop;
        fastio_read <= '0';
        report "IEC state reached = " & to_hexstring(iec_state_reached);
        report "IEC status byte = $" & to_hexstring(fastio_rdata);
        if fastio_rdata(7)='0' then
          assert false report "Expected to see DEVICE NOT PRESENT indicated in bit 7 of $D698, but it wasn't";
        end if;
        if fastio_rdata(1)='0' then
          assert false report "Expected to see TIMEOUT indicated in bit 1 of $D698, but it wasn't";
        end if;

      elsif run("Debug RAM can be read") then
        fastio_addr(3 downto 0) <= x"9"; -- set write data
        fastio_wdata <= x"28"; -- Access device 8
        fastio_write <= '1';
        for i in 1 to 4 loop
          clock_tick;
        end loop;
        fastio_addr(3 downto 0) <= x"8";
        fastio_wdata <= x"30"; -- Trigger ATN write
        for i in 1 to 4 loop
          clock_tick;
        end loop;
        fastio_write <= '0';
        
        for i in 1 to 400000 loop
          clock_tick;
        end loop;

        -- Now read back debug RAM content

        -- Reset read point to start of debug RAM
        fastio_write <= '1';
        fastio_wdata <= x"00";
        for i in 1 to 8 loop
          clock_tick;
        end loop;
        fastio_write <= '0';

        report "Starting readback of debug RAM";
        fastio_addr(3 downto 0) <= x"4";
        for n in 0 to 127 loop
          fastio_write <= '0';
          fastio_read <= '1';
          for i in 1 to 8 loop
            clock_tick;
          end loop;
          fastio_read <= '0';

          report "Read $" & to_hexstring(fastio_rdata) & " from debug RAM.";
          
          fastio_read <= '0';
          fastio_write <= '1';
          fastio_wdata <= x"01";
          for i in 1 to 4 loop
            clock_tick;
          end loop;

        end loop;
                  
      elsif run("ATN Sequence with dummy device succeeds") then

        for i in 1 to 4000 loop
          clock_tick;
        end loop;
        
        fastio_addr(3 downto 0) <= x"9"; -- set write data
        fastio_wdata <= x"28"; -- Access device 8
        fastio_write <= '1';
        for i in 1 to 4 loop
          clock_tick;
        end loop;
        fastio_addr(3 downto 0) <= x"8";
        fastio_wdata <= x"30"; -- Trigger ATN write
        for i in 1 to 4 loop
          clock_tick;
        end loop;
        fastio_write <= '0';
        
        for i in 1 to 800000 loop
          clock_tick;
          if iec_atn='0' then
            if true then
              -- Pretend there is a device
              if atn_state = 0 and iec_clk_o = '0' then
                atn_state <= 1;
                report "TESTBED: Pulling DATA to 0V";
                dummy_iec_data <= '0';
              end if;
              if atn_state = 1 and iec_clk_o = '1' then
                atn_state <= 2;
                dummy_iec_data <= '1';
                report "TESTBED: Releasing DATA to 5V";
              end if;
              if atn_state = 2 and iec_clk_o = '0' then
                atn_state <= 3;
              end if;
              if atn_state = 2 and iec_clk_o = '0' then
                atn_state <= 3;
              end if;
              -- Then watch first 7 bits arrive, then signal JiffyDOS support
              if atn_state = 2 and iec_clk_o = '0' then atn_state <= atn_state + 1; end if;
              if atn_state = 3 and iec_clk_o = '1' then atn_state <= atn_state + 1; end if;
              if atn_state = 4 and iec_clk_o = '0' then atn_state <= atn_state + 1; end if;
              if atn_state = 5 and iec_clk_o = '1' then atn_state <= atn_state + 1; end if;
              if atn_state = 6 and iec_clk_o = '0' then atn_state <= atn_state + 1; end if;
              if atn_state = 7 and iec_clk_o = '1' then atn_state <= atn_state + 1; end if;
              if atn_state = 8 and iec_clk_o = '0' then atn_state <= atn_state + 1; end if;
              if atn_state = 9 and iec_clk_o = '1' then atn_state <= atn_state + 1; end if;
              if atn_state = 10 and iec_clk_o = '0' then atn_state <= atn_state + 1; end if;
              if atn_state = 11 and iec_clk_o = '1' then atn_state <= atn_state + 1; end if;
              if atn_state = 12 and iec_clk_o = '0' then atn_state <= atn_state + 1; end if;
              if atn_state = 13 and iec_clk_o = '1' then atn_state <= atn_state + 1; end if;
              if atn_state = 14 and iec_clk_o = '0' then atn_state <= atn_state + 1; end if;
              if atn_state = 15 and iec_clk_o = '1' then atn_state <= atn_state + 1; end if;
              if atn_state = 16 and iec_clk_o = '0' then
                atn_state <= atn_state + 1;
                dummy_iec_data <= '0';
                report "TESTBED: Pulling DATA to 0V to kludge indication of JiffyDOS support ";
                for j in 1 to 12 loop
                  clock_tick;
                end loop;
                dummy_iec_data <= '1';
              end if;
              if atn_state = 17 and iec_clk_o = '1' then atn_state <= atn_state + 1; end if;
              if atn_state = 18 and iec_clk_o = '0' then
                atn_state <= atn_state + 1;
                dummy_iec_data <= '0';
                report "TESTBED: Pulling DATA to 0V to kludge indication of byte acknowledgement ";
              end if;
            end if;
          end if;
        end loop;
        report "IEC state reached = " & to_hexstring(iec_state_reached);

        -- Expect BUSY flag to have cleared
        fastio_addr(3 downto 0) <= x"7";
        fastio_read <= '1';
        for i in 1 to 8 loop
          clock_tick;
        end loop;
        fastio_read <= '0';
        report "IEC IRQ status byte = $" & to_hexstring(fastio_rdata);
        if fastio_rdata(5)='0' then
          assert false report "Expected to see ready for command indicated in bit 5 of $D697, but it wasn't";
        end if;

        -- Read status byte
        fastio_addr(3 downto 0) <= x"8";
        fastio_read <= '1';
        for i in 1 to 8 loop
          clock_tick;
        end loop;
        fastio_read <= '0';
        report "IEC status byte = $" & to_hexstring(fastio_rdata);
        if fastio_rdata(7)='1' then
          assert false report "Expected to not see DEVICE NOT PRESENT indicated in bit 7 of $D698, but it was";
        end if;
        if fastio_rdata(1)='1' then
          assert false report "Expected to not see TIMEOUT indicated in bit 1 of $D698, but it was";
        end if;

        
      elsif run("ATN Sequence with VHDL 1541 device succeeds") then

        report "IEC: Allowing time for 1541 to boot";
        
        -- Give the 1541 just time enough to boot
        for i in 1 to 1_950_000 loop
          clock_tick;
        end loop;

        report "IEC: Commencing sending byte under ATN";
        
        fastio_addr(3 downto 0) <= x"9"; -- set write data
        fastio_wdata <= x"28"; -- Access device 8 (which isn't actually
                               -- present, the VHDL device is 11, but
                               -- this situation doesn't get detected as
                               -- device not present).
        fastio_write <= '1';
        for i in 1 to 4 loop
          clock_tick;
        end loop;
        fastio_addr(3 downto 0) <= x"8";
        fastio_wdata <= x"30"; -- Trigger ATN write
        for i in 1 to 4 loop
          clock_tick;
        end loop;
        fastio_write <= '0';

        -- Allow time for everything to happen
        for i in 1 to 800000 loop
          clock_tick;
        end loop;
        report "IEC state reached = $" & to_hexstring(iec_state_reached) & " = " & integer'image(to_integer(iec_state_reached));

        -- Expect BUSY flag to have cleared
        fastio_addr(3 downto 0) <= x"7";
        fastio_read <= '1';
        for i in 1 to 8 loop
          clock_tick;
        end loop;
        fastio_read <= '0';
        report "IEC IRQ status byte = $" & to_hexstring(fastio_rdata);
        if fastio_rdata(5)='0' then
          assert false report "Expected to see ready for command indicated in bit 5 of $D697, but it wasn't";
        end if;

        -- Read status byte
        fastio_addr(3 downto 0) <= x"8";
        fastio_read <= '1';
        for i in 1 to 8 loop
          clock_tick;
        end loop;
        fastio_read <= '0';
        report "IEC status byte = $" & to_hexstring(fastio_rdata);
        if fastio_rdata(7)='1' then
          assert false report "Expected to not see DEVICE NOT PRESENT indicated in bit 7 of $D698, but it was";
        end if;
        if fastio_rdata(1)='1' then
          assert false report "Expected to not see TIMEOUT indicated in bit 1 of $D698, but it was";
        end if;

        
      elsif run("Read from Error Channel (15) of VHDL 1541 device succeeds") then

        -- Send $48, $6F under ATN, then do turn-around to listen, and receive
        -- 73,... status message from the drive.
        
        report "IEC: Allowing time for 1541 to boot";
        
        -- Give the 1541 just time enough to boot
        for i in 1 to 1_950_000 loop
          clock_tick;
        end loop;

        report "IEC: Commencing sending DEVICE 11 TALK ($4B) byte under ATN";

        fastio_addr(3 downto 0) <= x"9"; -- set write data
        fastio_wdata <= x"4B"; -- Access device 11
        fastio_write <= '1';
        for i in 1 to 4 loop
          clock_tick;
        end loop;
        fastio_addr(3 downto 0) <= x"8";
        fastio_wdata <= x"30"; -- Trigger ATN write
        for i in 1 to 4 loop
          clock_tick;
        end loop;
        fastio_write <= '0';

        -- Allow time for everything to happen
        for i in 1 to 800000 loop
          clock_tick;
        end loop;
        report "IEC state reached = $" & to_hexstring(iec_state_reached) & " = " & integer'image(to_integer(iec_state_reached));

        -- Expect BUSY flag to have cleared
        fastio_addr(3 downto 0) <= x"7";
        fastio_read <= '1';
        for i in 1 to 8 loop
          clock_tick;
        end loop;
        fastio_read <= '0';
        report "IEC IRQ status byte = $" & to_hexstring(fastio_rdata);
        if fastio_rdata(5)='0' then
          assert false report "Expected to see ready for command indicated in bit 5 of $D697, but it wasn't";
        end if;

        -- Read status byte
        fastio_addr(3 downto 0) <= x"8";
        fastio_read <= '1';
        for i in 1 to 8 loop
          clock_tick;
        end loop;
        fastio_read <= '0';
        report "IEC status byte = $" & to_hexstring(fastio_rdata);
        if fastio_rdata(7)='1' then
          assert false report "Expected to not see DEVICE NOT PRESENT indicated in bit 7 of $D698, but it was";
        end if;
        if fastio_rdata(1)='1' then
          assert false report "Expected to not see TIMEOUT indicated in bit 1 of $D698, but it was";
        end if;


        report "IEC: Commencing sending SECONDARY ADDRESS 15 byte under ATN";

        fastio_addr(3 downto 0) <= x"9"; -- set write data
        fastio_wdata <= x"6F"; -- Secondary address 15
        fastio_write <= '1';
        for i in 1 to 4 loop
          clock_tick;
        end loop;
        fastio_addr(3 downto 0) <= x"8";
        fastio_wdata <= x"30"; -- Trigger ATN write
        for i in 1 to 4 loop
          clock_tick;
        end loop;
        fastio_write <= '0';

        -- Allow time for everything to happen
        for i in 1 to 800000 loop
          clock_tick;
        end loop;
        report "IEC state reached = $" & to_hexstring(iec_state_reached) & " = " & integer'image(to_integer(iec_state_reached));

        -- Expect BUSY flag to have cleared
        fastio_addr(3 downto 0) <= x"7";
        fastio_read <= '1';
        for i in 1 to 8 loop
          clock_tick;
        end loop;
        fastio_read <= '0';
        report "IEC IRQ status byte = $" & to_hexstring(fastio_rdata);
        if fastio_rdata(5)='0' then
          assert false report "Expected to see ready for command indicated in bit 5 of $D697, but it wasn't";
        end if;

        -- Read status byte
        fastio_addr(3 downto 0) <= x"8";
        fastio_read <= '1';
        for i in 1 to 8 loop
          clock_tick;
        end loop;
        fastio_read <= '0';
        report "IEC status byte = $" & to_hexstring(fastio_rdata);
        if fastio_rdata(7)='1' then
          assert false report "Expected to not see DEVICE NOT PRESENT indicated in bit 7 of $D698, but it was";
        end if;
        if fastio_rdata(1)='1' then
          assert false report "Expected to not see TIMEOUT indicated in bit 1 of $D698, but it was";
        end if;


        report "IEC: Commencing turn-around to listen";

        fastio_write <= '1';
        fastio_addr(3 downto 0) <= x"8";
        fastio_wdata <= x"35"; -- Trigger turn-around to listen
        for i in 1 to 4 loop
          clock_tick;
        end loop;
        fastio_write <= '0';

        -- Allow a little time and check status goes busy
        for i in 1 to 100 loop
          clock_tick;
        end loop;

        -- Expect BUSY flag to have set
        fastio_addr(3 downto 0) <= x"7";
        fastio_read <= '1';
        for i in 1 to 8 loop
          clock_tick;
        end loop;
        fastio_read <= '0';
        report "IEC IRQ status byte = $" & to_hexstring(fastio_rdata);
        if fastio_rdata(5)='1' then
          assert false report "Expected to see IEC bus busy in bit 5 of $D697, but it wasn't";
        end if;
        
        -- Allow time for everything to happen
        for i in 1 to 50000 loop
          clock_tick;
        end loop;
        report "IEC state reached = $" & to_hexstring(iec_state_reached) & " = " & integer'image(to_integer(iec_state_reached));

        -- Expect BUSY flag to have cleared
        fastio_addr(3 downto 0) <= x"7";
        fastio_read <= '1';
        for i in 1 to 8 loop
          clock_tick;
        end loop;
        fastio_read <= '0';
        report "IEC IRQ status byte = $" & to_hexstring(fastio_rdata);
        if fastio_rdata(5)='0' then
          assert false report "Expected to see ready for command indicated in bit 5 of $D697, but it wasn't";
        end if;

        -- Read status byte
        fastio_addr(3 downto 0) <= x"8";
        fastio_read <= '1';
        for i in 1 to 8 loop
          clock_tick;
        end loop;
        fastio_read <= '0';
        report "IEC status byte = $" & to_hexstring(fastio_rdata);
        if fastio_rdata(7)='1' then
          assert false report "Expected to not see DEVICE NOT PRESENT indicated in bit 7 of $D698, but it was";
        end if;
        if fastio_rdata(1)='1' then
          assert false report "Expected to not see TIMEOUT indicated in bit 1 of $D698, but it was";
        end if;
        

        
      end if;
    end loop;
    test_runner_cleanup(runner);
  end process;

end architecture;
