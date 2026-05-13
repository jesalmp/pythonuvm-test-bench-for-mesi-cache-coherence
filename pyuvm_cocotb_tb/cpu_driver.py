import cocotb
from pyuvm import uvm_driver, ConfigDB
from cocotb.triggers import RisingEdge
from cpu_transaction import CpuTransaction
from cpu_bfm import CpuBfm
from cache_tb_pkg import RequestType

class CpuDriver(uvm_driver):
    def build_phase(self):
        super().build_phase()
        self.cpu_id = ConfigDB().get(self, "", "cpu_id")
        dut = ConfigDB().get(self, "", "dut")
        self.bfm = CpuBfm(dut, self.cpu_id)

    async def run_phase(self):
        while True:
            txn = await self.seq_item_port.get_next_item()
            if txn.wait_cycles > 0:
                for _ in range(txn.wait_cycles):
                    await RisingEdge(self.bfm.clk)
            if txn.request_type == RequestType.READ_REQ:
                read_data, timed_out = await self.bfm.drive_read(txn.address)
                txn.data = read_data
                if timed_out:
                    self.logger.error(f"CPU{self.cpu_id}: Read timeout addr=0x{txn.address:08X}")
            else:
                timed_out = await self.bfm.drive_write(txn.address, txn.data)
                if timed_out:
                    self.logger.error(f"CPU{self.cpu_id}: Write timeout addr=0x{txn.address:08X}")
            self.seq_item_port.item_done()
