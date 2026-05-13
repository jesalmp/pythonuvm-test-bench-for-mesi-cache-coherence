from enum import IntEnum, auto

class RequestType(IntEnum):
    READ_REQ = 0
    WRITE_REQ = 1

class CacheType(IntEnum):
    ICACHE = 0
    DCACHE = 1

class MesiState(IntEnum):
    INVALID = 0
    SHARED = 1
    EXCLUSIVE = 2
    MODIFIED = 3

class BusReqType(IntEnum):
    NONE = 0
    BUS_RD = 1
    BUS_RDX = 2
    INVALIDATE = 3

class BusReqProcNum(IntEnum):
    PROC0 = 0
    PROC1 = 1
    PROC2 = 2
    PROC3 = 3

class ServicedBy(IntEnum):
    SERV_NONE = 0
    SERV_L2 = 1
    SERV_SNOOP = 2

ADDR_WID = 32
DATA_WID = 32
TAG_WID_LV1 = 16
INDEX_WID_LV1 = 14
OFFSET_WID = 2
ASSOC_LV1 = 4
NUM_SETS_LV1 = 1 << INDEX_WID_LV1
TAG_WID_LV2 = 12
INDEX_WID_LV2 = 18
ASSOC_LV2 = 8
NUM_SETS_LV2 = 1 << INDEX_WID_LV2
IL_DL_ADDR_BOUND = 0x3FFFFFFF
NUM_CORES = 4
TIMEOUT_CYCLES = 110

def addr_to_cache_type(addr):
    return CacheType.ICACHE if addr <= IL_DL_ADDR_BOUND else CacheType.DCACHE

def addr_parts_lv1(addr):
    offset = addr & 0x3
    index = (addr >> OFFSET_WID) & ((1 << INDEX_WID_LV1) - 1)
    tag = (addr >> (OFFSET_WID + INDEX_WID_LV1)) & ((1 << TAG_WID_LV1) - 1)
    return tag, index, offset

def addr_parts_lv2(addr):
    offset = addr & 0x3
    index = (addr >> OFFSET_WID) & ((1 << INDEX_WID_LV2) - 1)
    tag = (addr >> (OFFSET_WID + INDEX_WID_LV2)) & ((1 << TAG_WID_LV2) - 1)
    return tag, index, offset

def default_data(addr):
    return 0x5555AAAA if (addr & 0x8) else 0xAAAA5555
