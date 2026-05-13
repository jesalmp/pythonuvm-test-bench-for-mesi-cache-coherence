#!/bin/bash
#add passing test cases here
declare -a arr=(
        "base_test"
        "read_miss_icache"
        "shared_snoop_invalidate_test"
        "snoop_mesi_update_test"
        "lru_eviction_test"
        "dirty_replacement_read_test"
        "write_miss_data_test"
        "icache_eviction_test"
        "lru_blk3_bias_test"
        "dirty_evict_refill_test"
        "wr_dirty_evict_refill_test"
        "mesi_full_transition_test"
        "randomized_stress_test"
        "randomized_stress_test"
        "randomized_stress_test"
        "randomized_stress_test"
        "randomized_stress_test"
        "randomized_stress_test"
        "lv2_write_hit_wrong_blk_test"
        "lv2_read_miss_lru_test"
        "snoop_exclusive_test"
        "exhaustive_interface_test"
        "lru_all_ways_icache_test"
        "lru_all_ways_icache_test"
        "snoop_seq_chain_test"
        "snoop_seq_chain_test"
        "proc_seq_chain_test"
        "proc_seq_chain_test"
        "apb_multi_miss_test"
        "apb_multi_miss_test"
        "snoop_seq_core13_test"
        "snoop_seq_core13_test"
        "snoop_seq_core13_test"
        "snoop_seq_core02_test"
        "snoop_seq_core02_test"
        "snoop_seq_core02_test"
        )

if [ ! -d logs ]; then
    mkdir logs
fi
#source ../../setup.bash
./CLEAR_LOGS
./CLEAR
xrun -f cmd_line_comp_elab.f

COUNT=1
for i in "${arr[@]}"
do
    xrun -f sim_cmd_line.f +UVM_TESTNAME=$i -svseed random -covtest "${i}_${COUNT}"
    mv xrun.log logs/"${i}_${COUNT}.log"
    COUNT=$((COUNT+1))
done
./CLEAR
