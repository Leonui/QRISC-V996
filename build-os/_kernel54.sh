#!/bin/bash
# Build a Linux 5.4 rv32ima kernel for biRISC-V. 5.4 has the time64 syscalls our
# modern glibc userspace needs (our busybox requires kernel >= 5.4.0); the proven
# 5.0 flow couldn't run our glibc binaries. Everything else (toolchain, busybox
# rootfs, bootloader, sim) is reused unchanged.
HERE=$(cd "$(dirname "$0")" && pwd)   # build-os/ —— configs 与内核驱动补丁都在工程内
TC=~/rvlinux/toolchain/riscv32ima-linux/bin/riscv32-unknown-linux-gnu-
KDIR=~/rvlinux/linux-5.4
ROOTFS=~/rvlinux/rootfs
LOG=~/rvlinux/kernel54_build.log

echo "== prepare initramfs rootfs ==" | tee "$LOG"
rm -rf "$ROOTFS"; mkdir -p "$ROOTFS"
cp -a ~/rvlinux/busybox/_install/. "$ROOTFS/"
mkdir -p "$ROOTFS"/{proc,sys,dev,etc,root,tmp,mnt}
# 虚拟磁盘读取助手(稳定基础设施,经 /dev/mem mmap 读 0x82000000):编一次烤进 initramfs。
mkdir -p "$ROOTFS/usr/bin"
_VC=~/rvlinux/toolchain/riscv32ima-linux/bin/riscv32-unknown-linux-gnu-gcc
"$_VC" -march=rv32ima -mabi=ilp32 -O2 -static -Wall \
    "$(dirname "$0")/vdiskcat.c" -o "$ROOTFS/usr/bin/vdiskcat" \
    && echo "  baked /usr/bin/vdiskcat" | tee -a "$LOG"
# 用户/组数据库(否则 whoami/id/ls -l 查不到 uid 0 的名字,报 "unknown uid 0")
cat > "$ROOTFS/etc/passwd" <<'EOF'
root:x:0:0:root:/root:/bin/sh
EOF
cat > "$ROOTFS/etc/group" <<'EOF'
root:x:0:
EOF
cat > "$ROOTFS/init" <<'EOF'
#!/bin/sh
mount -t proc  none /proc
mount -t sysfs none /sys
echo
echo "==================================================="
echo " QRISC-V996 Linux  (biRISC-V RV32IMA 5.4, built from scratch)"
echo "==================================================="
uname -a
# 虚拟磁盘:程序 cpio 放在 0x82000000(内核 RAM=32MB,在 RAM 之外)。vdiskcat 经 mmap
# 读出来 | cpio 解到 /opt —— 改程序只重建这块磁盘、重载仿真,不用重建内核。
if [ -c /dev/mem ] && [ -x /usr/bin/vdiskcat ]; then
    mkdir -p /opt
    vdiskcat 2>/dev/null | (cd /opt && cpio -idmu 2>/dev/null)
    if [ "$(ls -A /opt 2>/dev/null)" ]; then
        export PATH="$PATH:/opt"
        echo "虚拟磁盘已挂载到 /opt:$(ls /opt | tr '\n' ' ')"
    fi
fi
echo "busybox shell ready."
exec /bin/sh
EOF
chmod +x "$ROOTFS/init"

# static device nodes (kernel opens /dev/console for init fd0/1/2)
NODES=~/rvlinux/initramfs_nodes.txt
cat > "$NODES" <<'EOF'
dir /dev 755 0 0
nod /dev/console 600 0 0 c 5 1
nod /dev/null 666 0 0 c 1 3
nod /dev/tty 666 0 0 c 5 0
nod /dev/ttyS0 660 0 0 c 4 64
nod /dev/ttyUL0 660 0 0 c 204 187
nod /dev/mem 600 0 0 c 1 1
EOF

cd "$KDIR" || exit 1
# --- patches for v5.4 vs bleeding-edge GCC16 / binutils-trunk ---
# (1) spell out zicsr+zifencei in the riscv -march (content-matched, line-agnostic)
M=arch/riscv/Makefile
if ! grep -q 'zicsr_zifencei' "$M"; then
  sed -i 's|^\(KBUILD_CFLAGS += -march=.*\)$|\1_zicsr_zifencei|' "$M"
  sed -i 's|^\(KBUILD_AFLAGS += -march=.*\)$|\1_zicsr_zifencei|' "$M"
