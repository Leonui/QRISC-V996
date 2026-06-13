# QRISC-V996 在 ZCU104 上运行

> English: [README_EN.md](README_EN.md)

本目录放的是一套已经构建好的 ZCU104 上板文件。它会把 biRISC-V RV32IMA SoC 下载到
PL,以 50 MHz 运行;ARM PS 负责配合 JTAG 启动。

## 准备
- 已安装 AMD Vitis,并且当前 shell 能找到 `xsct`
  (通常先执行 `source <Vitis>/settings64.sh`)
- ZCU104 已上电,USB-JTAG/UART 线已接好
- **SW6 启动模式设为 JTAG(全部 OFF)**
- 已安装 `picocom`、`screen` 或 `minicom` 之一
- 已安装 `git lfs`,避免只拿到 LFS 指针文件

## 拉取 git-lfs 二进制
```bash
git lfs install
git lfs pull
```

## 运行裸机 hello
在仓库根目录执行:
```bash
xsct fpga/run_jtag.tcl \
  fpga/hw/qriscv_zcu104.bit \
  fpga/boot/fsbl_a53.elf \
  fpga/riscv_images/hello_uart.bin \
  fpga/boot/ps_app.elf
```
另开一个终端连接串口:
```bash
picocom -b 115200 /dev/ttyUSB1      # 退出:Ctrl-A Ctrl-X
```
正常情况下会看到启动横幅,输入字符会被原样回显。

## 运行 Linux 5.4
把第三个镜像参数换成 Linux 镜像即可。通过 JTAG 传输较慢,加载大约需要 145 秒。
```bash
xsct fpga/run_jtag.tcl \
  fpga/hw/qriscv_zcu104.bit \
  fpga/boot/fsbl_a53.elf \
  fpga/riscv_images/linux_hvc0.bin \
  fpga/boot/ps_app.elf
```
正常情况下会先看到内核日志,随后进入 BusyBox shell。可以用 `cat /proc/cpuinfo` 确认
`isa: rv32ima` 和 `mmu: sv32`。

手动输入时放慢一些,约 50 ms/字符;这个控制台没有流控,粘贴整段命令容易丢字符。
