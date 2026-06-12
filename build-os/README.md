# build-os/ —— 从源码重建 OS

从源码重建 QRISC-V996 跑的那套 RV32IMA Linux 5.4(rootfs → 内核 → 可引导镜像)。
体积巨大的外部源码(Linux 内核 / BusyBox / 工具链)**不入库**,由这里的 `Makefile` 拉取。

## 文件
| 文件 | 作用 |
|---|---|
| `Makefile` | **入口**:拉外部源码 + 串起构建(见下「目标」) |
| `_busybox.sh` | 编静态 BusyBox rootfs(用 `configs/busybox_config32`) |
| `_kernel54.sh` | 套用内核补丁+配置、组装 rootfs(/init、设备节点、vdiskcat)、编 vmlinux |
| `build_image.sh` | 打可引导镜像:选 `hvc0` / `ttyul0` 变体,用 `bootloader/` 的 SBI |
| `_bootimg.sh` | 被 build_image.sh 调:vmlinux + dtb → riscv-linux-boot.elf |
| `_ld.sh` | (一次性)给 binutils 打补丁的辅助 |
| `configs/kernel_config_rv32ima` | 内核 .config |
| `configs/busybox_config32` | BusyBox .config |
| `kernel-patches/irq-xilinx-intc.c` | 改好的 Xilinx INTC 驱动(加根中断处理器),`_kernel54.sh` 覆盖进内核树 |
| `dts/config32_*.dts` | 设备树:`hvc0`(SBI 控制台)/ `ttyul0`(uartlite 控制台)/ `diag`(双节点) |
| `vdiskcat.c` | 虚拟磁盘读取助手(mmap /dev/mem 读 0x82000000),烤进 initramfs |

## Makefile 目标
```bash
make -C build-os                    # 看帮助
# 前置源码(不入库,拉到 RVROOT=~/rvlinux)
make -C build-os clone_toolchain    # riscv-gnu-toolchain
make -C build-os build_gcc_linux    # 自建 rv32ima-linux GCC(慢,~1 小时)
make -C build-os clone_kernel       # Linux v5.4 -> ~/rvlinux/linux-5.4
make -C build-os clone_busybox      # BusyBox 1_37_0 -> ~/rvlinux/busybox
# 构建(用本目录的配置/补丁)
make -C build-os busybox            # 静态 rootfs
make -C build-os kernel             # 套补丁 + 编 vmlinux
make -C build-os image              # 打 hvc0 + ttyUL0 镜像 -> ../image/
```
裸机工具链用系统包:`sudo apt install -y gcc-riscv64-unknown-elf`。

## `_kernel54.sh` 自动套用的内核改动(无需手改内核源码)
1. **Xilinx INTC 驱动**:`cp kernel-patches/irq-xilinx-intc.c` 覆盖
   —— 加根中断处理器 `xil_intc_handle_irq` + `set_handle_irq`(5.4 RISC-V 没有
   `riscv,cpu-intc` 域,要自己接根)。
2. **Kconfig**:让 `XILINX_INTC` 在 RISC-V 上可选(原 5.4 仅 MicroBlaze/Zynq)。
3. **arch/riscv/Makefile** 加 `_zicsr_zifencei`(GCC16/binutils);**CSR 旧名**
   `sbadaddr→stval / sptbr→satp / mbadaddr→mtval`。
4. **.config**:开 XILINX_INTC / SERIAL_UARTLITE / DEVMEM / 虚拟磁盘相关等。
5. **rootfs**:写 `/init`(挂 proc/sys、解虚拟磁盘到 /opt、起 shell)、设备节点
   (console/ttyUL0/mem…)、`/etc/passwd`、烤入 `vdiskcat`。

> 为什么内核必须 ≥ 5.4:现代 rv32 glibc 用 64 位 time_t,需要 5.1+ 的 time64
> 系统调用;5.0 能启动但用户态僵死。
