"""
base_test.py
BaseTest — runs CpuBaseSeq on all 4 CPUs concurrently (Taken from CSCE714 Lab 6).
"""

import asyncio
from uvm_shim import UvmTest
from tb_env import TbEnv
from cpu_sequences import CpuBaseSeq


class BaseTest(UvmTest):
    def build_phase(self):
        self.env = TbEnv("tb", self)

    async def run_phase(self):
        self.raise_objection()
        self.logger.info("BaseTest: Starting")
        async def run_seq(i):
            seq = CpuBaseSeq(f"cpu{i}_base_seq")
            await seq.start(self.env.cpu[i].sequencer)
        await asyncio.gather(*[run_seq(i) for i in range(4)])
        self.drop_objection()

    def report_phase(self):
        _print_result(self.env.sb.errors)


def _print_result(errors):
    print("\n---Test Summary---\n\n---Final Test Status---")
    if errors == 0:
        print("\nTest PASS")
        print(r" ____   _    ____ ____")
        print(r"|  _ \ / \  / ___/ ___|")
        print(r"| |_) / _ \ \___ \___ \ ")
        print(r"|  __/ ___ \ ___) |__) |")
        print(r"|_| /_/   \_\____/____/")
    else:
        print(f"\nTest FAIL ({errors} error(s))")
        print(r" _____ _    ___ _")
        print(r"|  ___/ \  |_ _| |")
        print(r"| |_ / _ \  | || |")
        print(r"|  _/ ___ \ | || |___")
        print(r"|_|/_/   \_\___|_____|")
    print()
