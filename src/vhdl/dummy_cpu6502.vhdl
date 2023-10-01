
use WORK.ALL;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use Std.TextIO.all;
use work.debugtools.all;
use work.cputypes.all;
use work.victypes.all;

entity cpu6502 is 
  port (
    address : buffer unsigned(15 downto 0);
    address_next : out unsigned(15 downto 0);
    clk : in std_logic;
    cpu_int : out std_logic;
    cpu_state_o : out unsigned(7 downto 0);
    data_i : in unsigned(7 downto 0);
    data_o : out unsigned(7 downto 0);
    data_o_next : out unsigned(7 downto 0);
    irq : in std_logic;
    nmi : in std_logic;
    ready : in std_logic;
    reset : in std_logic;
    sync : buffer std_logic;
    t : out unsigned(2 downto 0);
    write : out std_logic;
    write_next : buffer std_logic
    );
end entity cpu6502;

architecture vapourware of cpu6502 is

  constant instruction_lut : ilut8bit := (

    -- 6502 personality
    -- MAP is not available here. To MAP from 6502 mode, you have to first
    -- enable 4502 mode by switching VIC-III/IV IO mode from VIC-II.
    I_BRK,I_ORA,I_KIL,I_SLO,I_NOP,I_ORA,I_ASL,I_SLO,I_PHP,I_ORA,I_ASL,I_ANC,I_NOP,I_ORA,I_ASL,I_SLO,
    I_BPL,I_ORA,I_KIL,I_SLO,I_NOP,I_ORA,I_ASL,I_SLO,I_CLC,I_ORA,I_NOP,I_SLO,I_NOP,I_ORA,I_ASL,I_SLO,
    I_JSR,I_AND,I_KIL,I_RLA,I_BIT,I_AND,I_ROL,I_RLA,I_PLP,I_AND,I_ROL,I_ANC,I_BIT,I_AND,I_ROL,I_RLA,
    I_BMI,I_AND,I_KIL,I_RLA,I_NOP,I_AND,I_ROL,I_RLA,I_SEC,I_AND,I_NOP,I_RLA,I_NOP,I_AND,I_ROL,I_RLA,
    I_RTI,I_EOR,I_KIL,I_SRE,I_NOP,I_EOR,I_LSR,I_SRE,I_PHA,I_EOR,I_LSR,I_ALR,I_JMP,I_EOR,I_LSR,I_SRE,
    I_BVC,I_EOR,I_KIL,I_SRE,I_NOP,I_EOR,I_LSR,I_SRE,I_CLI,I_EOR,I_NOP,I_SRE,I_NOP,I_EOR,I_LSR,I_SRE,
    I_RTS,I_ADC,I_KIL,I_RRA,I_NOP,I_ADC,I_ROR,I_RRA,I_PLA,I_ADC,I_ROR,I_ARR,I_JMP,I_ADC,I_ROR,I_RRA,
    I_BVS,I_ADC,I_KIL,I_RRA,I_NOP,I_ADC,I_ROR,I_RRA,I_SEI,I_ADC,I_NOP,I_RRA,I_NOP,I_ADC,I_ROR,I_RRA,
    I_NOP,I_STA,I_NOP,I_SAX,I_STY,I_STA,I_STX,I_SAX,I_DEY,I_NOP,I_TXA,I_XAA,I_STY,I_STA,I_STX,I_SAX,
    I_BCC,I_STA,I_KIL,I_AHX,I_STY,I_STA,I_STX,I_SAX,I_TYA,I_STA,I_TXS,I_TAS,I_SHY,I_STA,I_SHX,I_AHX,
    I_LDY,I_LDA,I_LDX,I_LAX,I_LDY,I_LDA,I_LDX,I_LAX,I_TAY,I_LDA,I_TAX,I_LAX,I_LDY,I_LDA,I_LDX,I_LAX,
    I_BCS,I_LDA,I_KIL,I_LAX,I_LDY,I_LDA,I_LDX,I_LAX,I_CLV,I_LDA,I_TSX,I_LAS,I_LDY,I_LDA,I_LDX,I_LAX,
    I_CPY,I_CMP,I_NOP,I_DCP,I_CPY,I_CMP,I_DEC,I_DCP,I_INY,I_CMP,I_DEX,I_AXS,I_CPY,I_CMP,I_DEC,I_DCP,
    I_BNE,I_CMP,I_KIL,I_DCP,I_NOP,I_CMP,I_DEC,I_DCP,I_CLD,I_CMP,I_NOP,I_DCP,I_NOP,I_CMP,I_DEC,I_DCP,
    I_CPX,I_SBC,I_NOP,I_ISC,I_CPX,I_SBC,I_INC,I_ISC,I_INX,I_SBC,I_NOP,I_SBC,I_CPX,I_SBC,I_INC,I_ISC,
    I_BEQ,I_SBC,I_KIL,I_ISC,I_NOP,I_SBC,I_INC,I_ISC,I_SED,I_SBC,I_NOP,I_ISC,I_NOP,I_SBC,I_INC,I_ISC
    );

  type mlut8bit is array(0 to 255) of addressingmode;
  constant mode_lut : mlut8bit := (
    -- 6502 personality
    M_impl,  M_InnX,  M_impl,  M_InnX,  M_nn,    M_nn,    M_nn,    M_nn,
    M_impl,  M_immnn, M_impl,  M_immnn, M_nnnn,  M_nnnn,  M_nnnn,  M_nnnn,
    M_rr,    M_InnY,  M_impl,  M_InnY,  M_nnX,   M_nnX,   M_nnX,   M_nnX,
    M_impl,  M_nnnnY, M_impl,  M_nnnnY, M_nnnnX, M_nnnnX, M_nnnnX, M_nnnnX,
    M_nnnn,  M_InnX,  M_impl,  M_InnX,  M_nn,    M_nn,    M_nn,    M_nn,
    M_impl,  M_immnn, M_impl,  M_immnn, M_nnnn,  M_nnnn,  M_nnnn,  M_nnnn,
    M_rr,    M_InnY,  M_impl,  M_InnY,  M_nnX,   M_nnX,   M_nnX,   M_nnX,
    M_impl,  M_nnnnY, M_impl,  M_nnnnY, M_nnnnX, M_nnnnX, M_nnnnX, M_nnnnX,
    M_impl,  M_InnX,  M_impl,  M_InnX,  M_nn,    M_nn,    M_nn,    M_nn,
    M_impl,  M_immnn, M_impl,  M_immnn, M_nnnn,  M_nnnn,  M_nnnn,  M_nnnn,
    M_rr,    M_InnY,  M_impl,  M_InnY,  M_nnX,   M_nnX,   M_nnX,   M_nnX,
    M_impl,  M_nnnnY, M_impl,  M_nnnnY, M_nnnnX, M_nnnnX, M_nnnnX, M_nnnnX,
    M_impl,  M_InnX,  M_impl,  M_InnX,  M_nn,    M_nn,    M_nn,    M_nn,
    M_impl,  M_immnn, M_impl,  M_immnn, M_Innnn, M_nnnn,  M_nnnn,  M_nnnn,
    M_rr,    M_InnY,  M_impl,  M_InnY,  M_nnX,   M_nnX,   M_nnX,   M_nnX,
    M_impl,  M_nnnnY, M_impl,  M_nnnnY, M_nnnnX, M_nnnnX, M_nnnnX, M_nnnnX,
    M_immnn, M_InnX,  M_immnn, M_InnX,  M_nn,    M_nn,    M_nn,    M_nn,
    M_impl,  M_immnn, M_impl,  M_immnn, M_nnnn,  M_nnnn,  M_nnnn,  M_nnnn,
    M_rr,    M_InnY,  M_impl,  M_InnY,  M_nnX,   M_nnX,   M_nnY,   M_nnY,
    M_impl,  M_nnnnY, M_impl,  M_nnnnY, M_nnnnX, M_nnnnX, M_nnnnY, M_nnnnY,
    M_immnn, M_InnX,  M_immnn, M_InnX,  M_nn,    M_nn,    M_nn,    M_nn,
    M_impl,  M_immnn, M_impl,  M_immnn, M_nnnn,  M_nnnn,  M_nnnn,  M_nnnn,
    M_rr,    M_InnY,  M_impl,  M_InnY,  M_nnX,   M_nnX,   M_nnY,   M_nnY,
    M_impl,  M_nnnnY, M_impl,  M_nnnnY, M_nnnnX, M_nnnnX, M_nnnnY, M_nnnnY,
    M_immnn, M_InnX,  M_immnn, M_InnX,  M_nn,    M_nn,    M_nn,    M_nn,
    M_impl,  M_immnn, M_impl,  M_immnn, M_nnnn,  M_nnnn,  M_nnnn,  M_nnnn,
    M_rr,    M_InnY,  M_impl,  M_InnY,  M_nnX,   M_nnX,   M_nnX,   M_nnX,
    M_impl,  M_nnnnY, M_impl,  M_nnnnY, M_nnnnX, M_nnnnX, M_nnnnX, M_nnnnX,
    M_immnn, M_InnX,  M_immnn, M_InnX,  M_nn,    M_nn,    M_nn,    M_nn,
    M_impl,  M_immnn, M_impl,  M_immnn, M_nnnn,  M_nnnn,  M_nnnn,  M_nnnn,
    M_rr,    M_InnY,  M_impl,  M_InnY,  M_nnX,   M_nnX,   M_nnX,   M_nnX,
    M_impl,  M_nnnnY, M_impl,  M_nnnnY, M_nnnnX, M_nnnnX, M_nnnnX, M_nnnnX);    

  type cpu_state_t is (
    poreset,
    interrupt,
    vector0,
    vector1,
    opcode_fetch,
    idecode,
    byte2_fetch,
    byte3_fetch,
    load,
    store,
    rmw_store1,
    rmw_store2
    );

  signal cpu_state : cpu_state_t := poreset;
  
  signal reg_pc : unsigned(15 downto 0) := x"FFFC";
  signal reg_a : unsigned(7 downto 0) := x"00";
  signal reg_x : unsigned(7 downto 0) := x"00";
  signal reg_y : unsigned(7 downto 0) := x"00";
  signal reg_sp : unsigned(7 downto 0) := x"00";
  signal flag_z : std_logic := '0';
  signal flag_d : std_logic := '0';
  signal flag_c : std_logic := '0';
  signal flag_i : std_logic := '0';
  signal flag_v : std_logic := '0';    
  signal flag_n : std_logic := '0';    

  signal nmi_pending : std_logic := '0';
  signal last_nmi : std_logic := '1';
  signal reg_mode : addressingmode := M_IMPL;
  signal reg_opcode : unsigned(7 downto 0) := x"00";
  signal reg_instruction : instruction := I_NOP;

  signal reg_addr : unsigned(15 downto 0) := to_unsigned(0,16);
  signal reg_x_dec : unsigned(7 downto 0);
  signal reg_y_dec : unsigned(7 downto 0);
  signal reg_x_inc : unsigned(7 downto 0);
  signal reg_y_inc : unsigned(7 downto 0);
  signal reg_addr_x : unsigned(8 downto 0);
  signal reg_addr_y : unsigned(8 downto 0);
  
