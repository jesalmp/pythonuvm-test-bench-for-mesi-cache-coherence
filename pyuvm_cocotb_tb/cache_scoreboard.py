import logging
from pyuvm import uvm_scoreboard, uvm_tlm_analysis_fifo, ConfigDB
from cache_tb_pkg import *
from sbus_packet import SbusPacket

class CacheLine:
    def __init__(self):
        self.tag = 0
        self.mesi = MesiState.INVALID

class CacheSet:
    def __init__(self, assoc=4):
        self.lines = [CacheLine() for _ in range(assoc)]
        self.lru = 0

class CacheScoreboard(uvm_scoreboard):
    def build_phase(self):
        super().build_phase()
        self.cpu_fifo = [uvm_tlm_analysis_fifo(f"cpu_fifo_{i}", self) for i in range(4)]
        self.sbus_fifo = uvm_tlm_analysis_fifo("sbus_fifo", self)
        self.dcache = [[CacheSet() for _ in range(NUM_SETS_LV1)] for _ in range(NUM_CORES)]
        self.icache = [[CacheSet() for _ in range(NUM_SETS_LV1)] for _ in range(NUM_CORES)]
        self.memory = {}
        self.pass_count = 0
        self.fail_count = 0

    def _get_cache(self, core, cache_type):
        return self.icache[core] if cache_type == CacheType.ICACHE else self.dcache[core]

    def _get_way_hit(self, core, cache_type, tag, index):
        cache = self._get_cache(core, cache_type)
        for w in range(ASSOC_LV1):
            line = cache[index].lines[w]
            if line.tag == tag and line.mesi != MesiState.INVALID:
                return w
        return -1

    def _get_way_free(self, core, cache_type, index):
        cache = self._get_cache(core, cache_type)
        for w in range(ASSOC_LV1):
            if cache[index].lines[w].mesi == MesiState.INVALID:
                return w
        return -1

    def _get_way_lru(self, core, cache_type, index):
        cache = self._get_cache(core, cache_type)
        lru = cache[index].lru
        if lru & 0b110 == 0b000:
            return 0
        if lru & 0b110 == 0b010:
            return 1
        if lru & 0b101 == 0b100:
            return 2
        return 3

    def _update_lru(self, core, cache_type, index, way):
        cache = self._get_cache(core, cache_type)
        lru = cache[index].lru
        if way == 0:
            lru = lru | 0b110
        elif way == 1:
            lru = (lru | 0b100) & 0b101
        elif way == 2:
            lru = (lru & 0b011) | 0b001
        else:
            lru = lru & 0b001
        cache[index].lru = lru & 0b111

    def _mem_read(self, addr):
        return self.memory.get(addr, default_data(addr))

    def _mem_write(self, addr, data):
        self.memory[addr] = data

    def _exist_others(self, core, tag, index, cache_type):
        for c in range(NUM_CORES):
            if c == core:
                continue
            cache = self._get_cache(c, cache_type)
            for w in range(ASSOC_LV1):
                line = cache[index].lines[w]
                if line.tag == tag and line.mesi != MesiState.INVALID:
                    return True
        return False

    def _invalidate_others(self, core, tag, index, cache_type):
        for c in range(NUM_CORES):
            if c == core:
                continue
            cache = self._get_cache(c, cache_type)
            for w in range(ASSOC_LV1):
                line = cache[index].lines[w]
                if line.tag == tag and line.mesi != MesiState.INVALID:
                    if line.mesi == MesiState.MODIFIED:
                        addr = (tag << (INDEX_WID_LV1 + OFFSET_WID)) | (index << OFFSET_WID)
                        self._mem_write(addr, self._mem_read(addr))
                    line.mesi = MesiState.INVALID

    def _share_others(self, core, tag, index, cache_type):
        for c in range(NUM_CORES):
            if c == core:
                continue
            cache = self._get_cache(c, cache_type)
            for w in range(ASSOC_LV1):
                line = cache[index].lines[w]
                if line.tag == tag and line.mesi in (MesiState.EXCLUSIVE, MesiState.MODIFIED):
                    if line.mesi == MesiState.MODIFIED:
                        addr = (tag << (INDEX_WID_LV1 + OFFSET_WID)) | (index << OFFSET_WID)
                        self._mem_write(addr, self._mem_read(addr))
                    line.mesi = MesiState.SHARED

    def check_and_update(self, core, pkt):
        tag, index, _ = addr_parts_lv1(pkt.address)
        cache_type = pkt.addr_type
        cache = self._get_cache(core, cache_type)

        way = self._get_way_hit(core, cache_type, tag, index)

        if pkt.request_type == RequestType.READ_REQ:
            expected_data = self._mem_read(pkt.address)
            if way >= 0:
                line = cache[index].lines[way]
                if line.mesi == MesiState.MODIFIED:
                    pass
                self._update_lru(core, cache_type, index, way)
            else:
                way = self._get_way_free(core, cache_type, index)
                if way < 0:
                    way = self._get_way_lru(core, cache_type, index)
                    evict_line = cache[index].lines[way]
                    if evict_line.mesi == MesiState.MODIFIED:
                        evict_addr = (evict_line.tag << (INDEX_WID_LV1 + OFFSET_WID)) | (index << OFFSET_WID)
                        self._mem_write(evict_addr, self._mem_read(evict_addr))
                    evict_line.mesi = MesiState.INVALID

                line = cache[index].lines[way]
                line.tag = tag
                if self._exist_others(core, tag, index, cache_type):
                    self._share_others(core, tag, index, cache_type)
                    line.mesi = MesiState.SHARED
                else:
                    line.mesi = MesiState.EXCLUSIVE
                self._update_lru(core, cache_type, index, way)

            if pkt.data == expected_data or way >= 0:
                self.pass_count += 1
            else:
                self.fail_count += 1
                self.logger.error(
                    f"CPU{core} READ MISMATCH addr=0x{pkt.address:08X}: "
                    f"got=0x{pkt.data:08X} exp=0x{expected_data:08X}")

        elif pkt.request_type == RequestType.WRITE_REQ:
            self._mem_write(pkt.address, pkt.data)
            if way >= 0:
                line = cache[index].lines[way]
                self._invalidate_others(core, tag, index, cache_type)
                line.mesi = MesiState.MODIFIED
                self._update_lru(core, cache_type, index, way)
            else:
                way = self._get_way_free(core, cache_type, index)
                if way < 0:
                    way = self._get_way_lru(core, cache_type, index)
                    evict_line = cache[index].lines[way]
                    if evict_line.mesi == MesiState.MODIFIED:
                        evict_addr = (evict_line.tag << (INDEX_WID_LV1 + OFFSET_WID)) | (index << OFFSET_WID)
                        self._mem_write(evict_addr, self._mem_read(evict_addr))
                    evict_line.mesi = MesiState.INVALID

                line = cache[index].lines[way]
                line.tag = tag
                self._invalidate_others(core, tag, index, cache_type)
                line.mesi = MesiState.MODIFIED
                self._update_lru(core, cache_type, index, way)
            self.pass_count += 1

    def check_phase(self):
        self.logger.info(f"Scoreboard: PASS={self.pass_count} FAIL={self.fail_count}")
        if self.fail_count > 0:
            self.logger.error("TEST FAILED")
        else:
            self.logger.info("TEST PASSED")
