import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.types import LogicArray

class CpuBfm:
    TIMEOUT_CYCLES = 110

    def __init__(self, dut, cpu_id):
        self.dut = dut
        self.cpu_id = cpu_id
        self.clk = dut.clk
        self._addr_bus = getattr(dut, f"addr_bus_cpu_lv1_{cpu_id}")
        self._data_reg = getattr(dut, f"data_bus_cpu_lv1_{cpu_id}_reg")
        self._data_wire = getattr(dut, f"data_bus_cpu_lv1_{cpu_id}")

    def _set_bit(self, signal, val):
        current = int(signal.value) if signal.value.is_resolvable else 0
        if val:
            current |= (1 << self.cpu_id)
        else:
            current &= ~(1 << self.cpu_id) & 0xF
        signal.value = current

    def _get_bit(self, signal):
        if not signal.value.is_resolvable:
            return 0
        return (int(signal.value) >> self.cpu_id) & 1

    def _drive_z(self, signal):
        signal.value = LogicArray("Z" * len(signal))

    async def drive_read(self, address):
        await RisingEdge(self.clk)
        self._set_bit(self.dut.cpu_rd, 1)
        self._addr_bus.value = address

        await RisingEdge(self.clk)
        self._set_bit(self.dut.cpu_rden, 1)

        read_data = 0
        timed_out = True
        for _ in range(self.TIMEOUT_CYCLES):
            await RisingEdge(self.clk)
            if self._get_bit(self.dut.data_in_bus_cpu_lv1):
                val = self._data_wire.value
                read_data = int(val) if val.is_resolvable else 0
                timed_out = False
                break

        await RisingEdge(self.clk)
        self._set_bit(self.dut.cpu_rd, 0)
        self._drive_z(self._addr_bus)

        await RisingEdge(self.clk)
        self._set_bit(self.dut.cpu_rden, 0)

        if self._get_bit(self.dut.data_in_bus_cpu_lv1):
            for _ in range(self.TIMEOUT_CYCLES):
                await RisingEdge(self.clk)
                if not self._get_bit(self.dut.data_in_bus_cpu_lv1):
                    break
        await RisingEdge(self.clk)

        return read_data, timed_out

    async def drive_write(self, address, data):
        await RisingEdge(self.clk)
        self._set_bit(self.dut.cpu_wr, 1)
        self._addr_bus.value = address
        self._data_reg.value = data

        await RisingEdge(self.clk)
        self._set_bit(self.dut.cpu_wren, 1)

        timed_out = True
        for _ in range(self.TIMEOUT_CYCLES):
            await RisingEdge(self.clk)
            if self._get_bit(self.dut.cpu_wr_done):
                timed_out = False
                break

        await RisingEdge(self.clk)
        self._set_bit(self.dut.cpu_wr, 0)
        self._drive_z(self._addr_bus)
        self._drive_z(self._data_reg)

        await RisingEdge(self.clk)
        self._set_bit(self.dut.cpu_wren, 0)

        if self._get_bit(self.dut.cpu_wr_done):
            for _ in range(self.TIMEOUT_CYCLES):
                await RisingEdge(self.clk)
                if not self._get_bit(self.dut.cpu_wr_done):
                    break
        await RisingEdge(self.clk)

        return timed_out
