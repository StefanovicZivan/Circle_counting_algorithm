variable dispScriptFile [file normalize [info script]]

proc getScriptDirectory {} {
    variable dispScriptFile
    set scriptFolder [file dirname $dispScriptFile]
    return $scriptFolder
}

set sdir [getScriptDirectory]
cd [getScriptDirectory]

#postavljanje direktorijuma za projekat
set resultDir ..\/..\/result\/ACC_CALC_IP
file mkdir $resultDir

#kreiranje projekta u datom direktorijumu
create_project pkg_acc_calc ..\/..\/result\/ACC_CALC_IP -part xc7z010clg400-1 -force

#uncomment for zybo-z7-10
set_property board_part digilentinc.com:zybo-z7-10:part0:1.0 [current_project]

#uncomment for zybo
#set_property board_part digilentinc.com:zybo:part0:2.0 [current_project]

set_property target_language VHDL [current_project]

#ubacivanje source fajlova
import_files -norecurse ..\/hdl\/acc_calc_ip.vhd
import_files -norecurse ..\/hdl\/cos_sine_samples_pkg.vhd
import_files -norecurse ..\/hdl\/acc_calc_ip_top.vhd
#import_files -fileset constrs_1 ..\/xdc\/acc_calc.xdc

#pokretanje sinteze
launch_runs synth_1
wait_on_run synth_1
puts "*****************************************************"
puts "* Sinteza zavrsena! *"
puts "*****************************************************"

#pakovanje IP jezgra
update_compile_order -fileset sources_1
ipx::package_project -root_dir ..\/..\/result\/ACC_CALC_IP -vendor xilinx.com -library user -taxonomy /UserIP -archive_source_project true

set_property vendor Group4 [ipx::current_core]
set_property name ACC_CALC_IP [ipx::current_core]
set_property display_name ACC_CALC_IP_V2_0 [ipx::current_core]
set_property description {Calculates circle coordinates for the accumulator matrices in the Circle Hough transform} [ipx::current_core]
set_property taxonomy {/UserIP} [ipx::current_core]
set_property supported_families {zynq Production} [ipx::current_core]

set_property core_revision 2 [ipx::current_core]
ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]
set_property  ip_repo_paths ..\/..\/ [current_project]
update_ip_catalog
ipx::check_integrity -quiet [ipx::current_core]
ipx::archive_core ..\/..\/ACC_CALC_IP_V2_0.zip [ipx::current_core]
close_project


