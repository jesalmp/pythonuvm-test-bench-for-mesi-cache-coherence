# PyUVM + Cocotb Testbench for MESI Cache Coherence

## Overview
This testbench uses **pyuvm** (Python UVM) with **cocotb** to co-simulate the
MESI cache coherence RTL design. It drives and monitors actual RTL signals.

## Architecture
- **cpu_bfm.py** — Bus Functional Model driving RTL read/write protocols
- **cpu_driver.py** — pyuvm driver using BFM
- **cpu_monitor.py** — Monitors per-CPU RTL signals
- **sbus_monitor.py** — Monitors shared LV1↔LV2 system bus
- **cache_scoreboard.py** — MESI reference model with LRU, data checking
- **tb_env.py** — 4× CPU agents + system bus monitor + scoreboard
- **base_test.py** — Runs random transactions on all 4 CPUs
- **five_trans_test.py** — Runs 5 ICache reads on CPU0

## Prerequisites
```bash
pip install cocotb pyuvm
```
A Verilog simulator is required (Icarus Verilog, Verilator, or commercial).

## Running
```bash
cd pyuvm_cocotb_tb
make                                    # default: BaseTest
make PLUSARGS="+UVM_TESTNAME=FiveTransTest"  # specific test
make SIM=verilator                      # use Verilator
```

## Signals Driven
Per CPU core (i=0..3):
- `addr_bus_cpu_lv1_i[31:0]` — address
- `data_bus_cpu_lv1_i_reg[31:0]` — write data
- `cpu_rd[i]`, `cpu_wr[i]` — request strobes
- `cpu_rden[i]`, `cpu_wren[i]` — enable (1 cycle after request)

Per CPU core outputs:
- `data_in_bus_cpu_lv1[i]` — read data valid
- `cpu_wr_done[i]` — write acknowledgment
- `data_bus_cpu_lv1_i[31:0]` — read data (on wire)
