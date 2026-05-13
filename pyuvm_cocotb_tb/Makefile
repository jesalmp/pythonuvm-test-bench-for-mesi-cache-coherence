TOPLEVEL_LANG = verilog
SIM ?= icarus

VERILOG_SOURCES = \
    $(PWD)/../design/lv2/def_lv2.sv \
    $(PWD)/../design/lv1/def_lv1.sv \
    $(PWD)/../design/common/access_blk_proc_md.sv \
    $(PWD)/../design/common/addr_segregator_proc.sv \
    $(PWD)/../design/common/blk_hit_proc_md.sv \
    $(PWD)/../design/common/blk_to_be_accessed_md.sv \
    $(PWD)/../design/common/free_blk_md.sv \
    $(PWD)/../design/lv1/cache_block_lv1_dl.sv \
    $(PWD)/../design/lv1/cache_block_lv1_il.sv \
    $(PWD)/../design/lv1/lru_block_lv1.sv \
    $(PWD)/../design/lv1/mesi_fsm_lv1.sv \
    $(PWD)/../design/lv1/access_blk_snoop_md.sv \
    $(PWD)/../design/lv1/addr_segregator_snoop.sv \
    $(PWD)/../design/lv1/blk_hit_snoop_md.sv \
    $(PWD)/../design/lv1/blk_to_be_accessed_snoop_md.sv \
    $(PWD)/../design/lv1/main_func_lv1_dl.sv \
    $(PWD)/../design/lv1/main_func_lv1_il.sv \
    $(PWD)/../design/lv1/cache_controller_lv1_dl.sv \
    $(PWD)/../design/lv1/cache_controller_lv1_il.sv \
    $(PWD)/../design/lv1/cache_wrapper_lv1_dl.sv \
    $(PWD)/../design/lv1/cache_wrapper_lv1_il.sv \
    $(PWD)/../design/lv1/cache_lv1_unicore.sv \
    $(PWD)/../design/lv1/cache_lv1_onecore.sv \
    $(PWD)/../design/lv1/cache_lv1_dualcore.sv \
    $(PWD)/../design/lv1/cache_lv1_multicore.sv \
    $(PWD)/../design/lv2/addr_segregator_proc_lv2.sv \
    $(PWD)/../design/lv2/cache_block_lv2.sv \
    $(PWD)/../design/lv2/lru_block_lv2.sv \
    $(PWD)/../design/lv2/main_func_lv2.sv \
    $(PWD)/../design/lv2/cache_controller_lv2.sv \
    $(PWD)/../design/lv2/cache_wrapper_lv2.sv \
    $(PWD)/../design/cache_top.sv \
    $(PWD)/../gold/memory.sv \
    $(PWD)/../gold/lrs_arbiter.sv \
    $(PWD)/hdl/top_tb.sv

TOPLEVEL = top_tb
MODULE = test_top

EXTRA_ARGS += +define+MULTI_CORE

include $(shell cocotb-config --makefiles)/Makefile.sim
