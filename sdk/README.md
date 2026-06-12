# SDK —— 给 biRISC-V SoC 写程序(裸机 + Linux 两种)

在你这个 biRISC-V + riscv_soc 平台上写程序,操作 UART / SPI / GPIO 等外设。两条线:

| | **裸机(baremetal)** | **Linux(linux)** |
|---|---|---|
| 跑在哪 | 直接在 biRISC-V 核上,**无操作系统** | 在启动好的 Linux 里,作为**进程** |
| 外设访问 | 直接读写物理 MMIO 寄存器 | 经 `/dev/mem` mmap 物理寄存器(用户态驱动) |
| 工具链 | `riscv64-unknown-elf-gcc`(newlib) | `riscv32-unknown-linux-gnu-gcc`(glibc,静态) |
| 加载方式 | 程序链在 0x80000000,直接当镜像跑 | 编进 rootfs,随内核镜像一起 |
| 适合 | 裸机驱动/外设时序验证,启动快、可控 | 跑应用、用 Linux 设施(printf/文件/网络栈) |

外设寄存器定义共用 [`soc.h`](soc.h)(UART@0x92000000 / SPI@0x93000000 / GPIO@0x94000000 ...)。

---

## 一、裸机(`baremetal/`)

```bash
cd sdk/baremetal
./build_run.sh examples/hello_uart.c     # 编译 + 在 tb_soc 上跑
./build_run.sh examples/gpio.c
./build_run.sh examples/spi.c
TRACE=1 ./build_run.sh examples/gpio.c    # 录波形,看 gpio_out / spi 引脚
```
- 用 `riscv64-unknown-elf-gcc -march=rv32ima_zicsr` 编译,`crt0.S` 启动、`link.ld` 链在 0x80000000。
- 外设操作函数在 [`baremetal/bm.h`](baremetal/bm.h):`uart_putc/puts/getc_nb`、`gpio_set_dir/write/read`、`spi_init/xfer`。
- 跑在 `tb/tb_soc`,UART 输出经真串行线反序列化打印;GPIO/SPI 效果看波形(`TRACE=1`)。
- 写自己的程序:在 `examples/` 放个 `.c`(`#include "../bm.h"`,写 `int main()`),`./build_run.sh examples/你的.c`。

**例子:**
- `hello_uart.c` —— UART 打印 + 回显(可在 GUI 输入框喂字符)
- `gpio.c` —— GPIO 设输出、翻转(波形 `gpio_out`)
- `spi.c` —— SPI 发字节(波形 `spi_clk/mosi/cs`)

---

## 二、Linux(`linux/`)

把程序送进 Linux 有**两条路**:

| | **A. 虚拟磁盘(推荐,快)** | **B. 烤进 initramfs** |
|---|---|---|
| 脚本 | `./mkdisk.sh` | `./build_install.sh` |
| 程序去哪 | 独立 `disk.hex`(DRAM 顶部 0x82000000) | 内核镜像肚子里(rootfs) |
| 改程序要多久 | **重建磁盘 ~几秒,不动内核** | 重建内核(增量 ~1-2 分钟) |
| 程序出现在 | `/opt`(开机自动解压,已在 PATH) | `/usr/bin` |
| 仿真怎么用 | tb 加 `+DISK=disk.hex`(GUI 勾「虚拟磁盘」) | 自动(在镜像里) |

### A. 虚拟磁盘(日常迭代用这个)
```bash
cd sdk/linux
./mkdisk.sh                # 编 examples/ 所有 .c -> tb/tb_soc/disk.hex
./mkdisk.sh hello.c        # 只编一个
```
然后 GUI 里(Linux 模式)勾上「虚拟磁盘」启动,或命令行:
```bash
./tb/tb_soc/build_vl/tb_soc +IMAGE=image.hex +DISK=disk.hex +INPUT=...
```
到 `~ #` 后:
```sh
~ # ls /opt              # 磁盘里的程序都在这
gpio_mmap  hello
~ # hello                # 直接敲名字(/opt 已在 PATH)
~ # gpio_mmap            # 经 /dev/mem 操作 GPIO
```
**改完程序只跑 `./mkdisk.sh`(~几秒)+ 重启仿真即可,无需重建内核。**

> 原理:磁盘数据放在 DRAM 0x82000000(内核 RAM=32MB 之外,tb 内存扩到 36MB 背书)。
> 开机 `/init` 用 `vdiskcat`(经 `/dev/mem` **mmap** 读,因为 read() 读不到 RAM 之外)
> 把程序 cpio 解到 `/opt`。`vdiskcat` 是稳定助手,编一次烤进 initramfs,改程序不动它。

### B. 烤进 initramfs(要程序随镜像分发、或不想带 disk.hex 时)
```bash
cd sdk/linux
./build_install.sh                 # 编译所有 examples + 装进 rootfs + 重建镜像
./build_install.sh hello.c         # 只编一个
./build_install.sh --no-rebuild    # 攒多个程序,最后一次性重建
```
程序进 `/usr/bin`,随内核镜像走。改一次要重建内核(增量 ~1-2 分钟)。

- 两条路都用 `riscv32-unknown-linux-gnu-gcc -static` 编译。
- 外设访问经 [`linux/mmio.h`](linux/mmio.h) 的 `mmio_map(物理基址)`(`/dev/mem` mmap),之后和裸机一样 `REG32()` 读写。需要 root(本系统默认 root)+ 内核 `CONFIG_DEVMEM=y`(已开)+ `/dev/mem` 节点(已加)。
- 为什么不能"运行时拷文件进去":根文件系统是 initramfs(内存只读、无网络/磁盘)。虚拟磁盘正是绕过这个限制——把程序放在一块内核不碰的物理内存,开机 mmap 读出来,改它不用动内核。

**例子:**
- `hello.c` —— 普通用户态程序(printf + uname)
- `gpio_mmap.c` —— 经 `/dev/mem` 操作 GPIO(和裸机 gpio.c 同效果,但跑在 Linux 里)

---

## 三、什么时候用哪个

- **验证外设 RTL / 时序、要快、要可控** → 裸机(启动几千周期就跑起来,没 OS/MMU 干扰)。
- **写应用、想用 printf/文件/字符串/将来网络** → Linux。
- 两者**寄存器操作一模一样**(都靠 `soc.h` + `REG32`),区别只在"基址是不是要先 mmap"。

## 四、外设地址速查(`soc.h`)

| 外设 | 基址 | 关键寄存器 |
|---|---|---|
| irq_ctrl | 0x90000000 | (Xilinx INTC) |
| timer | 0x91000000 | VALUE@0 |
| **uart** | 0x92000000 | RX@0 TX@4 STATUS@8(bit0 RX有效/bit3 TX满) |
| **spi** | 0x93000000 | CR@0x60 SR@0x64 DTR@0x68 DRR@0x6c SSR@0x70 |
| **gpio** | 0x94000000 | DIR@0 IN@4 OUT@8 |
| DRAM | 0x80000000 | 32MB |
