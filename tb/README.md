# tb/ —— 测试平台(testbench)

仿真验证用的 testbench。设计本身在 [`../src/`](../src)。

```
tb/
└── tb_soc/    biRISC-V + 全 RTL 外设的纯 Verilog testbench(当前唯一在用,见 tb_soc/README.md)
```

## tb_soc 是什么
- DUT = `biriscv_soc`(`src/soc/`):核 + arb/tap + uart_lite/timer/gpio/spi/irq_ctrl。
- testbench 只外接两样:行为级 AXI4 DRAM(`axi4_ram.v`)+ 一个 UART 串行接收器
  (把真实串行线 `uart_tx` 按 8N1 反序列化成字节打印)。**UART 是真 RTL,不是 C++/行为模型。**
- 用 Verilator(`--binary --timing`,推荐)或 iverilog 编译,纯 RTL。

## 怎么跑
```bash
cd tb/tb_soc
./build.sh          # 编译(verilator)
./run.sh            # 跑(默认加载 ../../image/biriscv-linux-5.4.elf)
```
更省事用 GUI:`python3 ../../gui/biriscv_soc_console.py`。

> 历史:早期还有 `tb_top`(SystemC+C++)和 `tb_rtl`(纯RTL但UART是行为模型、无真外设)
> 两代 testbench,均已被 `tb_soc`(全真 RTL 外设 + 真中断路径)取代并删除。
> 通用的 ELF→hex 转换器已移到 [`../scripts/make_hex.py`](../scripts)。
