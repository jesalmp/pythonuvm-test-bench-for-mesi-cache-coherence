"""
cache_tb_pkg.py
Shared enums and constants for the 4-core MESI cache Python UVM testbench.
Mirrors the SV typedefs in cpu_transaction_c.sv, sbus_packet_c.sv, and cache_scoreboard_c.sv.
"""

from enum import IntEnum, auto

# ---------------------------------------------------------------------------
# Bit-width constants (matching def_lv1.sv / def_lv2.sv)
# ---------------------------------------------------------------------------
DATA_WID_LV1 = 32
ADDR_WID_LV1 = 32

# Address partitioning (matches scoreboard: tag[31:16], index[15:2], offset[1:0])
TAG_MSB    = 31
TAG_LSB    = 16
INDEX_MSB  = 15
INDEX_LSB  = 2
OFFSET_MSB = 1
OFFSET_LSB = 0

TAG_WID    = TAG_MSB - TAG_LSB + 1        # 16 bits
INDEX_WID  = INDEX_MSB - INDEX_LSB + 1   # 14 bits
OFFSET_WID = OFFSET_MSB - OFFSET_LSB + 1 # 2  bits

# 4-way set associative
ASSOC = 4

# ICache/DCache boundary: address[31:30] == 2'b00 → ICache, else DCache
IL_DL_ADDR_BOUND_BIT = 30   # both bits [31:30] must be 0 for ICache

# Pre-initialized memory patterns (from README / scoreboard)
CORRECT_DATA_1 = 0x5555_AAAA   # when address[3] == 1
CORRECT_DATA_0 = 0xAAAA_5555   # when address[3] == 0

# ---------------------------------------------------------------------------
# Transaction / packet enumerations
# ---------------------------------------------------------------------------

class RequestType(IntEnum):
    READ_REQ  = 0
    WRITE_REQ = 1


class CacheType(IntEnum):
    ICACHE_ACC = 0
    DCACHE_ACC = 1


class AddrType(IntEnum):
    ICACHE = 0
    DCACHE = 1


class BusReqType(IntEnum):
    BUS_RD    = 0
    BUS_RDX   = 1
    INVALIDATE = 2
    ICACHE_RD = 3


class BusReqProcNum(IntEnum):
    REQ_PROC0 = 0
    REQ_PROC1 = 1
    REQ_PROC2 = 2
    REQ_PROC3 = 3


class ServBy(IntEnum):
    SERV_SNOOP0 = 0
    SERV_SNOOP1 = 1
    SERV_SNOOP2 = 2
    SERV_SNOOP3 = 3
    SERV_L2     = 5
    SERV_NONE   = -1


class MesiState(IntEnum):
    STATE_I = 0
    STATE_S = 1
    STATE_E = 2
    STATE_M = 3


# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------

def addr_to_cache_type(address: int) -> AddrType:
    """Determine cache type from address bits [31:30] (matches SV constraint)."""
    if (address >> IL_DL_ADDR_BOUND_BIT) == 0:
        return AddrType.ICACHE
    return AddrType.DCACHE


def addr_parts(address: int):
    """Return (tag, index, offset) from a 32-bit address."""
    offset = address & 0x3
    index  = (address >> INDEX_LSB) & ((1 << INDEX_WID) - 1)
    tag    = (address >> TAG_LSB)   & ((1 << TAG_WID)  - 1)
    return tag, index, offset
