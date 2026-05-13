import cocotb
from pyuvm import uvm_test, ConfigDB, uvm_root
from cocotb.triggers import RisingEdge, Timer
from tb_env import TbEnv
from cpu_sequences import CpuBaseSeq

class BaseTest(uvm_test):
    def build_phase(self):
        super().build_phase()
        self.env = TbEnv("env", self)

    async def run_phase(self):
        self.raise_objection()
        await Timer(50, units="ns")

        seqs = []
        for i in range(4):
            seq = CpuBaseSeq(f"cpu_seq_{i}")
            seqs.append(cocotb.start_soon(seq.start(self.env.agents[i].sequencer)))

        for s in seqs:
            await s

        await Timer(200, units="ns")
        self.drop_objection()
