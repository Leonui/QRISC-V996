// 裸机:GPIO 输出翻转(效果在波形 gpio_out 上看;UART 打印过程)
#include "../bm.h"

int main(void)
{
    uart_puts("\n==== 裸机 GPIO 演示 ====\n");
    gpio_set_dir(0xffffffff);          // 全部设为输出
    uart_puts("GPIO 全设为输出,开始翻转(看波形 gpio_out)...\n");

    for (int i = 0; i < 8; i++) {
        uint32_t pat = (i & 1) ? 0xa5a5a5a5 : 0x5a5a5a5a;
        gpio_write(pat);
        uart_puts("  gpio_out = ");
        uart_puthex(pat);
        uart_puts("\n");
        delay(2000);
    }
    gpio_write(0);
    uart_puts("==== done(gpio_out 已归零)====\n");
    return 0;
}
