## This file is a general .xdc for the Nexys4 rev B board
## To use it in a project:
## - uncomment the lines corresponding to used pins
## - rename the used ports (in each line, after get_ports) according to the top level signal names in the project

# Ignore false paths crossing clock domains in pixel output stage

## Clock signal
set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports CLK_IN]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} -add [get_ports CLK_IN]

set_false_path -from [get_cells led*]
set_false_path -to [get_cells vga*]

## Accept sub-optimal clock placement
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clocks1/CLKOUT0]

## Make Ethernet clocks unrelated to other clocks to avoid erroneous timing
## violations, and hopefully make everything synthesise faster.
set_clock_groups -asynchronous \
     -group { cpuclock hdmi_clk_OBUF vdac_clk_OBUF clock162 clock325 } \
     -group { CLKFBOUT clk_fb_eth clock100 clock200 eth_clock_OBUF } \

# Deal with more false paths crossing ethernet / cpu clock domains
set_false_path -from [get_clocks cpuclock] -to [get_clocks ethclock]
set_false_path -from [get_clocks ethclock] -to [get_clocks cpuclock]


## Switches
set_property -dict {PACKAGE_PIN J15 IOSTANDARD LVCMOS33} [get_ports {sw[0]}]
set_property -dict {PACKAGE_PIN L16 IOSTANDARD LVCMOS33} [get_ports {sw[1]}]
set_property -dict {PACKAGE_PIN M13 IOSTANDARD LVCMOS33} [get_ports {sw[2]}]
set_property -dict {PACKAGE_PIN R15 IOSTANDARD LVCMOS33} [get_ports {sw[3]}]
set_property -dict {PACKAGE_PIN R17 IOSTANDARD LVCMOS33} [get_ports {sw[4]}]
set_property -dict {PACKAGE_PIN T18 IOSTANDARD LVCMOS33} [get_ports {sw[5]}]
set_property -dict {PACKAGE_PIN U18 IOSTANDARD LVCMOS33} [get_ports {sw[6]}]
set_property -dict {PACKAGE_PIN R13 IOSTANDARD LVCMOS33} [get_ports {sw[7]}]
set_property -dict {PACKAGE_PIN T8 IOSTANDARD LVCMOS33} [get_ports {sw[8]}]
set_property -dict {PACKAGE_PIN U8 IOSTANDARD LVCMOS33} [get_ports {sw[9]}]
set_property -dict {PACKAGE_PIN R16 IOSTANDARD LVCMOS33} [get_ports {sw[10]}]
set_property -dict {PACKAGE_PIN T13 IOSTANDARD LVCMOS33} [get_ports {sw[11]}]
set_property -dict {PACKAGE_PIN H6 IOSTANDARD LVCMOS33} [get_ports {sw[12]}]
set_property -dict {PACKAGE_PIN U12 IOSTANDARD LVCMOS33} [get_ports {sw[13]}]
set_property -dict {PACKAGE_PIN U11 IOSTANDARD LVCMOS33} [get_ports {sw[14]}]
set_property -dict {PACKAGE_PIN V10 IOSTANDARD LVCMOS33} [get_ports {sw[15]}]

## LEDs
set_property -dict {PACKAGE_PIN H17 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN K15 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN J13 IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN N14 IOSTANDARD LVCMOS33} [get_ports {led[3]}]
set_property -dict {PACKAGE_PIN R18 IOSTANDARD LVCMOS33} [get_ports {led[4]}]
set_property -dict {PACKAGE_PIN V17 IOSTANDARD LVCMOS33} [get_ports {led[5]}]
set_property -dict {PACKAGE_PIN U17 IOSTANDARD LVCMOS33} [get_ports {led[6]}]
set_property -dict {PACKAGE_PIN U16 IOSTANDARD LVCMOS33} [get_ports {led[7]}]
set_property -dict {PACKAGE_PIN V16 IOSTANDARD LVCMOS33} [get_ports {led[8]}]
set_property -dict {PACKAGE_PIN T15 IOSTANDARD LVCMOS33} [get_ports {led[9]}]
set_property -dict {PACKAGE_PIN U14 IOSTANDARD LVCMOS33} [get_ports {led[10]}]
set_property -dict {PACKAGE_PIN T16 IOSTANDARD LVCMOS33} [get_ports {led[11]}]
set_property -dict {PACKAGE_PIN V15 IOSTANDARD LVCMOS33} [get_ports {led[12]}]
set_property -dict {PACKAGE_PIN V14 IOSTANDARD LVCMOS33} [get_ports {led[13]}]
set_property -dict {PACKAGE_PIN V12 IOSTANDARD LVCMOS33} [get_ports {led[14]}]
set_property -dict {PACKAGE_PIN V11 IOSTANDARD LVCMOS33} [get_ports {led[15]}]

