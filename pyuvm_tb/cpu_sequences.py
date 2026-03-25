"""
cpu_sequences.py
UVM sequences: CpuBaseSeq and FiveTransSeq.
"""

from uvm_shim import UvmSequence
from cpu_transaction import CpuTransaction
from cache_tb_pkg import RequestType, CacheType


class CpuBaseSeq(UvmSequence):
    async def body(self):
        self.logger.info("CpuBaseSeq: executing mixed cache transactions")

        def _do(name, **kw):
            t = CpuTransaction(name)
            t.randomize_with(kw)
            return t

        for t in [
            _do("T1", request_type=RequestType.READ_REQ,  cache_type=CacheType.ICACHE_ACC),
            _do("T2", request_type=RequestType.READ_REQ,  cache_type=CacheType.DCACHE_ACC),
            _do("T3", request_type=RequestType.WRITE_REQ, cache_type=CacheType.DCACHE_ACC,
                address=0x4000_5550),
            _do("T4", request_type=RequestType.WRITE_REQ, cache_type=CacheType.DCACHE_ACC,
                address=0x4000_5550),
            _do("T5", request_type=RequestType.WRITE_REQ, cache_type=CacheType.DCACHE_ACC,
                address=0x4000_5550),
            _do("T6", request_type=RequestType.WRITE_REQ, cache_type=CacheType.DCACHE_ACC),
            _do("T7", request_type=RequestType.READ_REQ,  cache_type=CacheType.DCACHE_ACC),
        ]:
            await self.start_item(t)
            await self.finish_item(t)


class FiveTransSeq(UvmSequence):
    async def body(self):
        self.logger.info("FiveTransSeq: 5 ICache reads")
        for i in range(5):
            t = CpuTransaction(f"icache_rd_{i}")
            t.randomize_with({"request_type": RequestType.READ_REQ,
                              "cache_type":   CacheType.ICACHE_ACC})
            await self.start_item(t)
            await self.finish_item(t)
