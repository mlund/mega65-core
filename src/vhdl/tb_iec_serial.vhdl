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

  signal iec_reset : std_logic;
  signal iec_atn : std_logic;
  signal iec_clk_en : std_logic;
  signal iec_data_en : std_logic;
  signal iec_srq_en : std_logic;
  signal iec_clk_o : std_logic;
  signal iec_data_o : std_logic;
  signal iec_srq_o : std_logic;
  signal iec_clk_i : std_logic := '1';
  signal iec_data_i : std_logic := '1';
  signal iec_srq_i : std_logic := '1';
    
  signal atn_state : integer := 0;
  
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
    iec_clk_en => iec_clk_en,
    iec_data_en => iec_data_en,
    iec_srq_en => iec_srq_en,
    iec_clk_o => iec_clk_o,
    iec_data_o => iec_data_o,
    iec_srq_o => iec_srq_o,
    iec_clk_i => iec_clk_i,
    iec_data_i => iec_data_i,
    iec_srq_i => iec_srq_i
    
    );

  main : process

    procedure clock_tick is
    begin
      pixelclock <= not pixelclock;
      if pixelclock='1' then
        clock41 <= not clock41;
      end if;
      wait for 6.173 ns;
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop

      if run("ATN Sequence with no device gets DEVICE NOT PRESENT") then
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
          

        
      elsif run("ATN Sequence with device succeeds") then

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
                iec_data_i <= '0';
              end if;
              if atn_state = 1 and iec_clk_o = '1' then
                atn_state <= 2;
                iec_data_i <= '1';
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
                iec_data_i <= '0';
                report "TESTBED: Pulling DATA to 0V to kludge indication of JiffyDOS support ";
                for j in 1 to 12 loop
                  clock_tick;
                end loop;
                iec_data_i <= '1';
              end if;
              if atn_state = 17 and iec_clk_o = '1' then atn_state <= atn_state + 1; end if;
              if atn_state = 18 and iec_clk_o = '0' then
                atn_state <= atn_state + 1;
                iec_data_i <= '0';
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

        
        
      end if;
    end loop;
    test_runner_cleanup(runner);
  end process;

end architecture;
