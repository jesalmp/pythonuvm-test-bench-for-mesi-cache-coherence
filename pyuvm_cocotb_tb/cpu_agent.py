from pyuvm import uvm_agent, uvm_sequencer, ConfigDB
from cpu_driver import CpuDriver
from cpu_monitor import CpuMonitor

class CpuAgent(uvm_agent):
    def build_phase(self):
        super().build_phase()
        self.cpu_id = ConfigDB().get(self, "", "cpu_id")
        ConfigDB().set(self, "driver", "cpu_id", self.cpu_id)
        ConfigDB().set(self, "monitor", "cpu_id", self.cpu_id)
        self.sequencer = uvm_sequencer("sequencer", self)
        self.driver = CpuDriver("driver", self)
        self.monitor = CpuMonitor("monitor", self)

    def connect_phase(self):
        self.driver.seq_item_port.connect(self.sequencer.seq_item_export)
