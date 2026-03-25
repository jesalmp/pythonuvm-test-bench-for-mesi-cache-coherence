"""
tb_env.py
TbEnv — UVM environment, mirrors env.sv.
"""

import asyncio
from uvm_shim import UvmEnv
from cpu_agent import CpuAgent
from cache_scoreboard import CacheScoreboard
from mesi_cache_model import MesiCacheModel


class TbEnv(UvmEnv):
    NUM_CORES = 4

    def build_phase(self):
        self.model = MesiCacheModel()
        self.done_queues = [asyncio.Queue() for _ in range(self.NUM_CORES)]

        self.cpu = []
        for i in range(self.NUM_CORES):
            agent = CpuAgent(f"cpu{i}", self)
            agent._cpu_id = i
            agent._model  = self.model
            agent._done_q = self.done_queues[i]
            self.cpu.append(agent)

        self.sb = CacheScoreboard("sb", self)

    def connect_phase(self):
        for i in range(self.NUM_CORES):
            self.cpu[i].monitor.ap.connect(self.sb.cpu_fifo[i].analysis_export)
            self.cpu[i].monitor.sbus_ap.connect(self.sb.sbus_fifo.analysis_export)
