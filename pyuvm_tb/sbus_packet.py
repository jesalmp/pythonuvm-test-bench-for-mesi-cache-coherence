"""
sbus_packet.py
SbusPacket — system bus packet, mirrors sbus_packet_c.sv.
"""

from uvm_shim import UvmSequenceItem
from cache_tb_pkg import BusReqType


class SbusPacket(UvmSequenceItem):
    def __init__(self, name="sbus_packet"):
        super().__init__(name)
        self.bus_req_type:              BusReqType = BusReqType.BUS_RD
        self.bus_req_proc_num:          int        = 0
        self.req_address:               int        = 0
        self.bus_req_snoop:             int        = 0
        self.req_serviced_by:           str        = "SERV_NONE"
        self.rd_data:                   int        = 0
        self.wr_data_snoop:             int        = 0
        self.snoop_wr_req_flag:         bool       = False
        self.cp_in_cache:               bool       = False
        self.shared:                    bool       = False
        self.service_time:              int        = 0
        self.proc_evict_dirty_blk_flag: bool       = False
        self.proc_evict_dirty_blk_addr: int        = 0
        self.proc_evict_dirty_blk_data: int        = 0

    @classmethod
    def from_model_dict(cls, d: dict, name="sbus_packet") -> "SbusPacket":
        if d is None:
            return None
        p = cls(name)
        p.bus_req_type              = d.get("bus_req_type", BusReqType.BUS_RD)
        p.bus_req_proc_num          = d.get("bus_req_proc_num", 0)
        p.req_address               = d.get("req_address", 0)
        p.bus_req_snoop             = d.get("bus_req_snoop", 0)
        p.req_serviced_by           = d.get("req_serviced_by", "SERV_NONE")
        p.rd_data                   = d.get("rd_data", 0)
        p.wr_data_snoop             = d.get("wr_data_snoop", 0)
        p.snoop_wr_req_flag         = d.get("snoop_wr_req_flag", False)
        p.cp_in_cache               = d.get("cp_in_cache", False)
        p.shared                    = d.get("shared", False)
        p.proc_evict_dirty_blk_flag = d.get("proc_evict_dirty_blk_flag", False)
        p.proc_evict_dirty_blk_addr = d.get("proc_evict_dirty_blk_addr") or 0
        p.proc_evict_dirty_blk_data = d.get("proc_evict_dirty_blk_data") or 0
        return p

    def __str__(self):
        return (f"SbusPacket(cpu={self.bus_req_proc_num} "
                f"type={self.bus_req_type.name if isinstance(self.bus_req_type, BusReqType) else self.bus_req_type} "
                f"addr=0x{self.req_address:08x} rd_data=0x{self.rd_data:08x} "
                f"shared={self.shared} serviced_by={self.req_serviced_by})")
