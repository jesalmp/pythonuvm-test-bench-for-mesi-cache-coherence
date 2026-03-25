"""
run_tb.py
Top-level runner for the 4-core MESI cache Python UVM testbench.

Usage
-----
    cd project/pyuvm_tb
    python run_tb.py                       # base_test (default)
    python run_tb.py --test base_test
    python run_tb.py --test five_trans_test
    python run_tb.py --log-level DEBUG
"""

import argparse
import asyncio
import logging
import sys

sys.path.insert(0, ".")

from uvm_shim import uvm_root


def parse_args():
    parser = argparse.ArgumentParser(
        description="Python UVM testbench for 4-core MESI Cache"
    )
    parser.add_argument("--test",
                        default="base_test",
                        choices=["base_test", "five_trans_test"])
    parser.add_argument("--log-level", default="INFO",
                        choices=["DEBUG", "INFO", "WARNING", "ERROR"])
    return parser.parse_args()


def main():
    args = parse_args()
    logging.basicConfig(
        level=getattr(logging, args.log_level),
        format="%(levelname)-7s [%(name)s] %(message)s",
        stream=sys.stdout,
    )
    print(f"\n{'='*60}")
    print(f"  Python UVM Testbench — 4-Core MESI Cache")
    print(f"  Running test: {args.test}")
    print(f"{'='*60}\n")

    if args.test == "base_test":
        from base_test import BaseTest as TestClass
    else:
        from five_trans_test import FiveTransTest as TestClass

    asyncio.run(uvm_root().run_test(TestClass))


if __name__ == "__main__":
    main()
