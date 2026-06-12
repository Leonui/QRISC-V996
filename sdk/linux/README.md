# sdk/linux/ —— Linux 用户态程序

在启动好的 Linux 里**作为进程**跑,经 `/dev/mem` mmap 操作外设(用户态驱动)。
用 `riscv32-unknown-linux-gnu-gcc -static` 编译。

把程序送进 Linux 有**两条路**:

| | **A. 虚拟磁盘(推荐,快)** | **B. 烤进 initramfs** |
|---|---|---|
| 脚本 | `./mkdisk.sh` | `./build_install.sh` |
| 程序去哪 | 独立 `disk.hex`(DRAM 顶部 `0x82000000`) | 内核镜像肚子里(rootfs `/usr/bin`) |
| 改程序要多久 | **重建磁盘 ~几秒,不动内核** | 增量重建内核 ~1-2 分钟 |
| 程序出现在 | `/opt`(开机自动解压,已在 PATH) | `/usr/bin` |
| 仿真怎么用 | tb 加 `+DISK=disk.hex`(GUI 勾「虚拟磁盘」) | 自动(在镜像里) |

## A. 虚拟磁盘(日常迭代)
```bash
./mkdisk.sh                # 编 examples/ 所有 .c -> ../../tb/tb_soc/disk.hex
./mkdisk.sh hello.c        # 只编一个
```
GUI(Linux 模式)勾「虚拟磁盘」启动 → `~ #` 后 `ls /opt`、敲程序名运行。
**改完程序只重跑 `./mkdisk.sh`(~几秒)+ 重启仿真,无需重建内核。**

原理:磁盘数据放 `0x82000000`(内核 RAM=32MB 之外,tb 内存扩到 36MB 背书)。
开机 `/init` 用 `vdiskcat`(经 `/dev/mem` **mmap** 读,因为 read() 读不到 RAM 之外)
把程序 cpio 解到 `/opt`。`vdiskcat` 编一次烤进 initramfs,改程序不动它。

## B. 烤进 initramfs
```bash
./build_install.sh                 # 编所有 examples + 装进 rootfs + 重建镜像
./build_install.sh hello.c         # 只编一个
./build_install.sh --no-rebuild    # 攒多个,最后一次性重建
```
程序进 `/usr/bin`,随内核镜像分发;改一次增量重建内核(~1-2 分钟)。

## 文件
| 文件 | 作用 |
|---|---|
| `mmio.h` | `mmio_map(物理基址)`(/dev/mem mmap)→ 之后和裸机一样 `REG32()` 读写 |
| `../soc.h` | 外设寄存器地址(裸机/Linux 共用) |
| `mkdisk.sh` | 编程序 → `mkcpio.py` 打 newc cpio → `bin2hex.py` 生成 disk.hex |
| `mkcpio.py` / `bin2hex.py` | 主机无 cpio,故用 Python 自造 cpio + 原始二进制→hex@0x82000000 |
| `build_install.sh` | 编程序 + 拷进 rootfs + 重建内核/镜像 |
| `examples/` | `hello.c`(printf+uname)/ `gpio_mmap.c`(经 /dev/mem 操作 GPIO) |

需 root(本系统默认 root)+ 内核 `CONFIG_DEVMEM=y`(已开)+ `/dev/mem` 节点(已加)。
