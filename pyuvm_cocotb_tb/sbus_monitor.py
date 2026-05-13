import cocotb
from pyuvm import uvm_monitor, uvm_analysis_port, ConfigDB
from cocotb.triggers import RisingEdge, FallingEdge, First
from sbus_packet import SbusPacket
from cache_tb_pkg import *

class SbusMonitor(uvm_monitor):
    def build_phase(self):
        super().build_phase()
        self.ap = uvm_analysis_port("ap", self)
        self.dut = ConfigDB().get(self, "", "dut")

    def _get_internal(self, path):
        obj = self.dut.inst_cache_top
        for part in path.split("."):
            obj = getattr(obj, part)
        return obj

    async def run_phase(self):
        while True:
            await RisingEdge(self.dut.clk)
            gnt_proc = self.dut.bus_lv1_lv2_gnt_proc.value
            if not gnt_proc.is_resolvable or int(gnt_proc) == 0:
                continue

            gnt_val = int(gnt_proc)
            proc_num = 0
            for i in range(4):
                if (gnt_val >> i) & 1:
                    proc_num = i
                    break

            pkt = SbusPacket()
            pkt.bus_req_proc_num = BusReqProcNum(proc_num)

            bus_rd = self._get_internal("bus_rd")
            bus_rdx = self._get_internal("bus_rdx")
            invalidate_sig = self._get_internal("invalidate")

            for _ in range(TIMEOUT_CYCLES):
                await RisingEdge(self.dut.clk)
                rd_val = int(bus_rd.value) if bus_rd.value.is_resolvable else 0
                rdx_val = int(bus_rdx.value) if bus_rdx.value.is_resolvable else 0
                inv_val = int(invalidate_sig.value) if invalidate_sig.value.is_resolvable else 0

                if rd_val:
                    pkt.bus_req_type = BusReqType.BUS_RD
                    break
                elif rdx_val:
                    pkt.bus_req_type = BusReqType.BUS_RDX
                    break
                elif inv_val:
                    pkt.bus_req_type = BusReqType.INVALIDATE
                    break

            addr_bus = self._get_internal("addr_bus_lv1_lv2")
            if addr_bus.value.is_resolvable:
                pkt.bus_req_address = int(addr_bus.value)

            cp_in_cache = self._get_internal("cp_in_cache")
            shared_sig = self._get_internal("shared")

            req_proc = self.dut.bus_lv1_lv2_req_proc.value
            while req_proc.is_resolvable and (int(req_proc) >> proc_num) & 1:
                await RisingEdge(self.dut.clk)
                req_proc = self.dut.bus_lv1_lv2_req_proc.value

                cp_val = int(cp_in_cache.value) if cp_in_cache.value.is_resolvable else 0
                sh_val = int(shared_sig.value) if shared_sig.value.is_resolvable else 0
                if cp_val:
                    pkt.cp_in_cache = 1
                    pkt.req_serviced_by = ServicedBy.SERV_SNOOP
                if sh_val:
                    pkt.shared = 1

            if pkt.req_serviced_by == ServicedBy.SERV_NONE and pkt.bus_req_type != BusReqType.INVALIDATE:
                pkt.req_serviced_by = ServicedBy.SERV_L2

            data_bus = self._get_internal("data_bus_lv1_lv2")
            if data_bus.value.is_resolvable:
                pkt.rd_data = int(data_bus.value)

            self.ap.write(pkt)
