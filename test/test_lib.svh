//=====================================================================
// Project: 4 core MESI cache design
// File Name: test_lib.svh
// Description: Base test class and list of tests
// Designers: Venky & Suru
//=====================================================================
//add your testcase files in here

`include "base_test.sv"
`include "read_miss_icache.sv"
`include "shared_snoop_invalidate_test.sv"
`include "snoop_mesi_update_test.sv"
`include "lru_eviction_test.sv"
`include "dirty_replacement_read_test.sv"
`include "write_miss_data_test.sv"
`include "icache_eviction_test.sv"
`include "lru_blk3_bias_test.sv"
`include "dirty_evict_refill_test.sv"
`include "wr_dirty_evict_refill_test.sv"
`include "mesi_full_transition_test.sv"
`include "randomized_stress_test.sv"
`include "lv2_write_hit_wrong_blk_test.sv"
`include "lv2_read_miss_lru_test.sv"
`include "snoop_exclusive_test.sv"
`include "exhaustive_interface_test.sv"
`include "lru_all_ways_icache_test.sv"
`include "snoop_seq_chain_test.sv"
`include "proc_seq_chain_test.sv"
`include "apb_multi_miss_test.sv"
`include "snoop_seq_core13_test.sv"
`include "snoop_seq_core02_test.sv"

