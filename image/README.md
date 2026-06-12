# image/ —— 预编译 OS 镜像

clone 下来**不用编内核**就能跑的可引导镜像(SBI 引导器 + 内核 + initramfs 打成一个 ELF,
加载在 `0x80000000`)。开机横幅:`QRISC-V996 Linux (biRISC-V RV32IMA 5.4, built from scratch)`。

| 文件 | 控制台 | 用途 |
|---|---|---|
| `biriscv-linux-5.4-hvc0.elf` | SBI(hvc0) | **默认、快**;UART 仍是真 RTL,但内核经 SBI 用它 |
| `biriscv-linux-5.4-ttyul0.elf` | 内核 uartlite 驱动(ttyUL0) | **真中断驱动路径**(irq_ctrl+uartlite),慢但最真实 |
| `biriscv-linux-5.4-diag.elf` | 诊断 | hvc0+ttyUL0 双节点,隔离调试用 |
| `biriscv-linux-5.4.elf` | (= hvc0 副本) | `run.sh` / GUI 的默认目标 |

## 怎么跑
```bash
./tb/tb_soc/run.sh                                   # 默认 = biriscv-linux-5.4.elf(hvc0)
ELF=image/biriscv-linux-5.4-ttyul0.elf ./tb/tb_soc/run.sh   # 换 ttyUL0
# 或 GUI 里「模式=Linux」选变体
```

## 怎么重新生成
这些是 `build-os/` 构建链的产物:
```bash
make -C build-os image          # 重建 hvc0 + ttyul0(需先有内核,见 build-os/README.md)
```
单独某个变体:`bash build-os/build_image.sh hvc0`(或 `ttyul0`)。

> 归档说明:这些 ELF 各约 11MB。是否纳入 git 由 `.gitignore` 决定——
> 含它们则 clone 即跑,不含则需先按 build-os 重建。
