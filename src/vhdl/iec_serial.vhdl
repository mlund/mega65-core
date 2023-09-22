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
  signal iec_devinfo : unsigned(7 downto 0) := x"00";

  signal iec_cmd : unsigned(7 downto 0) := x"00";
  signal iec_new_cmd : std_logic := '0';
  
begin

  -- Note that we put RX on bit 6, so that the common case of LOADing can be a
  -- little faster, by allowing BIT $D697 / BVC *-3 to be a very tight loop
  -- for waiting for bytes.

  -- @IO:GS $D697.7 AUTOIEC:IRQFLAG Interrupt flag. Set if any IRQ event is triggered.
  -- @IO:GS $D697.6 AUTOIEC:IRQRX Set if a byte has been received from a listener.
  -- @IO:GS $D697.5 AUTOIEC:IRQTX Set if ready to transmit a byte to a listener.
  -- @IO:GS $D697.4 AUTOIEC:IRQTO Set if a protocol timeout has occurred, e.g., device not found.
  -- @IO:GS $D697.3 AUTOIEC:IRQEN Enable interrupts if set
  -- @IO:GS $D697.2 AUTOIEC:IRQTXEN Enable RX interrupt source if set
  -- @IO:GS $D697.1 AUTOIEC:IRQRXEN Enable TX interrupt source if set
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
  -- @IO:GS $D69A.6 AUTOIEC:DIFAST Device fast serial mode selected
  -- @IO:GS $D69A.5 AUTOIEC:DIJDOS Device JiffyDOS(tm) serial mode selected
  -- @IO:GS $D69A.4 AUTOIEC:DIPORPOSE Device DolphinDOS(tm) serial mode selected
  -- @IO:GS $D69A.3 AUTOIEC:DI3 Reserved
  -- @IO:GS $D69A.2 AUTOIEC:DI2 Reserved
  -- @IO:GS $D69A.1 AUTOIEC:DI1 Reserved
  -- @IO:GS $D69A.0 AUTOIEC:DI0 Reserved
  
  process (clock) is
  begin

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
          when x"49" => -- Send L(I)STEN Secondary address (= KERNAL $FF93)
          when x"4b" => -- Send TAL(K) Secondary address (= KERNAL $FF96)
          when x"4d" => -- Set 64ms timeout on bus actions (=KERNAL $FFA2)
          when x"6d" => -- Disable 64ms timeout on bus actions (=KERNAL $FFA2)
          when x"52" => -- Read byte from IEC bus (assumes TALK, TALKSA
                      -- already done) (=KERNAL $FFA5)
          when x"57" => -- Write byte to IEC bus (assumes LISTEN, LISTENSA
                      -- already done) (=KERNAL $FFA8)
          when x"74" => -- Send UNTALK command to IEC bus (=KERNAL $FFAB)
          when x"6c" => -- Send UNLISTEN command to IEC bus (=KERNAL $FFAE)
          when x"4c" => -- Send LISTEN command to IEC bus (=KERNAL $FFB1)
          when x"54" => -- Send TALK command to IEC bus (=KERNAL $FFB4)
          when x"55" => -- Turn around from TALK to LISTEN (should this just
                        -- happen as part of the TALK command?)
          when others => null;
        end case;
      end if;
      
    end if;
  end process;
  
  
end questionable;
