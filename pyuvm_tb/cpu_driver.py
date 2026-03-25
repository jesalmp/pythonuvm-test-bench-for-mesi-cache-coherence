"""
cpu_driver.py
CpuDriver — UVM driver, mirrors cpu_driver_c.sv.
"""

import asyncio
from uvm_shim import UvmDriver
from cpu_transaction import CpuTransaction
from cache_tb_pkg import RequestType


class CpuDriver(UvmDriver):
    def build_phase(self):
        self.cpu_id = self._cpu_id
        self.model  = self._model
        self.done_q = self._done_q

    async def run_phase(self):
        self.logger.info(f"CPU{self.cpu_id} Driver: RUN Phase")
        while True:
            t: CpuTransaction = await self.seq_item_port.get_next_item()
            await self._drive(t)
            self.seq_item_port.item_done()

    async def _drive(self, t: CpuTransaction):
        self.logger.info(f"CPU{self.cpu_id} Driver: {t}")
        for _ in range(t.wait_cycles):
            await asyncio.sleep(0)
        if t.request_type == RequestType.READ_REQ:
            t.data = self.model.read(self.cpu_id, t.address)
        else:
            self.model.write(self.cpu_id, t.address, t.data)
        sbus_dict = self.model.last_sbus_packet()
        self.done_q.put_nowait((t, sbus_dict))
