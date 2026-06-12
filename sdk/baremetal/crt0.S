#-----------------------------------------------------------------
# crt0.S —— 裸机启动代码。核复位后从 reset_vector(0x80000000)取指,
# 这里设好栈、清 .bss、调 main()。main 返回后停机(死循环)。
#-----------------------------------------------------------------
    .section .text.init, "ax"
    .globl _start
_start:
    # 关中断(MIE/SIE),裸机用轮询
    csrw  mie, zero

    # 设置栈指针(链接脚本里 _stack_top)
    la    sp, _stack_top

    # 清 .bss
    la    t0, _bss_start
    la    t1, _bss_end
1:  bgeu  t0, t1, 2f
    sw    zero, 0(t0)
    addi  t0, t0, 4
    j     1b
2:

    # 调 main(argc=0, argv=0)
    li    a0, 0
    li    a1, 0
    call  main

    # main 返回后:死循环停机
hang:
    wfi
    j     hang
