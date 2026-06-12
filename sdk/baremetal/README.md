# sdk/baremetal/ —— 裸机程序

直接在 biRISC-V 核上跑、**无操作系统**,直写物理 MMIO 操作 UART/GPIO/SPI。
启动快(几千周期就跑起来)、可控,适合验证外设 RTL / 时序。

```bash
cd sdk/baremetal
./build_run.sh examples/hello_uart.c     # 编译 + 在 tb_soc 上跑
./build_run.sh examples/gpio.c
./build_run.sh examples/spi.c
TRACE=1 ./build_run.sh examples/gpio.c    # 录波形(看 gpio_out / spi 引脚)
```
GUI 里「模式 = 裸机」选 example 也行,现编现跑。

## 文件
| 文件 | 作用 |
|---|---|
| `crt0.S` | 启动:设 sp、清 bss、调 main、结束 wfi |
| `link.ld` | 链接脚本:ORIGIN `0x80000000`,栈在 DRAM 顶 |
| `bm.h` | 外设操作:`uart_putc/puts/getc_nb/puthex`、`gpio_*`、`spi_*` |
| `../soc.h` | 寄存器地址定义(UART/SPI/GPIO/…,裸机和 Linux 共用) |
| `build_run.sh` | 编译(`riscv64-unknown-elf-gcc -march=rv32ima_zicsr`)→ hex → 跑 tb_soc |
| `examples/` | `hello_uart.c`(打印+回显)/ `gpio.c`(翻转)/ `spi.c`(发字节) |

## 写自己的程序
在 `examples/` 放个 `.c`:
```c
#include "../bm.h"
int main(void){ uart_puts("hi\n"); return 0; }
```
`./build_run.sh examples/你的.c`。工具链用系统包
`sudo apt install -y gcc-riscv64-unknown-elf`(注意必须带 `-march=rv32ima_zicsr`,
核无 A 扩展之外还需 zicsr 才能用 `csrw` 等)。
