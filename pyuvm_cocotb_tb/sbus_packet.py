from pyuvm import uvm_sequence_item
from cache_tb_pkg import *

class SbusPacket:
    def __init__(self):
        self.bus_req_type = BusReqType.NONE
        self.bus_req_proc_num = BusReqProcNum.PROC0
        self.bus_req_address = 0
        self.bus_req_snoop = 0
        self.req_serviced_by = ServicedBy.SERV_NONE
        self.rd_data = 0
        self.wr_data_snoop = 0
        self.snoop_wr_req_flag = 0
        self.cp_in_cache = 0
        self.shared = 0
        self.proc_evict_dirty_blk_addr = 0
        self.proc_evict_dirty_blk_data = 0
        self.proc_evict_dirty_blk_flag = 0

    def __str__(self):
        return (f"SbusPacket(req={self.bus_req_type.name}, "
                f"proc={self.bus_req_proc_num.name}, "
                f"addr=0x{self.bus_req_address:08X}, "
                f"serv={self.req_serviced_by.name})")

    def __eq__(self, other):
        if not isinstance(other, SbusPacket):
            return False
        return (self.bus_req_type == other.bus_req_type and
                self.bus_req_proc_num == other.bus_req_proc_num and
                self.bus_req_address == other.bus_req_address and
                self.req_serviced_by == other.req_serviced_by and
                self.cp_in_cache == other.cp_in_cache and
                self.shared == other.shared)
