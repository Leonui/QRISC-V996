#!/bin/bash
# Stage 4: build busybox rootfs (rv32ima-linux). Logs to ~/rvlinux/busybox_build.log
HERE=$(cd "$(dirname "$0")" && pwd)   # build-os/ —— busybox 配置在工程内
TC=~/rvlinux/toolchain/riscv32ima-linux/bin/riscv32-unknown-linux-gnu-
cd ~/rvlinux/busybox || exit 1
cp "$HERE/configs/busybox_config32" .config
echo "== busybox build start $(date) ==" > ~/rvlinux/busybox_build.log
# force static build (so rootfs has no shared-lib deps), reconcile config to this busybox version
sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config
# reconcile config (adds CONFIG_SHA*_HWACCEL=y as default)
yes "" | make ARCH=riscv CROSS_COMPILE="$TC" oldconfig >> ~/rvlinux/busybox_build.log 2>&1
# now disable x86-only SHA-NI accel (undefined on RISC-V) and re-reconcile
sed -i 's/^CONFIG_SHA1_HWACCEL=y/# CONFIG_SHA1_HWACCEL is not set/'   .config
sed -i 's/^CONFIG_SHA256_HWACCEL=y/# CONFIG_SHA256_HWACCEL is not set/' .config
# disable applets/features that break against modern kernel headers / glibc / GCC
sed -i 's/^CONFIG_TC=y/# CONFIG_TC is not set/' .config
sed -i 's/^CONFIG_FEATURE_MOUNT_NFS=y/# CONFIG_FEATURE_MOUNT_NFS is not set/' .config
sed -i 's/^CONFIG_FEATURE_INETD_RPC=y/# CONFIG_FEATURE_INETD_RPC is not set/' .config
sed -i 's/^CONFIG_FEATURE_HAVE_RPC=y/# CONFIG_FEATURE_HAVE_RPC is not set/' .config
yes "" | make ARCH=riscv CROSS_COMPILE="$TC" oldconfig >> ~/rvlinux/busybox_build.log 2>&1
make ARCH=riscv CROSS_COMPILE="$TC" -j4 >> ~/rvlinux/busybox_build.log 2>&1
rc=$?
make ARCH=riscv CROSS_COMPILE="$TC" install >> ~/rvlinux/busybox_build.log 2>&1
echo "== busybox make rc=$rc $(date) ==" >> ~/rvlinux/busybox_build.log
if [ -x _install/bin/busybox ]; then
  file _install/bin/busybox
  echo "BUSYBOX OK"
else
  echo "BUSYBOX FAILED rc=$rc"; tail -15 ~/rvlinux/busybox_build.log
fi
