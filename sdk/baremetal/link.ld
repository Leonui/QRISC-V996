/*-----------------------------------------------------------------
 * link.ld —— 裸机链接脚本。程序放在 DRAM 起始 0x80000000(= 核 reset_vector),
 * 栈放 DRAM 高处。DRAM 共 32MB(0x80000000~0x82000000)。
 *-----------------------------------------------------------------*/
OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    DRAM (rwx) : ORIGIN = 0x80000000, LENGTH = 32M
}

_stack_top = ORIGIN(DRAM) + LENGTH(DRAM) - 16;   /* 栈顶放 DRAM 顶部往下 */

SECTIONS
{
    . = ORIGIN(DRAM);

    .text : {
        *(.text.init)          /* crt0 的 _start 必须在最前(reset_vector 落点)*/
        *(.text .text.*)
    } > DRAM

    .rodata : { *(.rodata .rodata.*) *(.srodata*) } > DRAM
    .data   : { *(.data .data.*) *(.sdata*) } > DRAM

    .bss : {
        _bss_start = .;
        *(.bss .bss.*) *(.sbss*) *(COMMON)
        _bss_end = .;
    } > DRAM

    _end = .;
}
