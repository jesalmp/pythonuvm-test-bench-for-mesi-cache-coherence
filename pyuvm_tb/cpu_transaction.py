"""
cpu_transaction.py
CpuTransaction — UVM sequence item, mirrors cpu_transaction_c.sv.
"""

import random
from uvm_shim import UvmSequenceItem
from cache_tb_pkg import (
    RequestType, CacheType, AddrType,
    CORRECT_DATA_0, CORRECT_DATA_1,
    addr_to_cache_type,
)


class CpuTransaction(UvmSequenceItem):
    def __init__(self, name="cpu_transaction"):
        super().__init__(name)
        self.request_type: RequestType = RequestType.READ_REQ
        self.data:         int         = 0
        self.address:      int         = 0
        self.cache_type:   CacheType   = CacheType.ICACHE_ACC
        self.wait_cycles:  int         = 0

    def randomize(self):
        self.request_type = random.choice(list(RequestType))
        self.wait_cycles  = random.randint(0, 5)  # keep short for simulation speed
        icache_choice = random.random() < 0.5
        if icache_choice:
            self.address = random.randint(0, 0x3FFF_FFFF)
        else:
            prefix = random.choice([0x4000_0000, 0x8000_0000, 0xC000_0000])
            self.address = prefix | random.randint(0, 0x3FFF_FFFF)
        addr_t = addr_to_cache_type(self.address)
        self.cache_type = (CacheType.ICACHE_ACC
                           if addr_t == AddrType.ICACHE
                           else CacheType.DCACHE_ACC)
        if self.request_type == RequestType.READ_REQ:
            self.data = CORRECT_DATA_1 if (self.address >> 3) & 1 else CORRECT_DATA_0
        else:
            self.data = random.randint(0, 0xFFFF_FFFF)

    def randomize_with(self, constraints: dict):
        self.randomize()
        for k, v in constraints.items():
            setattr(self, k, v)
        if 'cache_type' in constraints and 'address' not in constraints:
            if constraints['cache_type'] == CacheType.ICACHE_ACC:
                self.address = random.randint(0, 0x3FFF_FFFF)
            else:
                prefix = random.choice([0x4000_0000, 0x8000_0000, 0xC000_0000])
                self.address = prefix | random.randint(0, 0x3FFF_FFFF)
        if 'data' not in constraints and self.request_type == RequestType.READ_REQ:
            self.data = CORRECT_DATA_1 if (self.address >> 3) & 1 else CORRECT_DATA_0

    def __str__(self):
        return (f"CpuTransaction: {self.request_type.name} "
                f"addr=0x{self.address:08x} data=0x{self.data:08x} "
                f"cache={self.cache_type.name} wait={self.wait_cycles}")
