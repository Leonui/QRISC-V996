#!/bin/bash
#-----------------------------------------------------------------
# 打"虚拟磁盘":把 Linux 用户态程序编进一个 cpio,放到 DRAM 顶部(0x81c00000)。
# 跟 build_install.sh(烤进内核 initramfs)的区别:
#   build_install.sh -> 程序进内核镜像,改一次要重建内核(~1-2 分钟)
#   mkdisk.sh        -> 程序进独立磁盘 hex,改程序只重建这块(~几秒),不动内核!
# tb 用 +DISK=<disk.hex> 加载它,/init 开机 dd /dev/mem | cpio 解到 /opt。
#
#   ./mkdisk.sh              编 examples/ 下所有 .c -> disk.hex
#   ./mkdisk.sh hello.c      只编一个
#   ./mkdisk.sh --strip-off  不 strip(默认 strip 以缩小,读取更快)
#-----------------------------------------------------------------
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
CC=~/rvlinux/toolchain/riscv32ima-linux/bin/riscv32-unknown-linux-gnu-gcc
STRIP=~/rvlinux/toolchain/riscv32ima-linux/bin/riscv32-unknown-linux-gnu-strip
DISK_ADDR=0x82000000                       # 内核 RAM(32MB)之上的 4MB,tb 内存扩到 36MB
OUTHEX="$ROOT/tb/tb_soc/disk.hex"
STAGE="$HERE/build/disk"                    # cpio 内容目录(就是将来的 /opt)

command -v "$CC" >/dev/null || { echo "缺 Linux 工具链: $CC"; exit 1; }

DOSTRIP=1; SRCS=()
for a in "$@"; do
    [ "$a" = "--strip-off" ] && { DOSTRIP=0; continue; }
    SRCS+=("$HERE/examples/$a")
done
[ ${#SRCS[@]} -eq 0 ] && SRCS=("$HERE/examples/"*.c)

rm -rf "$STAGE"; mkdir -p "$STAGE"
echo "== 编译 Linux 程序(静态)进虚拟磁盘 =="
for src in "${SRCS[@]}"; do
    [ -f "$src" ] || continue
    name=$(basename "$src" .c)
    "$CC" -march=rv32ima -mabi=ilp32 -O2 -static -Wall "$src" -o "$STAGE/$name"
    [ "$DOSTRIP" = 1 ] && "$STRIP" "$STAGE/$name"
    chmod +x "$STAGE/$name"
    echo "  $name  ($(stat -c%s "$STAGE/$name") B)"
done

# 打 cpio(newc 格式,busybox cpio -i 能解;主机无 cpio,用 Python 生成)
CPIO="$HERE/build/disk.cpio"
python3 "$HERE/mkcpio.py" "$STAGE" "$CPIO"
SZ=$(stat -c%s "$CPIO")
echo "== cpio = $SZ B ($(( (SZ+1048575)/1048576 )) MB),磁盘区上限 4MB =="
[ "$SZ" -gt $((4*1024*1024)) ] && { echo "✗ 程序总量超过 4MB 磁盘区!减少程序或调大磁盘区。"; exit 1; }

python3 "$HERE/bin2hex.py" "$CPIO" "$OUTHEX" "$DISK_ADDR"
echo "✅ disk.hex 就绪。仿真加 +DISK=$OUTHEX(GUI 勾「虚拟磁盘」)即可。"
echo "   改程序后重跑本脚本(~几秒)+ 重启仿真,无需重建内核。"
