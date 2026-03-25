"""
cpu_agent.py
CpuAgent — UVM agent, mirrors cpu_agent_c.sv.
"""

from uvm_shim import UvmAgent, UvmSequencer
from cpu_driver import CpuDriver
from cpu_monitor import CpuMonitor


class CpuAgent(UvmAgent):
    """
    Active agent for one CPU core.
    TbEnv sets _cpu_id, _model, _done_q before build_phase.
    """

    def build_phase(self):
        self.sequencer      = UvmSequencer("sequencer", self)

        self.driver         = CpuDriver("driver", self)
        self.driver._cpu_id = self._cpu_id
        self.driver._model  = self._model
        self.driver._done_q = self._done_q

        self.monitor         = CpuMonitor("monitor", self)
        self.monitor._cpu_id = self._cpu_id
        self.monitor._done_q = self._done_q

    def connect_phase(self):
        self.driver.seq_item_port.connect(self.sequencer)
