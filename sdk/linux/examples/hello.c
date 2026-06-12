// Linux 程序:普通用户态程序,证明能在 biRISC-V Linux 里跑。
#include <stdio.h>
#include <sys/utsname.h>

int main(int argc, char **argv)
{
    struct utsname u;
    uname(&u);
    printf("Hello from biRISC-V Linux 用户态程序!\n");
    printf("  内核: %s %s  架构: %s\n", u.sysname, u.release, u.machine);
    printf("  这是编进 rootfs、在 Linux 进程里运行的,不是裸机。\n");
    return 0;
}