#set_property -dict { PACKAGE_PIN K5  IOSTANDARD LVCMOS33 } [get_ports RGB1_Red]
#set_property -dict { PACKAGE_PIN F13 IOSTANDARD LVCMOS33 } [get_ports RGB1_Green]
#set_property -dict { PACKAGE_PIN F6  IOSTANDARD LVCMOS33 } [get_ports RGB1_Blue]
#set_property -dict { PACKAGE_PIN K6  IOSTANDARD LVCMOS33 } [get_ports RGB2_Red]
#set_property -dict { PACKAGE_PIN H6  IOSTANDARD LVCMOS33 } [get_ports RGB2_Green]
#set_property -dict { PACKAGE_PIN L16 IOSTANDARD LVCMOS33 } [get_ports RGB2_Blue]

##7 segment display
set_property -dict {PACKAGE_PIN T10 IOSTANDARD LVCMOS33} [get_ports {sseg_ca[0]}]
set_property -dict {PACKAGE_PIN R10 IOSTANDARD LVCMOS33} [get_ports {sseg_ca[1]}]
set_property -dict {PACKAGE_PIN K16 IOSTANDARD LVCMOS33} [get_ports {sseg_ca[2]}]
set_property -dict {PACKAGE_PIN K13 IOSTANDARD LVCMOS33} [get_ports {sseg_ca[3]}]
set_property -dict {PACKAGE_PIN P15 IOSTANDARD LVCMOS33} [get_ports {sseg_ca[4]}]
set_property -dict {PACKAGE_PIN T11 IOSTANDARD LVCMOS33} [get_ports {sseg_ca[5]}]
set_property -dict {PACKAGE_PIN L18 IOSTANDARD LVCMOS33} [get_ports {sseg_ca[6]}]

set_property -dict {PACKAGE_PIN H15 IOSTANDARD LVCMOS33} [get_ports {sseg_ca[7]}]

set_property -dict {PACKAGE_PIN J17 IOSTANDARD LVCMOS33} [get_ports {sseg_an[0]}]
set_property -dict {PACKAGE_PIN J18 IOSTANDARD LVCMOS33} [get_ports {sseg_an[1]}]
set_property -dict {PACKAGE_PIN T9 IOSTANDARD LVCMOS33} [get_ports {sseg_an[2]}]
set_property -dict {PACKAGE_PIN J14 IOSTANDARD LVCMOS33} [get_ports {sseg_an[3]}]
set_property -dict {PACKAGE_PIN P14 IOSTANDARD LVCMOS33} [get_ports {sseg_an[4]}]
set_property -dict {PACKAGE_PIN T14 IOSTANDARD LVCMOS33} [get_ports {sseg_an[5]}]
set_property -dict {PACKAGE_PIN K2 IOSTANDARD LVCMOS33} [get_ports {sseg_an[6]}]
set_property -dict {PACKAGE_PIN U13 IOSTANDARD LVCMOS33} [get_ports {sseg_an[7]}]

##Buttons
set_property -dict {PACKAGE_PIN C12 IOSTANDARD LVCMOS33} [get_ports btnCpuReset]
set_property -dict {PACKAGE_PIN N17 IOSTANDARD LVCMOS33} [get_ports {btn[0]}]
set_property -dict {PACKAGE_PIN M18 IOSTANDARD LVCMOS33} [get_ports {btn[4]}]
set_property -dict {PACKAGE_PIN M17 IOSTANDARD LVCMOS33} [get_ports {btn[2]}]
set_property -dict {PACKAGE_PIN P17 IOSTANDARD LVCMOS33} [get_ports {btn[3]}]
set_property -dict {PACKAGE_PIN P18 IOSTANDARD LVCMOS33} [get_ports {btn[1]}]

