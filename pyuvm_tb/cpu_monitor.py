"""
cpu_monitor.py
CpuMonitor — UVM monitor, mirrors cpu_monitor_c.sv.
"""

from uvm_shim import UvmMonitor, UvmAnalysisPort
from cpu_transaction import CpuTransaction
from sbus_packet import SbusPacket
from cache_tb_pkg import RequestType, AddrType, addr_to_cache_type


class CpuMonPacket:
    """Mirrors cpu_mon_packet_c.sv fields."""
    def __init__(self):
        self.request_type: RequestType = RequestType.READ_REQ
        self.address:      int         = 0
        self.dat:          int         = 0
        self.addr_type:    AddrType    = AddrType.ICACHE
        self.illegal:      bool        = False

    def __str__(self):
        return (f"CpuMonPacket(type={self.request_type.name} "
                f"addr=0x{self.address:08x} dat=0x{self.dat:08x} "
                f"cache={self.addr_type.name} illegal={self.illegal})")


class CpuMonitor(UvmMonitor):
    def build_phase(self):
        self.cpu_id  = self._cpu_id
        self.done_q  = self._done_q
        self.ap      = UvmAnalysisPort("ap", self)
        self.sbus_ap = UvmAnalysisPort("sbus_ap", self)

    async def run_phase(self):
        self.logger.info(f"CPU{self.cpu_id} Monitor: RUN Phase")
        while True:
            t, sbus_dict = await self.done_q.get()
            self._publish(t, sbus_dict)

    def _publish(self, t: CpuTransaction, sbus_dict):
        pkt = CpuMonPacket()
        pkt.request_type = t.request_type
        pkt.address      = t.address
        pkt.dat          = t.data
        pkt.addr_type    = addr_to_cache_type(t.address)
        pkt.illegal      = (t.request_type == RequestType.WRITE_REQ and
                            pkt.addr_type == AddrType.ICACHE)
        self.logger.info(f"CPU{self.cpu_id} Monitor: {pkt}")
        self.ap.write(pkt)
        if sbus_dict is not None:
            sp = SbusPacket.from_model_dict(sbus_dict, f"sbus_cpu{self.cpu_id}")
            self.sbus_ap.write(sp)
