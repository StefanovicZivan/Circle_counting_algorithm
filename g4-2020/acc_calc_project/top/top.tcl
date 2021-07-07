#funkcija za dobijanje direktorijuma u kojem se nalazi .tcl skripta
variable dispScriptFile [file normalize [info script]]
proc getScriptDirectory {} {
    variable dispScriptFile
    set scriptFolder [file dirname $dispScriptFile]
    return $scriptFolder
}

#promeni direktorijum
cd [getScriptDirectory]
#postavi direktorijum za smestanje rezultata
set resultDir .\/result
#postavi putanju za ip repozitoriju koja sadrzi ACC_CALC_IP
set ip_repo_path [getScriptDirectory]\/..\/

#opcionalno redefinisanje resultDir promenljive
#set resultDir C:\/User\/result

#POVEZIVANJE SISTEMA
file mkdir $resultDir
#kreiraj projekat
create_project acc_calc_system $resultDir  -part xc7z010clg400-1 -force

#uncomment for zybo-z7-10
set_property board_part digilentinc.com:zybo-z7-10:part0:1.0 [current_project]

#uncomment for zybo
#set_property board_part digilentinc.com:zybo:part0:2.0 [current_project]

set_property target_language VHDL [current_project]

#kreiraj blok dijagram
create_bd_design "acc_calc_system"
update_compile_order -fileset sources_1

#dodaj ACC_CALC_IP u repozitoriju
set_property  ip_repo_paths  $ip_repo_path [current_project]
update_ip_catalog

#dodaj zynq processing system u blok dijagram
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0
endgroup

#podesi liniju prekida, frekvenciju takta, dodaj HP interfejse
set_property -dict [list CONFIG.PCW_USE_FABRIC_INTERRUPT {1} CONFIG.PCW_IRQ_F2P_INTR {1}] [get_bd_cells processing_system7_0]
set_property -dict [list CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100}] [get_bd_cells processing_system7_0]
set_property -dict [list CONFIG.PCW_USE_S_AXI_HP0 {1} CONFIG.PCW_USE_S_AXI_HP1 {1}] [get_bd_cells processing_system7_0]

#run block automation za procesor
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable" }  [get_bd_cells processing_system7_0]

#dodaj AXI DMA
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_0
endgroup
#iskljuci scatter gather engine
set_property -dict [list CONFIG.c_include_sg {0} CONFIG.c_sg_length_width {26} CONFIG.c_sg_include_stscntrl_strm {0}] [get_bd_cells axi_dma_0]
#povezi AXI Lite od DMA sa GP0 interfejsom procesora
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/processing_system7_0/M_AXI_GP0} Slave {/axi_dma_0/S_AXI_LITE} ddr_seg {Auto} intc_ip {New AXI Interconnect} master_apm {0}}  [get_bd_intf_pins axi_dma_0/S_AXI_LITE]
#povezi MM2S kanal sa HP0 interfejsom
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/axi_dma_0/M_AXI_MM2S} Slave {/processing_system7_0/S_AXI_HP0} ddr_seg {Auto} intc_ip {New AXI Interconnect} master_apm {0}}  [get_bd_intf_pins processing_system7_0/S_AXI_HP0]
#povezi S2MM kanal sa HP1 interfejsom
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/axi_dma_0/M_AXI_S2MM} Slave {/processing_system7_0/S_AXI_HP1} ddr_seg {Auto} intc_ip {New AXI Interconnect} master_apm {0}}  [get_bd_intf_pins processing_system7_0/S_AXI_HP1]

#dodaj ACC_CALC_IP_V2_0
update_compile_order -fileset sources_1
startgroup
create_bd_cell -type ip -vlnv Group4:user:ACC_CALC_IP:1.0 ACC_CALC_IP_0
endgroup
#povezi slave kanal od IP-a sa master kanalom DMA
connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXIS_MM2S] [get_bd_intf_pins ACC_CALC_IP_0/s00_axis]
#isto i za master kanal od IP-a
connect_bd_intf_net [get_bd_intf_pins axi_dma_0/S_AXIS_S2MM] [get_bd_intf_pins ACC_CALC_IP_0/m00_axis]
#connection automation
apply_bd_automation -rule xilinx.com:bd_rule:clkrst -config { Clk {/processing_system7_0/FCLK_CLK0 (100 MHz)} Freq {100} Ref_Clk0 {} Ref_Clk1 {} Ref_Clk2 {}}  [get_bd_pins ACC_CALC_IP_0/axis_aclk]

#povezi s2mm prekid sa procesorom
connect_bd_net [get_bd_pins axi_dma_0/s2mm_introut] [get_bd_pins processing_system7_0/IRQ_F2P]
save_bd_design

#uradi validaciju blok dizajna
validate_bd_design
#regenerisi layout
regenerate_bd_layout

#napravi HDL wrapper za blok dizajn
make_wrapper -files [get_files $resultDir/acc_calc_system.srcs/sources_1/bd/acc_calc_system/acc_calc_system.bd] -top
#dodaj wrapper u projekat
add_files -norecurse $resultDir/acc_calc_system.srcs/sources_1/bd/acc_calc_system/hdl/acc_calc_system_wrapper.vhd

#pokreni implementaciju
launch_runs impl_1 -to_step write_bitstream -jobs 4

wait_on_run impl_1
update_compile_order -fileset sources_1

#export hardverske platforme
write_hw_platform -fixed -force  -include_bit -file $resultDir/acc_calc_system_wrapper.xsa


