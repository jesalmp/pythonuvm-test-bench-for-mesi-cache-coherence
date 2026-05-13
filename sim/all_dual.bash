#!/bin/bash
#add passing test cases here
declare -a arr=(
        "base_test"
        "five_trans_test"
        "read_miss_icache"
        )

if [ ! -d logs ]; then
    mkdir logs
fi
#source ../../setup.bash
./CLEAR_LOGS
./CLEAR
xrun -f cmd_line_comp_elab.f +define+DUAL_CORE="1"

for i in "${arr[@]}"
do
    xrun -f sim_cmd_line.f +UVM_TESTNAME=$i +define+DUAL_CORE="1" -svseed 1 -covtest "$i"
    mv xrun.log logs/"$i".log
done
./CLEAR
