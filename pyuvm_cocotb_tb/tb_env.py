from pyuvm import uvm_env, ConfigDB
from cpu_agent import CpuAgent
from cache_scoreboard import CacheScoreboard
from sbus_monitor import SbusMonitor

class TbEnv(uvm_env):
    def build_phase(self):
        super().build_phase()
        self.agents = []
        for i in range(4):
            ConfigDB().set(self, f"cpu_agent_{i}*", "cpu_id", i)
            agent = CpuAgent(f"cpu_agent_{i}", self)
            self.agents.append(agent)
        self.sbus_mon = SbusMonitor("sbus_mon", self)
        self.scoreboard = CacheScoreboard("scoreboard", self)

    def connect_phase(self):
        for i, agent in enumerate(self.agents):
            agent.monitor.ap.connect(self.scoreboard.cpu_fifo[i].analysis_export)
        self.sbus_mon.ap.connect(self.scoreboard.sbus_fifo.analysis_export)
