#!/bin/bash
#-----------------------------------------------------------------
# 编译一个裸机程序并在 tb_soc 上跑(无 OS,直接在 biriscv 核上)。
#   ./build_run.sh examples/hello_uart.c     编译并运行
#   ./build_run.sh examples/gpio.c
#   ./build_run.sh examples/spi.c
# 仅编译不跑:  ./build_run.sh examples/xxx.c --build-only
# 录波形:      TRACE=1 ./build_run.sh examples/gpio.c   (看 gpio/spi 引脚)
#-----------------------------------------------------------------
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
SRC="${1:?用法: ./build_run.sh examples/xxx.c}"
CC=riscv64-unknown-elf-gcc
TBSOC="$ROOT/tb/tb_soc"

command -v $CC >/dev/null || { echo "缺裸机工具链: sudo apt install -y gcc-riscv64-unknown-elf"; exit 1; }

OUT="$HERE/build"; mkdir -p "$OUT"
NAME=$(basename "$SRC" .c)
ELF="$OUT/$NAME.elf"

echo "== 编译裸机 $SRC -> $ELF =="
$CC -march=rv32ima_zicsr -mabi=ilp32 -mcmodel=medany -O2 -ffreestanding -nostdlib \
    -Wall -T "$HERE/link.ld" \
    "$HERE/crt0.S" "$HERE/$SRC" -o "$ELF" -lgcc
riscv64-unknown-elf-size "$ELF" 2>/dev/null || true

[ "$2" = "--build-only" ] && { echo "(仅编译,产物 $ELF)"; exit 0; }

echo "== 转 hex + 在 tb_soc 上跑(reset 从 0x80000000)=="
HEX="$OUT/$NAME.hex"
python3 "$ROOT/scripts/make_hex.py" "$ELF" "$HEX" 0x80000000 >/dev/null
[ -x "$TBSOC/build_vl/tb_soc" ] || ( cd "$TBSOC" && ./build.sh )
: > "$OUT/.in.txt"
ARGS="+IMAGE=$HEX +INPUT=$OUT/.in.txt +MAX_CYCLES=${MAX_CYCLES:-3000000}"
[ -n "$TRACE" ] && { [ -x "$TBSOC/build_vl_trace_d1/tb_soc" ] || ( cd "$TBSOC" && ./build.sh verilator-trace ); \
    ARGS="$ARGS +TRACE +VCD=$TBSOC/tb_soc.fst"; BIN="$TBSOC/build_vl_trace_d1/tb_soc"; } || BIN="$TBSOC/build_vl/tb_soc"
echo "(输入:另开终端 echo cmd >> $OUT/.in.txt  喂给裸机 UART)"
echo "------------------------------------------------------------"
cd "$TBSOC"; exec stdbuf -o0 "$BIN" $ARGS