##Pmod Header JA
set_property -dict {PACKAGE_PIN C17 IOSTANDARD LVCMOS33} [get_ports {jalo[1]}]
set_property -dict {PACKAGE_PIN D18 IOSTANDARD LVCMOS33} [get_ports {jalo[2]}]
set_property -dict {PACKAGE_PIN E18 IOSTANDARD LVCMOS33} [get_ports {jalo[3]}]
set_property -dict {PACKAGE_PIN G17 IOSTANDARD LVCMOS33} [get_ports {jalo[4]}]
set_property -dict {PACKAGE_PIN D17 IOSTANDARD LVCMOS33} [get_ports {jahi[7]}]
set_property -dict {PACKAGE_PIN E17 IOSTANDARD LVCMOS33} [get_ports {jahi[8]}]
set_property -dict {PACKAGE_PIN F18 IOSTANDARD LVCMOS33} [get_ports {jahi[9]}]
set_property -dict {PACKAGE_PIN G18 IOSTANDARD LVCMOS33} [get_ports {jahi[10]}]

##Pmod Header JB
set_property -dict {PACKAGE_PIN D14 IOSTANDARD LVCMOS33} [get_ports {jblo[1]}]
set_property -dict {PACKAGE_PIN F16 IOSTANDARD LVCMOS33} [get_ports {jblo[2]}]
set_property -dict {PACKAGE_PIN G16 IOSTANDARD LVCMOS33} [get_ports {jblo[3]}]
set_property -dict {PACKAGE_PIN H14 IOSTANDARD LVCMOS33} [get_ports {jblo[4]}]
set_property PACKAGE_PIN E16 [get_ports {jbhi[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {jbhi[7]}]
set_property -dict {PACKAGE_PIN F13 IOSTANDARD LVCMOS33} [get_ports {jbhi[8]}]
set_property -dict {PACKAGE_PIN G13 IOSTANDARD LVCMOS33} [get_ports {jbhi[9]}]
set_property -dict {PACKAGE_PIN H16 IOSTANDARD LVCMOS33} [get_ports {jbhi[10]}]

##Pmod Header JC
set_property -dict {PACKAGE_PIN K1 IOSTANDARD LVCMOS33} [get_ports {jclo[1]}]
set_property -dict {PACKAGE_PIN F6 IOSTANDARD LVCMOS33} [get_ports {jclo[2]}]
set_property -dict {PACKAGE_PIN J2 IOSTANDARD LVCMOS33} [get_ports {jclo[3]}]
set_property -dict {PACKAGE_PIN G6 IOSTANDARD LVCMOS33} [get_ports {jclo[4]}]
set_property -dict { PACKAGE_PIN E7 IOSTANDARD LVCMOS33 } [get_ports {jchi[7]}]
set_property -dict { PACKAGE_PIN J3 IOSTANDARD LVCMOS33 } [get_ports {jchi[8]}]
set_property -dict {PACKAGE_PIN J4 IOSTANDARD LVCMOS33} [get_ports {jchi[9]}]
set_property -dict {PACKAGE_PIN E6 IOSTANDARD LVCMOS33} [get_ports {jchi[10]}]

##Pmod Header JD
set_property -dict {PACKAGE_PIN H4 IOSTANDARD LVCMOS33} [get_ports {jdlo[1]}]
set_property -dict {PACKAGE_PIN H1 IOSTANDARD LVCMOS33} [get_ports {jdlo[2]}]
set_property -dict {PACKAGE_PIN G1 IOSTANDARD LVCMOS33} [get_ports {jdlo[3]}]
set_property -dict {PACKAGE_PIN G3 IOSTANDARD LVCMOS33} [get_ports {jdlo[4]}]
## Modem PCM digital audio interface is 1.8V, so we will need a level converter
set_property -dict {PACKAGE_PIN H2 IOSTANDARD LVCMOS33} [get_ports {jdhi[7]}]
set_property -dict {PACKAGE_PIN G4 IOSTANDARD LVCMOS33} [get_ports {jdhi[8]}]
set_property -dict {PACKAGE_PIN G2 IOSTANDARD LVCMOS33} [get_ports {jdhi[9]}]
set_property -dict {PACKAGE_PIN F3 IOSTANDARD LVCMOS33} [get_ports {jdhi[10]}]

##Pmod Header JXADC

##VGA Connector
set_property -dict {PACKAGE_PIN A3 IOSTANDARD LVCMOS33} [get_ports {vgared[0]}]
set_property -dict {PACKAGE_PIN B4 IOSTANDARD LVCMOS33} [get_ports {vgared[1]}]
set_property -dict {PACKAGE_PIN C5 IOSTANDARD LVCMOS33} [get_ports {vgared[2]}]
set_property -dict {PACKAGE_PIN A4 IOSTANDARD LVCMOS33} [get_ports {vgared[3]}]
set_property -dict {PACKAGE_PIN B7 IOSTANDARD LVCMOS33} [get_ports {vgablue[0]}]
set_property -dict {PACKAGE_PIN C7 IOSTANDARD LVCMOS33} [get_ports {vgablue[1]}]
set_property -dict {PACKAGE_PIN D7 IOSTANDARD LVCMOS33} [get_ports {vgablue[2]}]
set_property -dict {PACKAGE_PIN D8 IOSTANDARD LVCMOS33} [get_ports {vgablue[3]}]
set_property -dict {PACKAGE_PIN C6 IOSTANDARD LVCMOS33} [get_ports {vgagreen[0]}]
set_property -dict {PACKAGE_PIN A5 IOSTANDARD LVCMOS33} [get_ports {vgagreen[1]}]
set_property -dict {PACKAGE_PIN B6 IOSTANDARD LVCMOS33} [get_ports {vgagreen[2]}]
set_property -dict {PACKAGE_PIN A6 IOSTANDARD LVCMOS33} [get_ports {vgagreen[3]}]
set_property -dict {PACKAGE_PIN B11 IOSTANDARD LVCMOS33} [get_ports hsync]
set_property -dict {PACKAGE_PIN B12 IOSTANDARD LVCMOS33} [get_ports vsync]

##Micro SD Connector
set_property -dict {PACKAGE_PIN E2 IOSTANDARD LVCMOS33} [get_ports sdReset]
#set_property -dict { PACKAGE_PIN A1 IOSTANDARD LVCMOS33 } [get_ports sdCD]
set_property -dict {PACKAGE_PIN B1 IOSTANDARD LVCMOS33} [get_ports sdClock]
set_property -dict {PACKAGE_PIN C1 IOSTANDARD LVCMOS33} [get_ports sdMOSI]
set_property -dict {PACKAGE_PIN C2 IOSTANDARD LVCMOS33} [get_ports sdMISO]
#set_property -dict { PACKAGE_PIN E1 IOSTANDARD LVCMOS33 } [get_ports {sdData[1]}]
#set_property -dict { PACKAGE_PIN F1 IOSTANDARD LVCMOS33 } [get_ports {sdData[2]}]
#set_property -dict { PACKAGE_PIN D2 IOSTANDARD LVCMOS33 } [get_ports {sdData[3]}]

##Accelerometer
set_property -dict {PACKAGE_PIN E15 IOSTANDARD LVCMOS33} [get_ports aclMISO]
set_property -dict {PACKAGE_PIN F14 IOSTANDARD LVCMOS33} [get_ports aclMOSI]
set_property -dict {PACKAGE_PIN F15 IOSTANDARD LVCMOS33} [get_ports aclSCK]
set_property -dict {PACKAGE_PIN D15 IOSTANDARD LVCMOS33} [get_ports aclSS]
set_property -dict {PACKAGE_PIN B13 IOSTANDARD LVCMOS33} [get_ports aclInt1]
set_property -dict {PACKAGE_PIN C16 IOSTANDARD LVCMOS33} [get_ports aclInt2]

##Temperature Sensor
set_property -dict {PACKAGE_PIN C14 IOSTANDARD LVCMOS33} [get_ports tmpSCL]
set_property -dict {PACKAGE_PIN C15 IOSTANDARD LVCMOS33} [get_ports tmpSDA]
set_property -dict {PACKAGE_PIN D13 IOSTANDARD LVCMOS33} [get_ports tmpInt]
set_property -dict {PACKAGE_PIN B14 IOSTANDARD LVCMOS33} [get_ports tmpCT]

##Omnidirectional Microphone
set_property -dict {PACKAGE_PIN J5 IOSTANDARD LVCMOS33} [get_ports micClk]
set_property -dict {PACKAGE_PIN H5 IOSTANDARD LVCMOS33} [get_ports micData]
set_property -dict {PACKAGE_PIN F5 IOSTANDARD LVCMOS33} [get_ports micLRSel]

##PWM Audio Amplifier
set_property -dict {PACKAGE_PIN A11 IOSTANDARD LVCMOS33} [get_ports ampPWM]
set_property -dict {PACKAGE_PIN D12 IOSTANDARD LVCMOS33} [get_ports ampSD]

##USB-RS232 Interface
set_property -dict {PACKAGE_PIN C4 IOSTANDARD LVCMOS33} [get_ports RsRx]
set_property -dict {PACKAGE_PIN D4 IOSTANDARD LVCMOS33} [get_ports UART_TXD]
#set_property -dict { PACKAGE_PIN D3 IOSTANDARD LVCMOS33 } [get_ports RsCts]
#set_property -dict { PACKAGE_PIN E5 IOSTANDARD LVCMOS33 } [get_ports RsRts]

##USB HID (PS/2)
set_property PACKAGE_PIN F4 [get_ports ps2clk]
set_property IOSTANDARD LVCMOS33 [get_ports ps2clk]
set_property PULLUP true [get_ports ps2clk]
set_property PACKAGE_PIN B2 [get_ports ps2data]
set_property IOSTANDARD LVCMOS33 [get_ports ps2data]
set_property PULLUP true [get_ports ps2data]

##SMSC Ethernet PHY
set_property -dict {PACKAGE_PIN C9 IOSTANDARD LVCMOS33} [get_ports eth_mdc]
set_property -dict {PACKAGE_PIN A9 IOSTANDARD LVCMOS33} [get_ports eth_mdio]
set_property -dict {PACKAGE_PIN B3 IOSTANDARD LVCMOS33} [get_ports eth_reset]
# the below eth_rxdv was called PhyCrs, unsure if this is correct, need to check
set_property -dict {PACKAGE_PIN D9 IOSTANDARD LVCMOS33} [get_ports eth_rxdv]
set_property -dict {PACKAGE_PIN C10 IOSTANDARD LVCMOS33} [get_ports eth_rxer]
set_property -dict {PACKAGE_PIN C11 IOSTANDARD LVCMOS33} [get_ports {eth_rxd[0]}]
set_property -dict {PACKAGE_PIN D10 IOSTANDARD LVCMOS33} [get_ports {eth_rxd[1]}]
set_property -dict {PACKAGE_PIN B9 IOSTANDARD LVCMOS33} [get_ports eth_txen]
set_property -dict {PACKAGE_PIN A10 IOSTANDARD LVCMOS33} [get_ports {eth_txd[0]}]
set_property -dict {PACKAGE_PIN A8 IOSTANDARD LVCMOS33} [get_ports {eth_txd[1]}]
set_property -dict {PACKAGE_PIN D5 IOSTANDARD LVCMOS33} [get_ports eth_clock]
set_property -dict {PACKAGE_PIN B8 IOSTANDARD LVCMOS33} [get_ports eth_interrupt]

##Quad SPI Flash
 #set_property  -dict { PACKAGE_PIN E9  IOSTANDARD LVCMOS33 } [get_ports {QspiSCK}]
set_property -dict {PACKAGE_PIN K17 IOSTANDARD LVCMOS33} [get_ports {QspiDB[0]}]
set_property -dict {PACKAGE_PIN K18 IOSTANDARD LVCMOS33} [get_ports {QspiDB[1]}]
set_property -dict {PACKAGE_PIN L14 IOSTANDARD LVCMOS33} [get_ports {QspiDB[2]}]
set_property -dict {PACKAGE_PIN M14 IOSTANDARD LVCMOS33} [get_ports {QspiDB[3]}]
set_property -dict {PACKAGE_PIN L13 IOSTANDARD LVCMOS33} [get_ports QspiCSn]
set_property PULLUP true [get_ports {qspidb[0]}]
set_property PULLUP true [get_ports {qspidb[1]}]
set_property PULLUP true [get_ports {qspidb[2]}]
set_property PULLUP true [get_ports {qspidb[3]}]


#set_false_path -from [get_clocks -of_objects [get_pins dotclock1/mmcm_adv_inst/CLKOUT2]] -to [get_clocks -of_objects [get_pins dotclock1/mmcm_adv_inst/CLKOUT3]]
#set_false_path -from [get_clocks -of_objects [get_pins dotclock1/mmcm_adv_inst/CLKOUT3]] -to [get_clocks -of_objects [get_pins dotclock1/mmcm_adv_inst/CLKOUT0]]
set_false_path -from [get_pins {machine0/viciv0/bitplanes_x_start_reg[2]/C}] -to [get_pins machine0/viciv0/vicii_sprites0/bitplanes0/x_in_bitplanes_reg/D]
set_false_path -from [get_pins machine0/iomapper0/block4b.c65uart0/reg_status3_rx_framing_error_reg/C] -to [get_pins {machine0/cpu0/read_data_copy_reg[3]/D}]
set_false_path -from [get_pins machine0/iomapper0/block4b.c65uart0/reg_status0_rx_full_reg/C] -to [get_pins {machine0/cpu0/read_data_copy_reg[0]/D}]
set_false_path -from [get_pins {machine0/viciv0/vicii_sprite_bitmap_collisions_reg[6]/C}] -to [get_pins {machine0/cpu0/read_data_copy_reg[6]/D}]
set_false_path -from [get_pins {machine0/viciv0/vicii_sprite_sprite_collisions_reg[5]/C}] -to [get_pins {machine0/cpu0/read_data_copy_reg[5]/D}]
set_false_path -from [get_pins {machine0/viciv0/vicii_sprites0/bitplanes0/v_bitplane_y_start_reg[5]/C}] -to [get_pins {machine0/viciv0/vicii_sprites0/bitplanes0/p_0_out/A[12]}]
set_false_path -from [get_pins {machine0/viciv0/vicii_sprites0/bitplanes0/v_bitplane_y_start_reg[5]/C}] -to [get_pins {machine0/viciv0/vicii_sprites0/bitplanes0/p_0_out/A[13]}]
set_false_path -from [get_pins {machine0/viciv0/vicii_sprites0/bitplanes0/v_bitplane_y_start_reg[5]/C}] -to [get_pins {machine0/viciv0/vicii_sprites0/bitplanes0/p_0_out/A[13]}]
set_false_path -from [get_pins {machine0/viciv0/vicii_sprites0/bitplanes0/v_bitplane_y_start_reg[5]/C}] -to [get_pins {machine0/viciv0/vicii_sprites0/bitplanes0/p_0_out/A[15]}]
set_false_path -from [get_pins {machine0/viciv0/vicii_sprites0/bitplanes0/v_bitplane_y_start_reg[5]/C}] -to [get_pins {machine0/viciv0/vicii_sprites0/bitplanes0/p_0_out/A[14]}]
set_false_path -from [get_pins {machine0/viciv0/vicii_sprites0/bitplanes0/v_bitplane_y_start_reg[5]/C}] -to [get_pins {machine0/viciv0/vicii_sprites0/bitplanes0/p_0_out/A[5]}]
set_false_path -from [get_pins {machine0/viciv0/vicii_sprites0/bitplanes0/v_bitplane_y_start_reg[5]/C}] -to [get_pins {machine0/viciv0/vicii_sprites0/bitplanes0/p_0_out/A[10]}]


set_false_path -from [get_pins machine0/iomapper0/block2.framepacker0/buffer_moby_toggle_reg/C] -to [get_pins {machine0/iomapper0/ethernet0/FSM_onehot_eth_tx_state_reg[0]/CE}]


set_multicycle_path -from [get_pins machine0/iomapper0/block2.framepacker0/buffer_moby_toggle_reg/C] -to [get_pins {machine0/iomapper0/ethernet0/FSM_onehot_eth_tx_state_reg[4]/CE}] 1
set_false_path -from [get_pins machine0/iomapper0/block2.framepacker0/buffer_moby_toggle_reg/C] -to [get_pins {machine0/iomapper0/ethernet0/FSM_onehot_eth_tx_state_reg[2]/CE}]
set_false_path -from [get_pins machine0/iomapper0/block2.framepacker0/buffer_moby_toggle_reg/C] -to [get_pins {machine0/iomapper0/ethernet0/FSM_onehot_eth_tx_state_reg[7]/CE}]
set_false_path -from [get_pins machine0/iomapper0/block2.framepacker0/buffer_moby_toggle_reg/C] -to [get_pins {machine0/iomapper0/ethernet0/FSM_onehot_eth_tx_state_reg[1]/CE}]
set_false_path -from [get_pins machine0/iomapper0/block2.framepacker0/buffer_moby_toggle_reg/C] -to [get_pins {machine0/iomapper0/ethernet0/FSM_onehot_eth_tx_state_reg[3]/CE}]
set_false_path -from [get_pins machine0/iomapper0/block2.framepacker0/buffer_moby_toggle_reg/C] -to [get_pins {machine0/iomapper0/ethernet0/FSM_onehot_eth_tx_state_reg[5]/CE}]
set_false_path -from [get_pins machine0/iomapper0/block2.framepacker0/buffer_moby_toggle_reg/C] -to [get_pins {machine0/iomapper0/ethernet0/FSM_onehot_eth_tx_state_reg[6]/CE}]
set_false_path -from [get_pins machine0/iomapper0/block2.framepacker0/buffer_moby_toggle_reg/C] -to [get_pins {machine0/iomapper0/ethernet0/tx_preamble_count_reg[0]/S}]
set_false_path -from [get_pins machine0/iomapper0/block2.framepacker0/buffer_moby_toggle_reg/C] -to [get_pins {machine0/iomapper0/ethernet0/tx_preamble_count_reg[2]/S}]
set_false_path -from [get_pins machine0/iomapper0/block2.framepacker0/buffer_moby_toggle_reg/C] -to [get_pins {machine0/iomapper0/ethernet0/tx_preamble_count_reg[3]/S}]
set_false_path -from [get_pins machine0/iomapper0/ethernet0/eth_tx_viciv_reg/C] -to [get_pins machine0/iomapper0/ethernet0/eth_tx_trigger_reg/D]
set_false_path -from [get_pins machine0/iomapper0/ethernet0/eth_rx_buffer_last_used_50mhz_reg/C] -to [get_pins machine0/iomapper0/ethernet0/eth_rx_buffer_last_used_int1_reg/D]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 26 [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR YES [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]


set_false_path -from [get_pins machine0/iomapper0/block2.framepacker0/buffer_moby_toggle_reg/C] -to [get_pins {machine0/iomapper0/ethernet0/FSM_onehot_eth_tx_state_reg[4]/CE}]
set_false_path -from [get_pins machine0/iomapper0/block2.framepacker0/buffer_moby_toggle_reg/C] -to [get_pins {machine0/iomapper0/ethernet0/tx_preamble_count_reg[4]/S}]
set_false_path -from [get_pins machine0/iomapper0/block2.framepacker0/buffer_moby_toggle_reg/C] -to [get_pins {machine0/iomapper0/ethernet0/tx_preamble_count_reg[0]/CE}]
set_false_path -from [get_pins machine0/iomapper0/block2.framepacker0/buffer_moby_toggle_reg/C] -to [get_pins {machine0/iomapper0/ethernet0/tx_preamble_count_reg[2]/CE}]
set_false_path -from [get_pins machine0/iomapper0/block2.framepacker0/buffer_moby_toggle_reg/C] -to [get_pins {machine0/iomapper0/ethernet0/tx_preamble_count_reg[3]/CE}]
set_false_path -from [get_pins machine0/iomapper0/block2.framepacker0/buffer_moby_toggle_reg/C] -to [get_pins {machine0/iomapper0/ethernet0/tx_preamble_count_reg[4]/CE}]
set_false_path -from [get_pins machine0/iomapper0/block2.framepacker0/buffer_moby_toggle_reg/C] -to [get_pins {machine0/iomapper0/ethernet0/eth_txd_int_reg[1]/D}]
set_false_path -from [get_pins machine0/iomapper0/block2.framepacker0/buffer_moby_toggle_reg/C] -to [get_pins {machine0/iomapper0/ethernet0/eth_txd_int_reg[0]/D}]
set_false_path -from [get_pins machine0/iomapper0/block2.framepacker0/buffer_moby_toggle_reg/C] -to [get_pins machine0/iomapper0/ethernet0/eth_txen_int_reg/D]
set_false_path -from [get_pins machine0/iomapper0/block2.framepacker0/buffer_moby_toggle_reg/C] -to [get_pins machine0/iomapper0/ethernet0/eth_tx_viciv_reg/D]