begin
  process (clk) is

    variable virt_flags : unsigned(7 downto 0);
    variable branch_addr : unsigned(15 downto 0);
    
    procedure set_nz(d : unsigned(7 downto 0)) is
    begin
      flag_n <= d(7);
      if d = x"00" then
        flag_z <= '1';
      else
        flag_z <= '0';
      end if;
    end procedure;

    procedure take_branch is
    begin
      report "Taking branch to $" & to_hexstring(branch_addr);
      reg_pc <= branch_addr;
      cpu_state <= opcode_fetch;
    end procedure;
  begin

    if rising_edge(clk) then

      if data_i(7)='0' then
        branch_addr := reg_pc + to_integer(data_i);
      else
        branch_addr := reg_pc - 128 + to_integer(data_i(6 downto 0));
      end if;
      
      virt_flags(7) := flag_n;
      virt_flags(6) := flag_v;
      virt_flags(5) := '1';
      virt_flags(4) := '0';
      virt_flags(3) := flag_d;
      virt_flags(2) := flag_i;
      virt_flags(1) := flag_z;
      virt_flags(0) := flag_c;

      reg_x_inc <= reg_x + 1;
      reg_x_dec <= reg_x - 1;
      reg_y_inc <= reg_y + 1;
      reg_y_dec <= reg_y - 1;
      reg_addr_x <= to_unsigned(to_integer(reg_addr(7 downto 0)) + to_integer(reg_x),9);
      reg_addr_y <= to_unsigned(to_integer(reg_addr(7 downto 0)) + to_integer(reg_y),9);
      
      last_nmi <= nmi;
      if nmi='0' and last_nmi='1' then
        nmi_pending <= '1';
      end if;    

      -- Export debug status of CPU
      cpu_state_o <= to_unsigned(cpu_state_t'pos(cpu_state),8);
      address_next <= reg_pc;
      
      write <= '1';
      
      if ready='1' then
        report("1541CPU: Clock ticks, state=" & cpu_state_t'image(cpu_state)
               & ", data_i = $" & to_hexstring(data_i)
               & ", addr=$" & to_hexstring(address));

        -- By default, fetch next instruction byte
        address <= reg_pc;
        
        case cpu_state is
          when poreset =>
            address <= x"FFFC";
            report "1541CPU: Power-on RESET commenced";
            cpu_state <= vector0;
          when interrupt =>
            address <= x"FFF8";
            if reset='0' then
              address(3 downto 0) <= x"c";
              report "1541CPU: RESET commenced";
            elsif nmi_pending='1' then
              address(3 downto 0) <= x"a";
              report "1541CPU: NMI commenced";
              nmi_pending <= '0';
            else
              address(3 downto 0) <= x"e";
              report "1541CPU: IRQ commenced";
            end if;
            cpu_state <= vector0;

          when vector0 =>
            reg_pc(7 downto 0) <= data_i;
            address(0) <= '1';
            cpu_state <= vector1;
          when vector1 =>
            reg_pc(15 downto 8) <= data_i;
            address <= address;
            address(0) <= '1';
            cpu_state <= opcode_fetch;
            report "1541CPU: Read interrupt vector. Jumping to $" & to_hexstring(data_i) & to_hexstring(reg_pc(7 downto 0));
          when opcode_fetch =>
            if irq='0' or nmi='0' or reset='0' then
              cpu_state <= interrupt;
            else
              reg_pc <= reg_pc + 1;
              cpu_state <= idecode;
            end if;

          when idecode =>
            cpu_state <= byte2_fetch;
            reg_opcode <= data_i;
            reg_instruction <= instruction_lut(to_integer(data_i));
            reg_mode <= mode_lut(to_integer(data_i));
            report "PC: $" & to_hexstring(reg_pc) & ", A:" & to_hexstring(reg_a) & ", X:" & to_hexstring(reg_x)
              & ", Y:" & to_hexstring(reg_y) & ", SP:" & to_hexstring(reg_sp)
              & " NVxBDIZC=" & to_string(virt_flags) & ", " &
              " Decoding " & instruction'image(instruction_lut(to_integer(data_i)))
              & ", mode = " & addressingmode'image(mode_lut(to_integer(data_i)));
            case mode_lut(to_integer(data_i)) is
              when M_IMPL =>
                cpu_state <= opcode_fetch;
                case instruction_lut(to_integer(data_i)) is
                  when I_CLC => flag_c <= '0';
                  when I_CLD => flag_d <= '0';
                  when I_CLI => flag_i <= '0';
                  when I_DEX => reg_x <= reg_x_dec; set_nz(reg_x_dec);
                  when I_DEY => reg_y <= reg_y_dec; set_nz(reg_y_dec);
                  when I_INX => reg_x <= reg_x_inc; set_nz(reg_x_inc);
                  when I_INY => reg_y <= reg_y_inc; set_nz(reg_y_inc);
                  when I_NOP => null;
                  when I_SEC => flag_c <= '1';
                  when I_SED => flag_d <= '1';
                  when I_SEI => flag_i <= '1';
                  when I_TAX => reg_x <= reg_a; set_nz(reg_a);
                  when I_TAY => reg_y <= reg_a; set_nz(reg_a);
                  when I_TXA => reg_a <= reg_x; set_nz(reg_x);
                  when I_TYA => reg_a <= reg_y; set_nz(reg_y);
                                
                  when others =>
                    assert false report "Unimplemented implied mode instruction " & instruction'image(instruction_lut(to_integer(data_i)));
                end case;
              when others =>
                reg_pc <= reg_pc + 1;
            end case;
          when byte2_fetch =>
            reg_addr(7 downto 0) <= data_i;
            cpu_state <= byte3_fetch;
            case reg_mode is
              when M_IMMNN =>
                reg_pc <= reg_pc + 1;
                case reg_instruction is
                  when I_LDA => reg_a <= data_i; set_nz(data_i); cpu_state <= idecode;
                  when I_LDX => reg_x <= data_i; set_nz(data_i); cpu_state <= idecode;
                  when I_LDY => reg_y <= data_i; set_nz(data_i); cpu_state <= idecode;
                  when others =>
                    assert false report "Unimplemented immediate mode instruction " & instruction'image(reg_instruction);
                end case;
              when M_NN | M_NNX | M_NNY =>
                case reg_mode is
                  when M_NN => address(7 downto 0) <= to_unsigned(0 + to_integer(data_i),8);
                  when M_NNX => address(7 downto 0) <= to_unsigned(0 + to_integer(reg_x) + to_integer(data_i),8);
                  when M_NNY => address(7 downto 0) <= to_unsigned(0 + to_integer(reg_y) + to_integer(data_i),8);
                  when others => null;
                end case;
                case reg_instruction is
                  when I_STA => data_o <= reg_a; write <= '1'; cpu_state <= opcode_fetch;
                  when I_STX => data_o <= reg_x; write <= '1'; cpu_state <= opcode_fetch;
                  when I_STY => data_o <= reg_y; write <= '1'; cpu_state <= opcode_fetch;
                  when others =>
                    assert false report "Unimplemented zeropage mode instruction " & instruction'image(reg_instruction);
                end case;
--              when M_INNX | M_INNY =>
              when M_RR =>
                -- XXX Doesn't charge extra cycle for crossing page boundary
                cpu_state <= idecode;
                case reg_instruction is
                  when I_BNE => if flag_z='0' then take_branch; end if;
                  when I_BEQ => if flag_z='1' then take_branch; end if;
                  when I_BCC => if flag_c='0' then take_branch; end if;
                  when I_BCS => if flag_c='1' then take_branch; end if;
                  when I_BMI => if flag_n='1' then take_branch; end if;
                  when I_BPL => if flag_n='0' then take_branch; end if;
                  when I_BVS => if flag_v='1' then take_branch; end if;
                  when I_BVC => if flag_v='0' then take_branch; end if;
                  when others =>
                    assert false report "Unimplemented branch instruction " & instruction'image(reg_instruction);
                end case;
              when M_NNNN | M_INNNN | M_NNNNX | M_NNNNY => cpu_state <= byte3_fetch; reg_pc <= reg_pc + 1;
              when others =>
                assert false report "Hit unimplemented addressing mode " & addressingmode'image(reg_mode);
                null;
            end case;    

          when byte3_fetch =>
            reg_addr(15 downto 8) <= data_i;
            case reg_mode is
              when M_NNNN | M_NNNNX | M_NNNNY =>

                -- Default to absolute unindexed addressing mode
                address(15 downto 8) <= data_i;
                address(7 downto 0) <= reg_addr(7 downto 0);

                -- XXX Does not charge an extra cycle for page crossing
                case reg_mode is
                  when M_NNNNX => address(7 downto 0) <= reg_addr_x(7 downto 0);
                                  if reg_addr_x(8)='1' then address(15 downto 8) <= to_unsigned(to_integer(data_i) + 1,8); end if;
                  when M_NNNNY => address(7 downto 0) <= reg_addr_y(7 downto 0);
                                  if reg_addr_y(8)='1' then address(15 downto 8) <= to_unsigned(to_integer(data_i) + 1,8); end if;
                  when others => null;
                end case;
                
                case reg_instruction is
                  when I_STA => data_o <= reg_a; write <= '1'; cpu_state <= opcode_fetch;
                  when I_STX => data_o <= reg_x; write <= '1'; cpu_state <= opcode_fetch;
                  when I_STY => data_o <= reg_y; write <= '1'; cpu_state <= opcode_fetch;
                  when others =>
                    assert false report "Unimplemented absolute mode instruction " & instruction'image(reg_instruction);
                end case;
              when others =>
                assert false report "Hit unimplemented addressing mode " & addressingmode'image(reg_mode);
                null;
            end case;          
            
          when others =>
            assert false report "Hit unimplemented CPU state " & cpu_state_t'image(cpu_state);
        end case;
        
      end if;
    end if;
    
  end process;  
end vapourware;

