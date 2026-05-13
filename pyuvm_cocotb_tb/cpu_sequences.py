from pyuvm import uvm_sequence
from cpu_transaction import CpuTransaction
from cache_tb_pkg import *

class CpuBaseSeq(uvm_sequence):
    def __init__(self, name="cpu_base_seq"):
        super().__init__(name)
        self.num_txns = 7

    async def body(self):
        for _ in range(self.num_txns):
            txn = CpuTransaction("txn")
            await self.start_item(txn)
            txn.randomize()
            await self.finish_item(txn)

class FiveTransSeq(uvm_sequence):
    def __init__(self, name="five_trans_seq"):
        super().__init__(name)

    async def body(self):
        for _ in range(5):
            txn = CpuTransaction("txn")
            await self.start_item(txn)
            txn.randomize_with(address=random.randint(0, IL_DL_ADDR_BOUND))
            await self.finish_item(txn)

class ReadMissSeq(uvm_sequence):
    def __init__(self, name="read_miss_seq"):
        super().__init__(name)
        self.num_txns = 10

    async def body(self):
        addrs_used = set()
        for _ in range(self.num_txns):
            txn = CpuTransaction("txn")
            await self.start_item(txn)
            while True:
                addr = random.randint(0x40000000, 0xFFFFFFFF)
                tag, idx, _ = addr_parts_lv1(addr)
                if (tag, idx) not in addrs_used:
                    addrs_used.add((tag, idx))
                    break
            txn.randomize_with(
                request_type=RequestType.READ_REQ,
                address=addr
            )
            await self.finish_item(txn)

class WriteMissSeq(uvm_sequence):
    def __init__(self, name="write_miss_seq"):
        super().__init__(name)
        self.num_txns = 10

    async def body(self):
        addrs_used = set()
        for _ in range(self.num_txns):
            txn = CpuTransaction("txn")
            await self.start_item(txn)
            while True:
                addr = random.randint(0x40000000, 0xFFFFFFFF)
                tag, idx, _ = addr_parts_lv1(addr)
                if (tag, idx) not in addrs_used:
                    addrs_used.add((tag, idx))
                    break
            txn.randomize_with(
                request_type=RequestType.WRITE_REQ,
                address=addr
            )
            await self.finish_item(txn)

import random
