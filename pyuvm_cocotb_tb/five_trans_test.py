import cocotb
from pyuvm import uvm_test, ConfigDB
from cocotb.triggers import Timer
from tb_env import TbEnv
from cpu_sequences import FiveTransSeq

class FiveTransTest(uvm_test):
    def build_phase(self):
        super().build_phase()
        self.env = TbEnv("env", self)

    async def run_phase(self):
        self.raise_objection()
        await Timer(50, units="ns")
        seq = FiveTransSeq("five_seq")
        await seq.start(self.env.agents[0].sequencer)
        await Timer(200, units="ns")
        self.drop_objection()
