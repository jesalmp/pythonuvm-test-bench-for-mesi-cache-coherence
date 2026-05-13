import cocotb
from pyuvm import uvm_monitor, uvm_analysis_port, ConfigDB
from cocotb.triggers import RisingEdge, FallingEdge, First
from cpu_transaction import CpuTransaction
from cache_tb_pkg import *

class CpuMonPacket:
    def __init__(self):
        self.request_type = RequestType.READ_REQ
        self.addr_type = CacheType.ICACHE
        self.address = 0
        self.data = 0
        self.illegal = False

    def __str__(self):
        return (f"CpuMonPacket(req={self.request_type.name}, "
                f"addr=0x{self.address:08X}, data=0x{self.data:08X}, "
                f"cache={self.addr_type.name})")

class CpuMonitor(uvm_monitor):
    def build_phase(self):
        super().build_phase()
        self.ap = uvm_analysis_port("ap", self)
        self.cpu_id = ConfigDB().get(self, "", "cpu_id")
        self.dut = ConfigDB().get(self, "", "dut")
        self._addr_bus = getattr(self.dut, f"addr_bus_cpu_lv1_{self.cpu_id}")
        self._data_wire = getattr(self.dut, f"data_bus_cpu_lv1_{self.cpu_id}")

    def _get_bit(self, signal):
        if not signal.value.is_resolvable:
            return 0
        return (int(signal.value) >> self.cpu_id) & 1

    async def run_phase(self):
        while True:
            await RisingEdge(self.dut.clk)
            is_rd = self._get_bit(self.dut.cpu_rd)
            is_wr = self._get_bit(self.dut.cpu_wr)
            if not is_rd and not is_wr:
                continue

            pkt = CpuMonPacket()
            addr_val = self._addr_bus.value
            if addr_val.is_resolvable:
                pkt.address = int(addr_val)
            pkt.addr_type = addr_to_cache_type(pkt.address)

            if is_rd and is_wr:
                self.logger.error(f"CPU{self.cpu_id}: Simultaneous rd/wr")
                continue

            if is_rd:
                pkt.request_type = RequestType.READ_REQ
                for _ in range(TIMEOUT_CYCLES + 10):
                    await RisingEdge(self.dut.clk)
                    if self._get_bit(self.dut.data_in_bus_cpu_lv1):
                        val = self._data_wire.value
                        pkt.data = int(val) if val.is_resolvable else 0
                        break
                if pkt.addr_type == CacheType.ICACHE and is_wr:
                    pkt.illegal = True
            else:
                pkt.request_type = RequestType.WRITE_REQ
                data_val = self._data_wire.value
                pkt.data = int(data_val) if data_val.is_resolvable else 0
                for _ in range(TIMEOUT_CYCLES + 10):
                    await RisingEdge(self.dut.clk)
                    if self._get_bit(self.dut.cpu_wr_done):
                        break

            self.ap.write(pkt)
