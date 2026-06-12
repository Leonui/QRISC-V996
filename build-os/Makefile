# =============================================================================
# build-os/Makefile —— 复现 biRISC-V 自建 Linux 环境的"前置依赖获取 + 构建"入口
#
# 工程仓库只含:RTL 核(src)、testbench(tb)、SDK、GUI、本目录的构建脚本/配置/补丁、
# 以及 SBI 引导器(bootloader/,源自 ultraembedded/riscv-linux-boot)。
# 体积巨大、可自行下载的东西(Linux 内核源码、BusyBox 源码、RISC-V 工具链)不入库,
# 由本 Makefile 拉取到外部工作区 RVROOT(默认 ~/rvlinux),与 _*.sh 脚本约定的路径一致。
#
# 实测版本:Linux 5.4.0 · BusyBox 1.37.0 · 自建 rv32ima-linux GCC(riscv-gnu-toolchain)
#          · 裸机用系统 gcc-riscv64-unknown-elf(apt)
#
# 典型流程(全新机器):
#   sudo apt install -y gcc-riscv64-unknown-elf device-tree-compiler verilator gtkwave python3-tk
#   make -C build-os clone_toolchain build_gcc_linux   # 自建 Linux 工具链(慢,~1 小时)
#   make -C build-os clone_kernel clone_busybox        # 拉内核 5.4 + busybox 源码
#   make -C build-os busybox kernel image              # 建 rootfs → 内核 → 可引导镜像
# 之后用 tb/tb_soc 或 gui 运行;改程序见 sdk/README.md(虚拟磁盘 / 烤进镜像两条路)。
# =============================================================================

# 外部工作区(内核/busybox/工具链都放这;_kernel54.sh 等脚本硬约定为 ~/rvlinux)
RVROOT      ?= $(HOME)/rvlinux
KERNEL_TAG  ?= v5.4
BUSYBOX_TAG ?= 1_37_0
HERE        := $(CURDIR)

.PHONY: help deps clone_kernel clone_busybox clone_toolchain build_gcc_linux \
        baremetal_toolchain busybox kernel image clean_image

help:
	@echo "biRISC-V 自建 Linux —— 前置依赖获取 + 构建(外部工作区 RVROOT=$(RVROOT))"
	@echo ""
	@echo "  前置依赖(源码,不入库,本 Makefile 拉取):"
	@echo "    make clone_toolchain     - 克隆 riscv-gnu-toolchain 到 $(RVROOT)"
	@echo "    make build_gcc_linux     - 自建 rv32ima-linux GCC -> $(RVROOT)/toolchain/riscv32ima-linux(慢)"
	@echo "    make baremetal_toolchain - 裸机工具链(系统包,提示 apt 命令)"
	@echo "    make clone_kernel        - 克隆 Linux 并 checkout $(KERNEL_TAG) -> $(RVROOT)/linux-5.4"
	@echo "    make clone_busybox       - 克隆 BusyBox 并 checkout $(BUSYBOX_TAG) -> $(RVROOT)/busybox"
	@echo "    make deps                - 以上源码一次拉齐"
	@echo ""
	@echo "  构建(用工程内 build-os/ 的配置/补丁/脚本):"
	@echo "    make busybox             - 建静态 BusyBox rootfs(_busybox.sh)"
	@echo "    make kernel              - 套用内核补丁+配置,编 vmlinux(_kernel54.sh)"
	@echo "    make image               - 打 hvc0 + ttyUL0 可引导镜像 -> ../image/(build_image.sh)"

deps: clone_toolchain clone_kernel clone_busybox
	@echo "源码已拉齐。下一步:make build_gcc_linux(若还没工具链)、再 make busybox kernel image。"

# ---- 前置依赖:源码获取 ----------------------------------------------------
clone_toolchain:
	@mkdir -p $(RVROOT)
	cd $(RVROOT) && [ -d riscv-gnu-toolchain ] || \
	  git clone --recursive https://github.com/riscv/riscv-gnu-toolchain

# Linux 5.4(本平台需要 5.4 的 time64 syscall;旧 5.0 跑不了现代 glibc busybox)。
# 用 torvalds/linux + checkout v5.4 标签;也可改下 kernel.org 的 linux-5.4.tar.xz。
clone_kernel:
	@mkdir -p $(RVROOT)
	cd $(RVROOT) && [ -d linux-5.4 ] || ( \
	  git clone --depth 1 --branch $(KERNEL_TAG) \
	    https://github.com/torvalds/linux.git linux-5.4 )

clone_busybox:
	@mkdir -p $(RVROOT)
	cd $(RVROOT) && [ -d busybox ] || git clone https://github.com/mirror/busybox.git busybox
	cd $(RVROOT)/busybox && git checkout $(BUSYBOX_TAG)

# ---- 前置依赖:工具链构建 --------------------------------------------------
# Linux 用户态工具链(glibc, rv32ima),装到 _*.sh 约定的 $(RVROOT)/toolchain/riscv32ima-linux
build_gcc_linux:
	rm -rf  $(RVROOT)/build/build-riscv32ima-linux
	mkdir -p $(RVROOT)/build/build-riscv32ima-linux
	cd $(RVROOT)/build/build-riscv32ima-linux && \
	  $(RVROOT)/riscv-gnu-toolchain/configure \
	    --with-arch=rv32ima --prefix=$(RVROOT)/toolchain/riscv32ima-linux && \
	  $(MAKE) -j linux

# 裸机(newlib)工具链:直接用发行版包即可,SDK 配 -march=rv32ima_zicsr 使用它。
baremetal_toolchain:
	@echo "裸机工具链用系统包(无需自建):"
	@echo "   sudo apt install -y gcc-riscv64-unknown-elf"
	@echo "SDK 裸机侧用 riscv64-unknown-elf-gcc -march=rv32ima_zicsr(见 sdk/baremetal/)。"

# ---- 构建(调用工程内脚本)-------------------------------------------------
busybox:
	bash $(HERE)/_busybox.sh

kernel:
	bash $(HERE)/_kernel54.sh

image:
	bash $(HERE)/build_image.sh hvc0
	bash $(HERE)/build_image.sh ttyul0
	@echo "镜像在 ../image/biriscv-linux-5.4-{hvc0,ttyul0}.elf"

clean_image:
	rm -f ../image/biriscv-linux-5.4-*.elf
