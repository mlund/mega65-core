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
    iec_srq_i : in std_logic;
    
    );
end iec_serial;

architecture questionable of iec_serial is

  signal iec_irq : unsigned(7 downto 0) := x"00";
  signal iec_status : unsigned(7 downto 0) := x"00";
  signal iec_data : unsigned(7 downto 0) := x"00";
  signal iec_devinfo : unsigned(7 downto 0) := x"00";
begin

  -- @IO:GS $D697.7 AUTOIEC:IRQFLAG Interrupt flag. Set if any IRQ event is triggered.
  -- @IO:GS $D697.6 AUTOIEC:IRQTX Set if ready to transmit a byte to a listener.
  -- @IO:GS $D697.5 AUTOIEC:IRQRX Set if a byte has been received from a listener.
  -- @IO:GS $D697.4 AUTOIEC:IRQTO Set if a protocol timeout has occurred, e.g., device not found.
  -- @IO:GS $D697.3 AUTOIEC:IRQEN Enable interrupts if set
  -- @IO:GS $D697.2 AUTOIEC:IRQTXEN Enable TX interrupt source if set
  -- @IO:GS $D697.1 AUTOIEC:IRQRXEN Enable RX interrupt source if set
  -- @IO:GS $D697.0 AUTOIEC:IRQTOEN Enable timeout interrupt source if set
  
  -- @IO:GS $D698.7 AUTOIEC:STNODEV Device not present
  -- @IO:GS $D698.6 AUTOIEC:STNOEOF End of file
  -- @IO:GS $D698.5 AUTOIEC:ST5 Reserved
  -- @IO:GS $D698.4 AUTOIEC:STVERIFY Verify error occurred
  -- @IO:GS $D698.3 AUTOIEC:ST3 Reserved
  -- @IO:GS $D698.2 AUTOIEC:ST2 Reserved
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
        and (to_integer(fastio_addr(3 downto 0))>6 and to_integer(fastio_addr(3 downto 0)<11)) 
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
      if fastio_addr(19 downto 4) = x"d369"
        and (to_integer(fastio_addr(3 downto 0))>6 and to_integer(fastio_addr(3 downto 0)<11)) then
        if fastio_write='1' then
          case fastio_addr(3 downto 0) is
            when x"7" => -- Write to IRQ register
            when x"8" => -- Write to command register
            when x"9" => -- Write to data register
            when x"a" => -- Write device info
            when others => null;
          end case;
        end if;
      end if;
    end if;
  end process;
  
  
end questionable;
