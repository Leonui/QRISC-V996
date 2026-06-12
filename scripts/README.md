# scripts/ —— 通用工具

## make_hex.py
把可引导 **ELF → `$readmemh` 用的字寻址 hex**(仿真内存镜像)。

- **零依赖**:自己解析 ELF32,不需要 RISC-V 工具链 / binutils。
- 输出带 `@词偏移`,落在指定基址(默认 0x80000000)。
- 整个构建链都在用它:`tb/tb_soc/run.sh`、`gui/run_soc_backend.sh`、
  `sdk/linux/build_install.sh`、`sdk/baremetal/build_run.sh`。

```bash
python3 scripts/make_hex.py <input.elf> <output.hex> [基址=0x80000000]
# 例:
python3 scripts/make_hex.py image/biriscv-linux-5.4.elf tb/tb_soc/image.hex 0x80000000
```

> 虚拟磁盘那条线另有 `sdk/linux/bin2hex.py`(原始二进制→hex,落在 0x82000000)
> 和 `sdk/linux/mkcpio.py`(目录→newc cpio),见 sdk/linux/。
