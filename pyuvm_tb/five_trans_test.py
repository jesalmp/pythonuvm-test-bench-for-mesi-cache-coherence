"""
five_trans_test.py
FiveTransTest — 5 ICache reads on CPU0 only.
"""

from uvm_shim import UvmTest
from tb_env import TbEnv
from cpu_sequences import FiveTransSeq
from base_test import _print_result


class FiveTransTest(UvmTest):
    def build_phase(self):
        self.env = TbEnv("tb", self)

    async def run_phase(self):
        self.raise_objection()
        self.logger.info("FiveTransTest: Starting")
        seq = FiveTransSeq("five_trans_seq")
        await seq.start(self.env.cpu[0].sequencer)
        self.drop_objection()

    def report_phase(self):
        _print_result(self.env.sb.errors)
