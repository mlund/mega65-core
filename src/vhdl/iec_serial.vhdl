use WORK.ALL;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use Std.TextIO.all;
use work.debugtools.all;
use work.cputypes.all;

entity iec_serial is
  generic (
    cpu_frequency : integer
    );
  port (
    clock : in std_logic;
    clock81 : in std_logic;
    irq : out std_logic := '1';
    
    --------------------------------------------------
    -- CBM floppy serial port
    --------------------------------------------------
    fastio_addr : in unsigned(19 downto 0);
    fastio_write : in std_logic;
    fastio_read : in std_logic;
    fastio_wdata : in unsigned(7 downto 0);
    fastio_rdata : out unsigned(7 downto 0);
    
    --------------------------------------------------
    -- CBM floppy serial port
    --------------------------------------------------
    iec_reset : out std_logic;
    iec_atn : out std_logic;
    iec_clk_en : out std_logic;
    iec_data_en : out std_logic;
    iec_srq_en : out std_logic;
    iec_clk_o : out std_logic;
    iec_data_o : out std_logic;
    iec_srq_o : out std_logic;
    iec_clk_i : in std_logic;
    iec_data_i : in std_logic;
    iec_srq_i : in std_logic
    
    );
end iec_serial;

architecture questionable of iec_serial is

  signal iec_irq : unsigned(7 downto 0) := x"00";
  signal iec_status : unsigned(7 downto 0) := x"00";
  signal iec_data : unsigned(7 downto 0) := x"00";
  signal iec_data_out : unsigned(7 downto 0) := x"00";
  signal iec_devinfo : unsigned(7 downto 0) := x"00";

  signal iec_cmd : unsigned(7 downto 0) := x"00";
  signal iec_new_cmd : std_logic := '0';

  -- C= fast serial protocol does not send fast byte prior
  -- to ATN if a device is listening (as in that case, it
  -- would treat the byte as data)
  signal iec_dev_listening : std_logic := '0';  
  
  signal iec_state : integer := 0;
  signal iec_busy : std_logic := '0';
  signal iec_under_attention : std_logic := '0';
  
  signal wait_clk_high : std_logic := '0';
  signal wait_clk_low : std_logic := '0';
  signal wait_data_high : std_logic := '0';
  signal wait_data_low : std_logic := '0';
  signal wait_srq_high : std_logic := '0';
  signal wait_srq_low : std_logic := '0';

  signal wait_usec : integer := 0;
  signal wait_msec : integer := 0;

  signal cycles : integer := 0;
  signal usecs : integer := 0;
  signal usec_toggle : std_logic := '0';
  signal msec_toggle : std_logic := '0';
  signal last_usec_toggle : std_logic := '0';
  signal last_msec_toggle : std_logic := '0';
  signal timing_sync_toggle : std_logic := '0';
  signal last_timing_sync_toggle : std_logic := '0';

