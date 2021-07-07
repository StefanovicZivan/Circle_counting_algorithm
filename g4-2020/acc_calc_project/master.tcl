variable dispScriptFile [file normalize [info script]]
proc getScriptDirectory {} {
    variable dispScriptFile
    set scriptFolder [file dirname $dispScriptFile]
    return $scriptFolder
}

cd [getScriptDirectory]
set ip_repo_path [getScriptDirectory]

#zapakuj ip
source $ip_repo_path\/acc_calc_ip\/src\/script\/acc_calc.tcl

#napravi blok dijagram i eksportuj hw platformu
source $ip_repo_path\/top\/top.tcl
