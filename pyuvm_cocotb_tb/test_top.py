import cocotb
from pyuvm import ConfigDB, uvm_root
from base_test import BaseTest
from five_trans_test import FiveTransTest

@cocotb.test()
async def test_cache(dut):
    ConfigDB().set(None, "*", "dut", dut)
    test_name = cocotb.plusargs.get("UVM_TESTNAME", "BaseTest")
    await uvm_root().run_test(test_name)
