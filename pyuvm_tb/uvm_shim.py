"""
uvm_shim.py
Lightweight standalone UVM component framework for Python.
Provides the essential UVM building blocks (no cocotb / pyuvm required):

  UvmObject
  UvmComponent         – build/connect/run/check phases, child list
  UvmDriver            – seq_item_port (asyncio.Queue)
  UvmMonitor
  UvmAgent
  UvmEnv
  UvmTest
  UvmSequencer         – seq_item_export
  UvmSequence          – start_item / finish_item / body
  UvmSequenceItem
  UvmAnalysisPort      – write() fan-out
  UvmTlmAnalysisFifo   – analysis_export + asyncio.Queue get()
  uvm_root             – singleton runner

Usage
-----
    import asyncio
    from uvm_shim import uvm_root
    asyncio.run(uvm_root().run_test(MyTest))
"""

import asyncio
import logging
from typing import Any, Callable, List, Optional

# ---------------------------------------------------------------------------
# Base object
# ---------------------------------------------------------------------------

class UvmObject:
    def __init__(self, name: str):
        self.name = name
        self.logger = logging.getLogger(name)


# ---------------------------------------------------------------------------
# Analysis port / FIFO
# ---------------------------------------------------------------------------

class UvmAnalysisPort:
    """Fan-out write to all connected exports."""
    def __init__(self, name: str, parent=None):
        self.name = name
        self._exports: List["UvmTlmAnalysisFifo"] = []

    def connect(self, export: "UvmTlmAnalysisFifo"):
        self._exports.append(export)

    def write(self, item):
        for exp in self._exports:
            exp._q.put_nowait(item)


class UvmTlmAnalysisFifo:
    """FIFO with an analysis_export (compatible with UvmAnalysisPort.connect)."""
    def __init__(self, name: str, parent=None):
        self.name = name
        self._q: asyncio.Queue = asyncio.Queue()
        self.analysis_export = self   # self IS the export

    async def get(self):
        return await self._q.get()


# ---------------------------------------------------------------------------
# Sequence item / sequencer / sequence
# ---------------------------------------------------------------------------

class UvmSequenceItem(UvmObject):
    def __init__(self, name: str = "seq_item"):
        super().__init__(name)


class UvmSequencer(UvmObject):
    """Middleman between sequences and driver."""
    def __init__(self, name: str, parent=None):
        super().__init__(name)
        # queue from sequence to driver
        self._item_q: asyncio.Queue = asyncio.Queue()
        # ack back to sequence
        self._done_event: asyncio.Event = asyncio.Event()
        # seq_item_export is the sequencer itself
        self.seq_item_export = self

    async def _put(self, item):
        self._done_event.clear()
        await self._item_q.put(item)
        await self._done_event.wait()

    def _item_done(self):
        self._done_event.set()


class _SeqItemPort:
    """Attached to the driver; pulls items from the connected sequencer."""
    def __init__(self):
        self._sequencer: Optional[UvmSequencer] = None

    def connect(self, export: UvmSequencer):
        self._sequencer = export

    async def get_next_item(self) -> UvmSequenceItem:
        return await self._sequencer._item_q.get()

    def item_done(self):
        self._sequencer._item_done()


class UvmSequence(UvmObject):
    def __init__(self, name: str = "sequence"):
        super().__init__(name)
        self._sequencer: Optional[UvmSequencer] = None

    async def start_item(self, item: UvmSequenceItem):
        pass  # nothing to wait for before putting item

    async def finish_item(self, item: UvmSequenceItem):
        await self._sequencer._put(item)

    async def body(self):
        """Override in subclass."""

    async def start(self, sequencer: UvmSequencer):
        self._sequencer = sequencer
        self.logger.info(f"Sequence {self.name}: starting body")
        await self.body()
        self.logger.info(f"Sequence {self.name}: body done")


# ---------------------------------------------------------------------------
# Component hierarchy
# ---------------------------------------------------------------------------

class UvmComponent(UvmObject):
    def __init__(self, name: str, parent: Optional["UvmComponent"] = None):
        super().__init__(name)
        self.parent = parent
        self._children: List["UvmComponent"] = []
        self._tasks: List[asyncio.Task] = []
        if parent is not None:
            parent._children.append(self)

    # Phase hooks — override in subclasses
    def build_phase(self):    pass
    def connect_phase(self):  pass
    def check_phase(self):    pass
    def report_phase(self):   pass

    async def run_phase(self):
        """Override in leaf components; default does nothing."""

    # Internal traversal
    def _traverse_build(self):
        self.build_phase()
        for c in self._children:
            c._traverse_build()

    def _traverse_connect(self):
        self.connect_phase()
        for c in self._children:
            c._traverse_connect()

    def _traverse_check(self):
        for c in self._children:
            c._traverse_check()
        self.check_phase()

    def _traverse_report(self):
        for c in self._children:
            c._traverse_report()
        self.report_phase()

    def _collect_run_tasks(self, loop: asyncio.AbstractEventLoop) -> List[asyncio.Task]:
        tasks = []
        for c in self._children:
            tasks.extend(c._collect_run_tasks(loop))
        if type(self).run_phase is not UvmComponent.run_phase:
            tasks.append(loop.create_task(self.run_phase()))
        return tasks


# ---------------------------------------------------------------------------
# Specialised component subtypes
# ---------------------------------------------------------------------------

class UvmDriver(UvmComponent):
    def __init__(self, name: str, parent=None):
        super().__init__(name, parent)
        self.seq_item_port = _SeqItemPort()


class UvmMonitor(UvmComponent):
    pass


class UvmAgent(UvmComponent):
    pass


class UvmEnv(UvmComponent):
    pass


class UvmScoreboard(UvmComponent):
    pass


class UvmTest(UvmComponent):
    def __init__(self, name: str, parent=None):
        super().__init__(name, parent)
        self._objection = 0
        self._run_done  = asyncio.Event()

    def raise_objection(self):
        self._objection += 1

    def drop_objection(self):
        self._objection -= 1
        if self._objection <= 0:
            self._run_done.set()


# ---------------------------------------------------------------------------
# Root runner
# ---------------------------------------------------------------------------

class _UvmRoot:
    _instance = None

    @classmethod
    def instance(cls):
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    async def run_test(self, test_class: type):
        """Build, connect, run, check, and report a test."""
        loop = asyncio.get_running_loop()

        # Instantiate test (top of hierarchy)
        test: UvmTest = test_class("uvm_test_top", None)

        # Build → connect phases (synchronous traversal)
        test._traverse_build()
        test._traverse_connect()

        # Collect all run_phase coroutines from the hierarchy
        run_tasks = test._collect_run_tasks(loop)

        # Also schedule the test's own run_phase
        test_run_task = loop.create_task(test.run_phase())

        # Wait for test to drop all objections
        await test._run_done.wait()

        # Cancel infinite monitor/driver loops
        for t in run_tasks:
            t.cancel()
        test_run_task.cancel()

        # Drain pending cancellations
        await asyncio.gather(*run_tasks, test_run_task,
                             return_exceptions=True)

        # Check + report
        test._traverse_check()
        test._traverse_report()


def uvm_root() -> _UvmRoot:
    return _UvmRoot.instance()