fi
# (2) pre-1.10 CSR names modern binutils dropped (guarded -> no-op if absent)
for r in 'sptbr satp' 'sbadaddr stval' 'mbadaddr mtval'; do
  old=${r% *}; new=${r#* }
  grep -rl "$old" arch/riscv/ 2>/dev/null | xargs -r sed -i "s/\b$old\b/$new/g"
done
# (vdso '-r -R' is handled by our patched ld - no Makefile change needed)
# (3) 我们对 Xilinx INTC 驱动的改动(=本平台的 irq_ctrl):加根中断处理器
#     xil_intc_handle_irq + set_handle_irq(5.4 RISC-V 无 riscv,cpu-intc 域,需自己接根)。
#     直接用工程内改好的整份驱动覆盖,确保可复现。
cp "$HERE/kernel-patches/irq-xilinx-intc.c" drivers/irqchip/irq-xilinx-intc.c
# (4) 让 XILINX_INTC 在 RISC-V 上可选(原 5.4 仅 MicroBlaze/Zynq;内容匹配,幂等)
KC=drivers/irqchip/Kconfig
if grep -q '^config XILINX_INTC' "$KC" && ! grep -q 'Xilinx Interrupt Controller IP' "$KC"; then
  python3 - "$KC" <<'PY'
import re,sys
p=sys.argv[1]; s=open(p).read()
s=re.sub(r'config XILINX_INTC\n(?:\t.*\n)+',
         'config XILINX_INTC\n\tbool "Xilinx Interrupt Controller IP"\n\tdepends on OF\n\tselect IRQ_DOMAIN\n',
         s,count=1)
open(p,'w').write(s)
PY
fi

cp "$HERE/configs/kernel_config_rv32ima" .config
echo "== kernel olddefconfig ==" | tee -a "$LOG"
make ARCH=riscv CROSS_COMPILE="$TC" olddefconfig >> "$LOG" 2>&1
# embed rootfs + device nodes, auto /dev
./scripts/config --enable  CONFIG_BLK_DEV_INITRD
./scripts/config --set-str CONFIG_INITRAMFS_SOURCE "$ROOTFS $NODES"
./scripts/config --enable  CONFIG_DEVTMPFS
./scripts/config --enable  CONFIG_DEVTMPFS_MOUNT
./scripts/config --enable  CONFIG_HVC_RISCV_SBI
# 真 RTL 串口路径:Xilinx INTC(=我们的 irq_ctrl) + uartlite 驱动 + 其控制台
./scripts/config --enable  CONFIG_XILINX_INTC
./scripts/config --enable  CONFIG_SERIAL_UARTLITE
./scripts/config --enable  CONFIG_SERIAL_UARTLITE_CONSOLE
./scripts/config --set-val CONFIG_SERIAL_UARTLITE_NR_UARTS 1
make ARCH=riscv CROSS_COMPILE="$TC" HOSTCFLAGS="-fcommon" olddefconfig >> "$LOG" 2>&1
echo "== verify key rv32 options ==" | tee -a "$LOG"
grep -E 'CONFIG_(ARCH_RV32I|32BIT|HVC_RISCV_SBI|CMODEL_MEDLOW)=y' .config | tee -a "$LOG"
echo "== build vmlinux (-j4) $(date) ==" | tee -a "$LOG"
make ARCH=riscv CROSS_COMPILE="$TC" HOSTCFLAGS="-fcommon" \
     KCFLAGS="-Wno-error -fcommon" -j4 vmlinux >> "$LOG" 2>&1
rc=$?
echo "== kernel make rc=$rc $(date) ==" | tee -a "$LOG"
if [ -f vmlinux ]; then
  ls -la vmlinux; file vmlinux
  strings vmlinux | grep -m1 'Linux version'
  echo "KERNEL54 OK"
else
  echo "KERNEL54 FAILED rc=$rc"; grep -iE 'error:|Error [0-9]|\*\*\*' "$LOG" | tail -20
fi
