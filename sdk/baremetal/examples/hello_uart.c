// 裸机:经 uart_lite 打印 + 读回显(无 OS,直接操作寄存器)
#include "../bm.h"

int main(void)
{
    uart_puts("\n==== biRISC-V 裸机 Hello (no OS) ====\n");
    uart_puts("UART @0x92000000,直接读写寄存器。\n");
    uart_puts("timer 计数值 = ");
    uart_puthex(timer_now());
    uart_puts("\n回显模式:敲什么显什么(GUI 输入框可发)。\n");

    // 简单回显:把收到的字符打回去
    for (int n = 0; n < 200; n++) {     // 收 200 个字符后退出(裸机演示用)
        int c;
        while ((c = uart_getc_nb()) < 0) {}   // 等一个字符
        uart_putc((char)c);
        if (c == '\r') uart_putc('\n');
    }
    uart_puts("\n==== done ====\n");
    return 0;
}