begin

  -- Note that we put RX on bit 6, so that the common case of LOADing can be a
  -- little faster, by allowing BIT $D697 / BVC *-3 to be a very tight loop
  -- for waiting for bytes.

  -- @IO:GS $D697.7 AUTOIEC:IRQFLAG Interrupt flag. Set if any IRQ event is triggered.
  -- @IO:GS $D697.6 AUTOIEC:IRQRX Set if a byte has been received from a listener.
  -- @IO:GS $D697.5 AUTOIEC:IRQREADY Set if ready to process a command
  -- @IO:GS $D697.4 AUTOIEC:IRQTO Set if a protocol timeout has occurred, e.g., device not found.
  -- @IO:GS $D697.3 AUTOIEC:IRQEN Enable interrupts if set
  -- @IO:GS $D697.2 AUTOIEC:IRQRXEN Enable RX interrupt source if set
  -- @IO:GS $D697.1 AUTOIEC:IRQREADYEN Enable TX interrupt source if set
  -- @IO:GS $D697.0 AUTOIEC:IRQTOEN Enable timeout interrupt source if set
  
  -- @IO:GS $D698.7 AUTOIEC:STNODEV Device not present
  -- @IO:GS $D698.6 AUTOIEC:STNOEOF End of file
  -- @IO:GS $D698.5 AUTOIEC:STSRQ State of SRQ line
  -- @IO:GS $D698.4 AUTOIEC:STVERIFY Verify error occurred
  -- @IO:GS $D698.3 AUTOIEC:STC State of CLK line
  -- @IO:GS $D698.2 AUTOIEC:STD Sate of DATA line
  -- @IO:GS $D698.1 AUTOIEC:STTO Timeout occurred
  -- @IO:GS $D698.0 AUTOIEC:STDDIR Data direction when timeout occurred.
  
  -- @IO:GS $D699 AUTOIEC:DATA Data byte read from IEC bus
  -- @IO:GS $D69A.7 AUTOIEC:DIPRESENT Device is present
  -- @IO:GS $D69A.5-6 AUTOIEC:DIPROT Device protocol (00=1541,01=C128/C65 FAST, 10 = JiffyDOS(tm), 11=both
  -- @IO:GS $D69A.4 AUTOIEC:DIATN Device is currently held under attention
  -- @IO:GS $D69A.0-3 AUTOIEC:DIDEVNUM Lower 4 bits of currently selected device number
  
  process (clock,clock81) is
  begin

    if rising_edge(clock81) then
      if timing_sync_toggle /= last_timing_sync_toggle then
        last_timing_sync_toggle <= timing_sync_toggle;
        cycles <= 0;
        usecs <= 0;
      elsif cycles < (81-1) then
        cycles <= cycles + 1;
      else
        cycles <= 0;
        usec_toggle <= not usec_toggle;
        if usecs < 999 then
          usecs <= usecs + 1;
        else
          usecs <= 0;
          msec_toggle <= not msec_toggle;
        end if;
      end if;
    end if;
    
    if fastio_addr(19 downto 4) = x"d369"
      and (to_integer(fastio_addr(3 downto 0))>6)
      and (to_integer(fastio_addr(3 downto 0))<11)
      and fastio_read='1' then
      case fastio_addr(3 downto 0) is
        when x"7" => -- Read IRQ register
          fastio_rdata <= iec_irq;
        when x"8" => -- Read from status register
          fastio_rdata <= iec_status;
        when x"9" => -- Read from data register
          fastio_rdata <= iec_data;
        when x"a" => -- Read device info
          fastio_rdata <= iec_devinfo;
        when others => fastio_rdata <= (others => 'Z');
      end case;
    else
      fastio_rdata <= (others => 'Z');
    end if;
    
    if rising_edge(clock) then

      -- Indicate busy status
      iec_irq(5) <= not iec_busy;
    
      -- Allow easy reading of IEC lines
      iec_status(5) <= iec_srq_i;
      iec_status(3) <= iec_clk_i;
      iec_status(2) <= iec_data_i;
      
      -- Trigger IRQ if appropriate event has occurred
      if (iec_irq(6) and iec_irq(6-4)) = '1' then
        iec_irq(7) <= '1';
      end if;
      if (iec_irq(5) and iec_irq(5-4)) = '1' then
        iec_irq(7) <= '1';
      end if;
      if (iec_irq(4) and iec_irq(4-4)) = '1' then
        iec_irq(7) <= '1';
      end if;
      if (iec_irq(7) and iec_irq(7-4)) = '1' then
        irq <= '0';
      else
        irq <= '1';
      end if;
      
      if fastio_addr(19 downto 4) = x"d369"
        and (to_integer(fastio_addr(3 downto 0))>6)
        and (to_integer(fastio_addr(3 downto 0))<11) then
        if fastio_write='1' then
          case fastio_addr(3 downto 0) is
            when x"7" => -- Write to IRQ register
              -- Writing to IRQ bits clears the events
              iec_irq(7) <= iec_irq(7) and not fastio_wdata(7);
              iec_irq(6) <= iec_irq(6) and not fastio_wdata(6);
              iec_irq(5) <= iec_irq(5) and not fastio_wdata(5);
              iec_irq(4) <= iec_irq(4) and not fastio_wdata(4);
              iec_irq(3 downto 0) <= fastio_wdata(3 downto 0);
            when x"8" => -- Write to command register
              iec_cmd <= fastio_wdata;
              iec_new_cmd <= '1';
            when x"9" => -- Write to data register
              iec_data_out <= fastio_wdata;
            when x"a" => -- Write device info
            when others => null;
          end case;
        end if;
      end if;

      if iec_new_cmd='1' then
        iec_new_cmd <= '0';
        case iec_cmd is
          -- Low-level / bitbashing commands
          when x"41" => -- ATN to +5V
            iec_atn <= '1';              
          when x"61" => -- ATN low to 0V
            iec_atn <= '0';              
          when x"43" => -- CLK line +5V (bitbashing)
            iec_clk_o <= '1'; iec_clk_en <= '1';
          when x"63" => -- Pull CLK line low to 0V (bitbashing)
            iec_clk_o <= '0'; iec_clk_en <= '0';
          when x"44" => -- DATA line to +5V (bitbashing)
            iec_data_o <= '1'; iec_data_en <= '1';
          when x"64" => -- Pull DATA line low to 0V (bitbashing)
            iec_data_o <= '0'; iec_data_en <= '0';
          when x"53" => -- SRQ line to +5V (bitbashing)
            iec_srq_o <= '1'; iec_srq_en <= '1';
          when x"73" => -- Pull SRQ line low to 0V (bitbashing)
            iec_srq_o <= '0'; iec_srq_en <= '0';

            -- Protocol level commands
          when x"30" => -- Request device attention (send data byte under attention)
            iec_dev_listening <= '1';
            iec_state <= 100;
            iec_busy <= '1';
          when x"31" => -- Send byte
            iec_dev_listening <= '1';
          when x"32" => -- Receive byte
            iec_dev_listening <= '0';
          when x"33" => -- Send EOI without byte
          when x"34" => -- Send byte with EOI
          when x"35" => -- Turn around from talk to listen
            iec_dev_listening <= '0';
          when others => null;
        end case;
      end if;

      -- Update usec and msec denominated count-downs
      if usec_toggle /= last_usec_toggle then
        if wait_usec > 0 then
          wait_usec <= wait_usec - 1;
        end if;
        usec_toggle <= last_usec_toggle;
      end if;
      if msec_toggle /= last_msec_toggle then
        if wait_usec > 0 then
          wait_msec <= wait_msec - 1;
        end if;
        msec_toggle <= last_msec_toggle;
      end if;
      
      -- Advance state in IEC protocol transaction if the requirements are met
      if (iec_state >0)
        and (wait_clk_low='0' or iec_clk_i='0')
        and (wait_clk_high='0' or iec_clk_i='1')
        and (wait_data_low='0' or iec_data_i='0')
        and (wait_data_high='0' or iec_data_i='1')
        and (wait_srq_low='0' or iec_srq_i='0')
        and (wait_srq_high='0' or iec_srq_i='1')
        and (wait_usec = 0) and (wait_msec = 0 )
      then
        iec_state <= iec_state + 1;
      end if;
      case iec_state is
        -- IDLE state
        when 0 => null;

        -- Request attention from one or more devices
        when 100 =>

          iec_under_attention <= '0';
          
          -- DATA to 5V
          iec_data_o <= '1'; iec_data_en <= '1';
          -- Ensure SRQ is released to 5V
          iec_srq_o <= '1'; iec_srq_en <= '1';

          -- Skip C= fast serial signal if a device is
          -- listening, so that it doesn't get mis-interpretted
          -- as data.
          -- XXX - Actually only required if the device supports
          -- C= fast serial?
          if iec_dev_listening='1' then
            iec_state <= 120;
          end if;

          -- Send data byte $FF using SRQ as clock to indicate our ability
          -- to do C= fast serial
        when 101 => iec_srq_o <= '1'; iec_srq_en <= '1'; wait_usec <= 5;
        when 102 => iec_srq_o <= '0'; iec_srq_en <= '0'; wait_usec <= 5;
        when 103 => iec_srq_o <= '1'; iec_srq_en <= '1'; wait_usec <= 5;
        when 104 => iec_srq_o <= '0'; iec_srq_en <= '0'; wait_usec <= 5;
        when 105 => iec_srq_o <= '1'; iec_srq_en <= '1'; wait_usec <= 5;
        when 106 => iec_srq_o <= '0'; iec_srq_en <= '0'; wait_usec <= 5;
        when 107 => iec_srq_o <= '1'; iec_srq_en <= '1'; wait_usec <= 5;
        when 108 => iec_srq_o <= '0'; iec_srq_en <= '0'; wait_usec <= 5;
        when 109 => iec_srq_o <= '1'; iec_srq_en <= '1'; wait_usec <= 5;
        when 110 => iec_srq_o <= '0'; iec_srq_en <= '0'; wait_usec <= 5;
        when 111 => iec_srq_o <= '1'; iec_srq_en <= '1'; wait_usec <= 5;
        when 112 => iec_srq_o <= '0'; iec_srq_en <= '0'; wait_usec <= 5;
        when 113 => iec_srq_o <= '1'; iec_srq_en <= '1'; wait_usec <= 5;
        when 114 => iec_srq_o <= '0'; iec_srq_en <= '0'; wait_usec <= 5;
        when 115 => iec_srq_o <= '1'; iec_srq_en <= '1'; wait_usec <= 5;
        when 116 => iec_srq_o <= '0'; iec_srq_en <= '0'; wait_usec <= 5;
          
        when 120 =>
          -- ATN to 0V
          iec_atn <= '0';
          -- CLK to 0V
          iec_clk_o <= '0'; iec_clk_en <= '0';
          -- DATA to 5V
          iec_data_o <= '1'; iec_data_en <= '1';
          -- Ensure SRQ is released to 5V
          iec_srq_o <= '1'; iec_srq_en <= '1';

          -- Clear relevant status bits
          iec_status(7) <= '0'; -- no DEVICE NOT FOUND error (yet)
          iec_status(1) <= '0'; -- No timeout
          iec_status(0) <= '0'; -- No data direction during timeout

          -- And also device info byte
          iec_devinfo(7) <= '0'; -- Device not (yet) detected
          iec_devinfo(6 downto 5) <= "00"; -- slow protocol
          -- Device ID being requested
          iec_devinfo(4 downto 0) <= iec_data_out(4 downto 0);

          -- Wait upto 1ms for DATA to go low
          wait_msec <= 1;
          
        when 121 =>
          if iec_data_i = '0' then
            iec_state <= 123; -- Proceed with ATN send
          end if;
        when 122 =>
          -- Timeout has occurred: DEVICE NOT PRESENT
          -- (actually it means that there are no devices at all)
          iec_state <= 0;
          iec_busy <= '0';
          iec_devinfo <= x"00";
          iec_status(7) <= '1'; -- DEVICE NOT PRESENT
          iec_status(1) <= '1'; -- TIMEOUT OCCURRED ...
          iec_status(0) <= '1'; -- ... WHILE WE WERE TALKING          

          -- Release all IEC lines
          iec_atn <= '1';
          iec_clk_o <= '1'; iec_clk_en <= '1';

          iec_busy <= '0';
          
        when 123 =>
          -- At least one device has responded

          -- CLK to 5V
          iec_clk_o <= '1'; iec_clk_en <= '1';

          -- Now wait upto 64ms for listener ready for data
          -- This period is actually unconstrained in the protcol,
          -- but we place a limit on it for now.
          wait_msec <= 64;

        when 124 =>
          if iec_data_i='1' then
            -- Listener ready for data
            iec_state <= 126;
          end if;
        when 125 =>
          -- Timeout on listener ready for data
          
          -- Timeout has occurred: DEVICE NOT PRESENT
          -- (which is not strictly true, it's that device
          -- did not respond in time)
          iec_state <= 0;
          iec_busy <= '0';
          iec_devinfo <= x"00";
          iec_status(7) <= '1'; -- DEVICE NOT PRESENT
          iec_status(1) <= '1'; -- TIMEOUT OCCURRED ...
          iec_status(0) <= '1'; -- ... WHILE WE WERE TALKING

          -- Release all IEC lines
          iec_atn <= '1';
          iec_clk_o <= '1'; iec_clk_en <= '1';

        when 126 =>
          -- Okay, all listeners are ready for the data byte.
          -- So send it using the slow protocol.
          -- After sending 7th bit, we do the JiffyDOS(tm) check
          -- by delaying, and waiting to see if the data line
          -- is pulled low by a device, indicating that it speaks
          -- the JiffyDOS protocol.  More on that when we get to it.

          -- Send the first 7 bits
        when 127 => iec_clk_o <= '0'; iec_clk_en <= '0'; iec_data_o <= '1'; iec_data_en <= '1'; wait_usec <= 5;
        when 128 => iec_clk_o <= '0'; iec_clk_en <= '0'; iec_data_o <= iec_data_out(0); iec_data_en <= iec_data_out(0); wait_usec <= 15;
        when 129 => iec_clk_o <= '1'; iec_clk_en <= '1'; iec_data_o <= iec_data_out(0); iec_data_en <= iec_data_out(0); wait_usec <= 20;
                    -- Rotate byte being sent completely, so repeated sending
                    -- of same byte is possible without having to re-write it.
                    iec_data_out(6 downto 0) <= iec_data_out(7 downto 1); iec_data_out(7) <= iec_data_out(0);
        when 130 => iec_clk_o <= '0'; iec_clk_en <= '0'; iec_data_o <= '1'; iec_data_en <= '1'; wait_usec <= 5;
        when 131 => iec_clk_o <= '0'; iec_clk_en <= '0'; iec_data_o <= iec_data_out(0); iec_data_en <= iec_data_out(0); wait_usec <= 15;
        when 132 => iec_clk_o <= '1'; iec_clk_en <= '1'; iec_data_o <= iec_data_out(0); iec_data_en <= iec_data_out(0); wait_usec <= 20;
                    iec_data_out(6 downto 0) <= iec_data_out(7 downto 1); iec_data_out(7) <= iec_data_out(0);
        when 133 => iec_clk_o <= '0'; iec_clk_en <= '0'; iec_data_o <= '1'; iec_data_en <= '1'; wait_usec <= 5;
        when 134 => iec_clk_o <= '0'; iec_clk_en <= '0'; iec_data_o <= iec_data_out(0); iec_data_en <= iec_data_out(0); wait_usec <= 15;
        when 135 => iec_clk_o <= '1'; iec_clk_en <= '1'; iec_data_o <= iec_data_out(0); iec_data_en <= iec_data_out(0); wait_usec <= 20;
                    iec_data_out(6 downto 0) <= iec_data_out(7 downto 1); iec_data_out(7) <= iec_data_out(0);
        when 136 => iec_clk_o <= '0'; iec_clk_en <= '0'; iec_data_o <= '1'; iec_data_en <= '1'; wait_usec <= 5;
        when 137 => iec_clk_o <= '0'; iec_clk_en <= '0'; iec_data_o <= iec_data_out(0); iec_data_en <= iec_data_out(0); wait_usec <= 15;
        when 138 => iec_clk_o <= '1'; iec_clk_en <= '1'; iec_data_o <= iec_data_out(0); iec_data_en <= iec_data_out(0); wait_usec <= 20;
                    iec_data_out(6 downto 0) <= iec_data_out(7 downto 1); iec_data_out(7) <= iec_data_out(0);
        when 139 => iec_clk_o <= '0'; iec_clk_en <= '0'; iec_data_o <= '1'; iec_data_en <= '1'; wait_usec <= 5;
        when 140 => iec_clk_o <= '0'; iec_clk_en <= '0'; iec_data_o <= iec_data_out(0); iec_data_en <= iec_data_out(0); wait_usec <= 15;
        when 141 => iec_clk_o <= '1'; iec_clk_en <= '1'; iec_data_o <= iec_data_out(0); iec_data_en <= iec_data_out(0); wait_usec <= 20;
                    iec_data_out(6 downto 0) <= iec_data_out(7 downto 1); iec_data_out(7) <= iec_data_out(0);
        when 142 => iec_clk_o <= '0'; iec_clk_en <= '0'; iec_data_o <= '1'; iec_data_en <= '1'; wait_usec <= 5;
        when 143 => iec_clk_o <= '0'; iec_clk_en <= '0'; iec_data_o <= iec_data_out(0); iec_data_en <= iec_data_out(0); wait_usec <= 15;
        when 144 => iec_clk_o <= '1'; iec_clk_en <= '1'; iec_data_o <= iec_data_out(0); iec_data_en <= iec_data_out(0); wait_usec <= 20;
                    iec_data_out(6 downto 0) <= iec_data_out(7 downto 1); iec_data_out(7) <= iec_data_out(0);
        when 145 => iec_clk_o <= '0'; iec_clk_en <= '0'; iec_data_o <= '1'; iec_data_en <= '1'; wait_usec <= 5;
        when 146 => iec_clk_o <= '0'; iec_clk_en <= '0'; iec_data_o <= iec_data_out(0); iec_data_en <= iec_data_out(0); wait_usec <= 15;
        when 147 => iec_clk_o <= '1'; iec_clk_en <= '1'; iec_data_o <= iec_data_out(0); iec_data_en <= iec_data_out(0); wait_usec <= 20;
                    iec_data_out(6 downto 0) <= iec_data_out(7 downto 1); iec_data_out(7) <= iec_data_out(0);
           -- Now we have sent 7 bits, release data, keeping clock at 0V, and
           -- check for DATA being pulled low
        when 148 => iec_clk_o <= '0'; iec_clk_en <= '0'; iec_data_o <= '1'; iec_data_en <= '1';
                    wait_usec <= 500; 
        when 149 =>
          -- Data went low: device speaks JiffyDOS protocol
          if iec_data_i='0' then
            -- Record JiffyDOS capability
            iec_devinfo(6 downto 5) <= "10";
            -- Wait for DATA to be released again
            wait_usec <= 0; wait_data_high <= '1';
          end if;
        when 150 => iec_clk_o <= '0'; iec_clk_en <= '0'; iec_data_o <= iec_data_out(0); iec_data_en <= iec_data_out(0); wait_usec <= 15;
        when 151 => iec_clk_o <= '1'; iec_clk_en <= '1'; iec_data_o <= iec_data_out(0); iec_data_en <= iec_data_out(0); wait_usec <= 20;
                    iec_data_out(6 downto 0) <= iec_data_out(7 downto 1); iec_data_out(7) <= iec_data_out(0);
        when 152 => iec_clk_o <= '0'; iec_clk_en <= '0'; iec_data_o <= '1'; iec_data_en <= '1';
                    -- Allow device 1000usec = 1ms to acknowledge byte by
                    -- pulling data low
                    wait_msec <= 1;
        when 153 =>
          if iec_data_i='0' then
            iec_state <= 155;
          end if;
        when 154 =>
          -- Timeout detected acknowledging byte

          -- Timeout has occurred: DEVICE NOT PRESENT
          -- (which is not strictly true, it's that device
          -- did not respond in time)
          iec_state <= 0;
          iec_devinfo <= x"00";
          iec_status(7) <= '1'; -- DEVICE NOT PRESENT
          iec_status(1) <= '1'; -- TIMEOUT OCCURRED ...
          iec_status(0) <= '1'; -- ... WHILE WE WERE TALKING

          -- Release all IEC lines
          iec_atn <= '1';
          iec_clk_o <= '1'; iec_clk_en <= '1';

        when 155 =>
          -- Successfully sent byte
          iec_devinfo(7) <= '1';
          iec_busy <= '0';

          -- And we are still under attention
          iec_under_attention <= '1';
          iec_devinfo(4) <= '1'; 
          
        when others => iec_state <= 0; iec_busy <= '0';
      end case;  
      
    end if;
  end process;
  
  
end questionable;
