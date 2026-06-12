// Linux 程序:经 /dev/mem mmap 直接操作 GPIO 外设(用户态驱动)。
// 和裸机 gpio.c 干一样的事,但跑在 Linux 里。需 root。
#include "../mmio.h"

int main(void)
{
    volatile void *gpio = mmio_map(GPIO_BASE);
    if (!gpio) return 1;

    printf("GPIO @0x%08x 已 mmap。设为输出并翻转(看波形 gpio_out):\n", GPIO_BASE);
    REG32(gpio, GPIO_DIRECTION) = 0xffffffff;      // 全输出

    for (int i = 0; i < 6; i++) {
        uint32_t pat = (i & 1) ? 0xcafe0000 : 0x0000babe;
        REG32(gpio, GPIO_OUTPUT) = pat;
        printf("  gpio_out = 0x%08x\n", pat);
        usleep(1000);
    }
    REG32(gpio, GPIO_OUTPUT) = 0;
    printf("done(gpio_out 归零)。\n");
    return 0;
}
