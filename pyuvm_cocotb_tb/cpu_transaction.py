import random
from pyuvm import uvm_sequence_item
from cache_tb_pkg import *

class CpuTransaction(uvm_sequence_item):
    def __init__(self, name="cpu_transaction"):
        super().__init__(name)
        self.request_type = RequestType.READ_REQ
        self.address = 0
        self.data = 0
        self.access_cache_type = CacheType.ICACHE
        self.wait_cycles = 0

    def randomize(self):
        self.request_type = random.choice(list(RequestType))
        self.address = random.randint(0, 0xFFFFFFFF)
        self.access_cache_type = addr_to_cache_type(self.address)
        if self.access_cache_type == CacheType.ICACHE:
            self.request_type = RequestType.READ_REQ
        self.data = random.randint(0, 0xFFFFFFFF)
        self.wait_cycles = random.randint(0, 30)

    def randomize_with(self, **kwargs):
        self.randomize()
        for k, v in kwargs.items():
            setattr(self, k, v)
        self.access_cache_type = addr_to_cache_type(self.address)
        if self.access_cache_type == CacheType.ICACHE:
            self.request_type = RequestType.READ_REQ

    def __str__(self):
        return (f"CpuTransaction(req={self.request_type.name}, "
                f"addr=0x{self.address:08X}, data=0x{self.data:08X}, "
                f"cache={self.access_cache_type.name})")
