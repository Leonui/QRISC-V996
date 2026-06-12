# bootloader —— vendoring 的 SBI 引导器

本目录是 biRISC-V 用的 SBI 引导器/固件源码,**vendoring 自上游
[ultraembedded/riscv-linux-boot](https://github.com/ultraembedded/riscv-linux-boot)**
(目录改名为 `bootloader` 只为直观;产物 ELF 仍叫 `riscv-linux-boot.elf`)。

作用:把 vmlinux + dtb 打成 biRISC-V 可引导的 ELF(load @0x80000000),
在 M 态模拟原子指令(核是 RV32IM,无 A)、提供 hvc0(SBI)控制台。
由 `build-os/_bootimg.sh` / `build-os/build_image.sh` 调用(用 `make -C build-os image`)。

许可证见 LICENSE.md。构建产物(obj/、*.elf、*.bin、config.dtb)不入库(见 .gitignore)。
