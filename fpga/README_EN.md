# Running QRISC-V996 on the ZCU104

> 中文: [README.md](README.md)

This folder has the files needed to run QRISC-V996 on a ZCU104 without rebuilding
the Vivado project. It loads the biRISC-V RV32IMA SoC into the PL at 50 MHz,
while the ARM PS handles the JTAG boot flow. You can use the same setup for the
bare-metal hello image or the Linux image.

## Prerequisites
- AMD Vitis installed, with `xsct` available in the current shell
  (`source <Vitis>/settings64.sh` is the usual setup)
- ZCU104 powered on, with USB-JTAG/UART connected
- **SW6 boot mode set to JTAG (all switches OFF)**
- `picocom`, `screen`, or `minicom`
- `git lfs` installed, so you get the binary files instead of LFS pointers

## Fetch the git-lfs artifacts
```bash
git lfs install
git lfs pull
```

## Run bare-metal hello
From the repository root:
```bash
xsct fpga/run_jtag.tcl \
  fpga/hw/qriscv_zcu104.bit \
  fpga/boot/fsbl_a53.elf \
  fpga/riscv_images/hello_uart.bin \
  fpga/boot/ps_app.elf
```
Open the console in a second terminal:
```bash
picocom -b 115200 /dev/ttyUSB1      # exit: Ctrl-A Ctrl-X
```
You should see the boot banner; typed characters are echoed back.

## Run Linux 5.4
Use the same command, replacing only the third image argument. Loading over JTAG
is slow and takes about 145 seconds.
```bash
xsct fpga/run_jtag.tcl \
  fpga/hw/qriscv_zcu104.bit \
  fpga/boot/fsbl_a53.elf \
  fpga/riscv_images/linux_hvc0.bin \
  fpga/boot/ps_app.elf
```
After the kernel log, you should land in a BusyBox shell. `cat /proc/cpuinfo`
should report `isa: rv32ima` and `mmu: sv32`.

Type slowly when entering commands, roughly 50 ms per character. The console has
no flow control, so large pastes can lose characters.
